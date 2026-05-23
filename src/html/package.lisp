;;;; package.lisp — Package definition for Lexis HTML renderer

(defpackage #:lexis.html
  (:use #:cl #:lexis)
  (:export
   #:render-html
   #:render-html-tree

   ;; Rendering options
   #:*standalone*
   #:*css-class-prefix*))
