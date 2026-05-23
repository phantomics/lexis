;;;; package.lisp — Test package for Lexis

(defpackage #:lexis/tests
  (:use #:cl #:lexis #:lexis.html #:fiveam)
  (:export #:run-tests))

(in-package #:lexis/tests)

(def-suite lexis-suite
  :description "All Lexis tests")

(def-suite util-suite
  :description "Utility function tests"
  :in lexis-suite)

(def-suite parse-suite
  :description "Parsing tests"
  :in lexis-suite)

(def-suite text-processing-suite
  :description "Text processing / inline markup tests"
  :in lexis-suite)

(def-suite html-suite
  :description "HTML rendering tests"
  :in lexis-suite)

(defun run-tests ()
  "Run the complete Lexis test suite."
  (run! 'lexis-suite))
