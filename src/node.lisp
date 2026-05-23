;;;; node.lisp — Base CLOS classes for the Lexis document object model

(in-package #:lexis)

;;; ============================================================
;;; lexis-node — abstract base for all document nodes
;;; ============================================================

(defclass lexis-node ()
  ()
  (:documentation "Abstract base class for all Lexis document nodes.
A node is either a text node (leaf containing a string) or an element
node (has a tag, optional attributes, and children)."))

;;; ============================================================
;;; lexis-text-node — a leaf node containing text
;;; ============================================================

(defclass lexis-text-node (lexis-node)
  ((text :accessor node-text
         :initarg :text
         :type string
         :documentation "The text content of this node."))
  (:documentation "A leaf node containing a text string.
Text nodes are the atomic units of content in a Lexis document."))

(defmethod print-object ((node lexis-text-node) stream)
  (print-unreadable-object (node stream :type t)
    (let ((text (node-text node)))
      (if (> (length text) 40)
          (format stream "~S..." (subseq text 0 37))
          (format stream "~S" text)))))

;;; ============================================================
;;; lexis-element — base class for all tagged element nodes
;;; ============================================================

(defclass lexis-element (lexis-node)
  ((tag :accessor node-tag
        :initarg :tag
        :type symbol
        :documentation "The tag symbol identifying this element's type.")
   (attrs :accessor node-attrs
          :initarg :attrs
          :initform nil
          :documentation "Normalized attribute plist (keyword keys).")
   (children :accessor node-children
             :initarg :children
             :initform nil
             :type list
             :documentation "Ordered list of child lexis-node instances."))
  (:documentation "Base class for all tagged element nodes.
Every element has a tag symbol, an attribute plist, and a list of children.
Subclasses provide typed accessors for their specific attributes."))

(defmethod print-object ((node lexis-element) stream)
  (print-unreadable-object (node stream :type t)
    (format stream "~A (~D child~:P)"
            (node-tag node)
            (length (node-children node)))))

;;; ============================================================
;;; Attribute access protocol for elements
;;; ============================================================

(defmethod get-attr ((node lexis-element) key &optional default)
  "Retrieve an attribute value from an element node."
  (getf (node-attrs node) key default))
