;;;; text-processing.lisp — Inline markup expansion in text nodes
;;;;
;;;; Scans text nodes for inline markup patterns and expands them
;;;; into proper Lexis inline element nodes.
;;;;
;;;; Processing order (per spec Section 3.3):
;;;; 1. Code spans (`...`)
;;;; 2. Links ([[...|...]] and [[...]])
;;;; 3. Strong (**...**)
;;;; 4. Emphasis (*...*)
;;;; 5. Strikethrough (~~...~~)

(in-package #:lexis)

;;; ============================================================
;;; Pattern definitions
;;; ============================================================

;; Code spans: `content` (no nesting, content is literal)
(defparameter *code-pattern*
  (cl-ppcre:create-scanner "`([^`]+)`"))

;; Links: [[display|uri]] or [[target]]
(defparameter *link-pattern*
  (cl-ppcre:create-scanner "\\[\\[([^\\]]+?)\\|([^\\]]+?)\\]\\]|\\[\\[([^\\]]+?)\\]\\]"))

;; Strong: **content**
(defparameter *strong-pattern*
  (cl-ppcre:create-scanner "\\*\\*(.+?)\\*\\*"))

;; Emphasis: *content* (not preceded/followed by *)
(defparameter *emphasis-pattern*
  (cl-ppcre:create-scanner "(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)"))

;; Strikethrough: ~~content~~
(defparameter *strikethrough-pattern*
  (cl-ppcre:create-scanner "~~(.+?)~~"))

;;; ============================================================
;;; Text expansion engine
;;; ============================================================

(defun expand-pattern (text pattern node-builder)
  "Scan TEXT for matches of PATTERN. For each match, call NODE-BUILDER
with the match registers to produce a node. Returns a list of strings
and nodes representing the expanded text.
NODE-BUILDER receives the register vector and returns a lexis-node."
  (let ((result '())
        (last-end 0)
        (len (length text)))
    (cl-ppcre:do-scans (match-start match-end reg-starts reg-ends pattern text)
      ;; Add any text before this match
      (when (> match-start last-end)
        (push (subseq text last-end match-start) result))
      ;; Build the node from match registers
      (push (funcall node-builder text reg-starts reg-ends) result)
      (setf last-end match-end))
    ;; Add trailing text
    (when (< last-end len)
      (push (subseq text last-end) result))
    (if result
        (nreverse result)
        (list text))))

(defun get-register (text reg-starts reg-ends index)
  "Extract register INDEX from a regex match, or NIL if not matched."
  (let ((start (aref reg-starts index))
        (end (aref reg-ends index)))
    (when (and start end)
      (subseq text start end))))

;;; ============================================================
;;; Individual pattern expanders
;;; ============================================================

(defun expand-code-spans (text)
  "Expand backtick code spans in TEXT."
  (expand-pattern text *code-pattern*
    (lambda (text reg-starts reg-ends)
      (make-instance 'lexis-code
                     :tag 'code
                     :children (list (make-instance 'lexis-text-node
                                                    :text (get-register text reg-starts reg-ends 0)))))))

(defun expand-links (text)
  "Expand [[display|uri]] and [[target]] patterns in TEXT."
  (expand-pattern text *link-pattern*
    (lambda (text reg-starts reg-ends)
      (let ((display (get-register text reg-starts reg-ends 0))
            (uri (get-register text reg-starts reg-ends 1))
            (bare-target (get-register text reg-starts reg-ends 2)))
        (cond
          ;; [[display|uri]] form
          ((and display uri)
           (let ((is-classic (and (>= (length uri) 8)
                                  (string= "classic:" uri :end2 8))))
             (if is-classic
                 (make-instance 'lexis-classic-link
                                :tag 'classic-link
                                :attrs (list :uri uri)
                                :children (list (make-instance 'lexis-text-node :text display)))
                 (make-instance 'lexis-web-link
                                :tag 'web-link
                                :attrs (list :uri uri)
                                :children (list (make-instance 'lexis-text-node :text display))))))
          ;; [[target]] bare form → cross-ref
          (bare-target
           (make-instance 'lexis-cross-ref
                          :tag 'cross-ref
                          :attrs (list :target bare-target)
                          :children (list (make-instance 'lexis-text-node :text bare-target)))))))))

(defun expand-strong (text)
  "Expand **strong** patterns in TEXT."
  (expand-pattern text *strong-pattern*
    (lambda (text reg-starts reg-ends)
      (make-instance 'lexis-strong
                     :tag 'strong
                     :children (list (make-instance 'lexis-text-node
                                                    :text (get-register text reg-starts reg-ends 0)))))))

(defun expand-emphasis (text)
  "Expand *emphasis* patterns in TEXT."
  (expand-pattern text *emphasis-pattern*
    (lambda (text reg-starts reg-ends)
      (make-instance 'lexis-emphasis
                     :tag 'emphasis
                     :children (list (make-instance 'lexis-text-node
                                                    :text (get-register text reg-starts reg-ends 0)))))))

(defun expand-strikethrough (text)
  "Expand ~~strikethrough~~ patterns in TEXT."
  (expand-pattern text *strikethrough-pattern*
    (lambda (text reg-starts reg-ends)
      (make-instance 'lexis-strikethrough
                     :tag 'strikethrough
                     :children (list (make-instance 'lexis-text-node
                                                    :text (get-register text reg-starts reg-ends 0)))))))

;;; ============================================================
;;; Multi-pass expansion on a single text string
;;; ============================================================

(defun expand-inline-markup (text)
  "Expand all inline markup patterns in a single text string.
Returns a list of strings and lexis-node instances.
Processing order: code → links → strong → emphasis → strikethrough."
  ;; Pass 1: code spans (content is literal, no further processing)
  (let ((pass1 (expand-code-spans text)))
    ;; Pass 2-5: apply remaining patterns to string fragments only
    (flet ((apply-pass (items expander)
             (loop for item in items
                   if (stringp item)
                     nconc (funcall expander item)
                   else
                     collect item)))
      (let* ((pass2 (apply-pass pass1 #'expand-links))
             (pass3 (apply-pass pass2 #'expand-strong))
             (pass4 (apply-pass pass3 #'expand-emphasis))
             (pass5 (apply-pass pass4 #'expand-strikethrough)))
        pass5))))

;;; ============================================================
;;; Tree-level text processing
;;; ============================================================

(defgeneric process-text (node)
  (:documentation "Expand inline markup within text nodes of this subtree.
Returns a node (possibly the same instance, possibly new).
The text processing pass scans text-node children for inline patterns
and replaces them with sequences of text nodes and inline element nodes."))

(defmethod process-text ((node lexis-text-node))
  "Text nodes in isolation are returned as-is.
Expansion happens at the parent level where children are managed."
  node)

(defmethod process-text ((node lexis-element))
  "Process text children of this element, expanding inline markup.
Does not process children of code-block nodes (content is literal)."
  ;; Recursively process children first (depth-first)
  (setf (node-children node)
        (loop for child in (node-children node)
              collect (process-text child)))
  ;; Now expand inline markup in text-node children of this element
  (setf (node-children node)
        (expand-text-children (node-children node)))
  node)

(defmethod process-text ((node lexis-code-block))
  "Code blocks are literal — no inline markup processing."
  node)

(defmethod process-text ((node lexis-code))
  "Inline code is literal — no further inline markup processing."
  node)

(defmethod process-text ((node lexis-passthrough))
  "Passthrough content is opaque target-native data — never processed
for inline markup, regardless of what characters appear in it."
  node)

(defun expand-text-children (children)
  "Given a list of child nodes, expand inline markup in any text nodes.
Returns a new list where text nodes may have been replaced by sequences
of text nodes and inline element nodes."
  (loop for child in children
        if (typep child 'lexis-text-node)
          nconc (let ((expanded (expand-inline-markup (node-text child))))
                  ;; If expansion produced only the original string, keep text node
                  (if (and (= 1 (length expanded))
                           (stringp (first expanded)))
                      (list child)
                      ;; Convert strings to text nodes, keep nodes as-is
                      (mapcar (lambda (item)
                                (if (stringp item)
                                    (make-instance 'lexis-text-node :text item)
                                    item))
                              expanded)))
        else
          collect child))
