;;;; parse.lisp — Parsing s-expressions into Lexis node trees

(in-package #:lexis)

;;; ============================================================
;;; Tag registry — maps tag symbols to node classes
;;; ============================================================

(defvar *tag-registry* (make-hash-table :test 'equal)
  "Hash table mapping tag name strings to their CLOS class names.
Uses string keys so that tag lookup is package-independent —
a Lexis document can be read in any package.")

(defun register-tag (tag-symbol class-name)
  "Register a mapping from TAG-SYMBOL to CLASS-NAME in the tag registry.
The key is the symbol's name (a string), enabling package-independent lookup."
  (setf (gethash (symbol-name tag-symbol) *tag-registry*) class-name))

(defun tag->class (tag-symbol)
  "Look up the CLOS class for TAG-SYMBOL by its name.
Returns 'lexis-unknown-element if not registered."
  (gethash (symbol-name tag-symbol) *tag-registry* 'lexis-unknown-element))

;;; Register core vocabulary tags
(macrolet ((register-tags (&rest pairs)
             `(progn
                ,@(loop for (tag class) on pairs by #'cddr
                        collect `(register-tag ',tag ',class)))))
  (register-tags
   document        lexis-document
   section         lexis-section
   paragraph       lexis-paragraph
   code-block      lexis-code-block
   blockquote      lexis-blockquote
   unordered-list  lexis-unordered-list
   ordered-list    lexis-ordered-list
   item            lexis-item
   image           lexis-image
   figure          lexis-figure
   caption         lexis-caption
   emphasis        lexis-emphasis
   strong          lexis-strong
   code            lexis-code
   strikethrough   lexis-strikethrough
   web-link        lexis-web-link
   classic-link    lexis-classic-link
   cross-ref       lexis-cross-ref))

;;; ============================================================
;;; Parsing
;;; ============================================================

(defgeneric parse-node (form)
  (:documentation "Convert a raw Lexis s-expression form into a lexis-node instance.
Strings become lexis-text-node. Lists become the appropriate lexis-element subclass
based on the tag registry. Returns a lexis-node."))

(defmethod parse-node ((form string))
  "Strings become text nodes."
  (make-instance 'lexis-text-node :text form))

(defmethod parse-node ((form cons))
  "Lists are parsed as tagged elements: (tag [(@attrs...)] children...)"
  (multiple-value-bind (tag attrs children)
      (extract-tag-parts form)
    (unless (symbolp tag)
      (error 'malformed-document
             :message (format nil "Tag must be a symbol, got: ~S" tag)
             :form form))
    (let ((class (tag->class tag)))
      (when (eq class 'lexis-unknown-element)
        (warn 'unknown-tag-warning :tag tag))
      (let ((node (make-instance class
                                 :tag tag
                                 :attrs attrs
                                 :children (mapcar #'parse-node children))))
        ;; Post-processing for specific types
        (post-parse-node node)
        node))))

(defmethod parse-node ((form null))
  "NIL is treated as empty text."
  (make-instance 'lexis-text-node :text ""))

(defmethod parse-node ((form t))
  "Fallback: coerce non-string atoms to their printed representation."
  (make-instance 'lexis-text-node :text (princ-to-string form)))

;;; ============================================================
;;; Post-parse processing
;;; ============================================================

(defgeneric post-parse-node (node)
  (:documentation "Perform any post-parse initialization on a node.
Called after the node and its children are fully constructed.")
  (:method ((node lexis-node))
    "Default: no-op."
    node))

(defmethod post-parse-node ((node lexis-section))
  "Compute section depth from the :depth attribute if provided."
  (let ((explicit-depth (get-attr node :depth)))
    (when explicit-depth
      (setf (section-depth node) explicit-depth)))
  node)

;;; ============================================================
;;; Depth computation (post-parse pass)
;;; ============================================================

(defgeneric compute-depths (node &optional current-depth)
  (:documentation "Walk the tree and assign section depths based on nesting.")
  (:method ((node lexis-node) &optional current-depth)
    (declare (ignore current-depth))
    node))

(defmethod compute-depths ((node lexis-element) &optional (current-depth 0))
  "Recurse into children, incrementing depth for nested sections."
  (dolist (child (node-children node))
    (compute-depths child current-depth))
  node)

(defmethod compute-depths ((node lexis-section) &optional (current-depth 0))
  "Assign depth to this section and recurse into children at depth+1."
  (let ((depth (1+ current-depth)))
    (unless (get-attr node :depth)  ; don't override explicit depth
      (setf (section-depth node) depth))
    (dolist (child (node-children node))
      (compute-depths child depth)))
  node)

;;; ============================================================
;;; Top-level entry point
;;; ============================================================

(defun parse-document (form)
  "Parse a complete Lexis document from an s-expression form.
FORM should be a list starting with the DOCUMENT tag.
Returns a lexis-document instance with depths computed."
  (unless (and (consp form)
               (symbolp (car form))
               (string= "DOCUMENT" (symbol-name (car form))))
    (error 'malformed-document
           :message "Document must be a list starting with DOCUMENT"
           :form form))
  (let ((doc (parse-node form)))
    (compute-depths doc)
    doc))
