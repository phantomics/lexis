;;; compass.sexp — Compass project manifest
;;;
;;; Written by compass init. Read with a restricted reader: strings, integers,
;;; keywords, and lists only. Other keys, such as :commands, may be added by
;;; hand (Compass §5, §22).

(:namespaces ("LEXIS")
 :doc-directory "doc/"
 :federation ((:namespace "SEED" :path "../seed")
              (:namespace "CLASSIC" :path "../classic"))
 :commands ((:name :test
             :repl "(progn (ql:quickload \"lexis/tests\") (lexis/tests:run-tests))"
             :doc "Run Lexis's test suite"))
 :stewards ((:namespace "LEXIS" :steward "Andrew Sengul" :approval :solo)))
