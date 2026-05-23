;;;; util.lisp — Attribute parsing and utility functions

(in-package #:lexis)

;;; ============================================================
;;; Attribute normalization
;;; ============================================================

(defun normalize-attrs (attr-forms)
  "Normalize a Lexis attribute list to a keyword plist.
Accepts either keyword plist form (@ :key val :key val ...)
or alist form (@ (key val) (key val) ...).
The form is determined by the type of the first element:
- If keyword → plist
- If list → alist
Returns a plist with keyword keys."
  (when (null attr-forms)
    (return-from normalize-attrs nil))
  (let ((first (car attr-forms)))
    (cond
      ;; Keyword plist form: (:key val :key val ...)
      ((keywordp first)
       (normalize-plist-attrs attr-forms))
      ;; Association list form: ((key val) (key val) ...)
      ((listp first)
       (normalize-alist-attrs attr-forms))
      (t
       (error 'malformed-document
              :message "Attributes must begin with a keyword or a list"
              :form attr-forms)))))

(defun normalize-plist-attrs (plist)
  "Validate and return a keyword plist as-is.
Ensures alternating keyword/value structure."
  (loop for (key val) on plist by #'cddr
        unless (keywordp key)
          do (error 'malformed-document
                    :message (format nil "Expected keyword in attribute plist, got: ~S" key)
                    :form plist)
        collect key
        collect val))

(defun normalize-alist-attrs (alist)
  "Convert an association list of (key value) pairs to a keyword plist.
Keys are interned as keywords."
  (loop for entry in alist
        unless (and (listp entry) (>= (length entry) 2))
          do (error 'malformed-document
                    :message (format nil "Invalid alist attribute entry: ~S" entry)
                    :form alist)
        collect (let ((key (car entry)))
                  (etypecase key
                    (keyword key)
                    (symbol (intern (symbol-name key) :keyword))
                    (string (intern (string-upcase key) :keyword))))
        collect (cadr entry)))

(defgeneric get-attr (source key &optional default)
  (:documentation "Retrieve an attribute value.
SOURCE may be a plist or a lexis-element node.
KEY should be a keyword symbol."))

(defmethod get-attr ((attrs list) key &optional default)
  "Retrieve from a normalized attribute plist."
  (getf attrs key default))

;;; ============================================================
;;; Tree walking helpers
;;; ============================================================

(defun attrs-present-p (form)
  "Check whether a Lexis tagged-node form contains an @ attribute list.
FORM is the CDR of the tagged node (everything after the tag symbol).
Uses string comparison for the @ symbol to be package-independent."
  (and (consp (car form))
       (let ((first-sym (caar form)))
         (and (symbolp first-sym)
              (string= "@" (symbol-name first-sym))))))

(defun extract-tag-parts (form)
  "Given a complete Lexis tagged-node s-expression (tag [(@...)] children...),
return three values: TAG, ATTRS (normalized plist or NIL), CHILDREN (list)."
  (let* ((tag (car form))
         (rest (cdr form)))
    (if (attrs-present-p rest)
        (values tag
                (normalize-attrs (cdar rest))
                (cdr rest))
        (values tag nil rest))))
