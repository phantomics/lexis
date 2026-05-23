;;;; lexis.asd — ASDF system definition for Lexis
;;;; Lisp EXpressions as Interchange Syntax
;;;;
;;;; A semantic document format using s-expressions, with a CLOS object
;;;; model for processing and multi-target rendering.

(asdf:defsystem "lexis"
  :description "Lisp EXpressions as Interchange Syntax — s-expression document format"
  :version "0.1.0"
  :license "BSD-3"
  :depends-on ("cl-ppcre")
  :pathname "src/"
  :serial t
  :components
  ((:file "packages")
   (:file "conditions")
   (:file "util")
   (:file "node")
   (:file "tags")
   (:file "parse")
   (:file "text-processing")))

(asdf:defsystem "lexis/tests"
  :description "Test suite for Lexis"
  :depends-on ("lexis" "lexis.html" "fiveam")
  :pathname "test/"
  :serial t
  :components
  ((:file "package")
   (:file "test-util")
   (:file "test-parse")
   (:file "test-text-processing")
   (:file "test-html")))
