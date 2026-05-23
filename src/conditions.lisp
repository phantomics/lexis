;;;; conditions.lisp — Error and warning conditions for Lexis

(in-package #:lexis)

(define-condition lexis-error (error)
  ((message :initarg :message :reader lexis-error-message))
  (:report (lambda (c stream)
             (format stream "Lexis error: ~A" (lexis-error-message c)))))

(define-condition malformed-document (lexis-error)
  ((form :initarg :form :reader malformed-document-form))
  (:report (lambda (c stream)
             (format stream "Malformed Lexis document: ~A~%  Form: ~S"
                     (lexis-error-message c)
                     (malformed-document-form c)))))

(define-condition unknown-tag-warning (warning)
  ((tag :initarg :tag :reader unknown-tag-warning-tag))
  (:report (lambda (c stream)
             (format stream "Unknown Lexis tag: ~S (treating as generic container)"
                     (unknown-tag-warning-tag c)))))
