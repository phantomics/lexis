;;;; test-text-processing.lisp — Tests for inline markup expansion

(in-package #:lexis/tests)
(in-suite text-processing-suite)

;;; ============================================================
;;; Individual pattern expansion
;;; ============================================================

(test expand-code-span
  "Backtick code spans are expanded."
  (let ((result (lexis::expand-code-spans "Use `defun` to define functions.")))
    (is (= 3 (length result)))
    (is (string= "Use " (first result)))
    (is (typep (second result) 'lexis-code))
    (is (string= "defun" (node-text (first (node-children (second result))))))
    (is (string= " to define functions." (third result)))))

(test expand-strong-text
  "Double-asterisk strong patterns are expanded."
  (let ((result (lexis::expand-strong "This is **important** text.")))
    (is (= 3 (length result)))
    (is (typep (second result) 'lexis-strong))
    (is (string= "important" (node-text (first (node-children (second result))))))))

(test expand-emphasis-text
  "Single-asterisk emphasis patterns are expanded."
  (let ((result (lexis::expand-emphasis "This is *emphasized* text.")))
    (is (= 3 (length result)))
    (is (typep (second result) 'lexis-emphasis))
    (is (string= "emphasized" (node-text (first (node-children (second result))))))))

(test expand-strikethrough-text
  "Tilde strikethrough patterns are expanded."
  (let ((result (lexis::expand-strikethrough "This is ~~deleted~~ text.")))
    (is (= 3 (length result)))
    (is (typep (second result) 'lexis-strikethrough))
    (is (string= "deleted" (node-text (first (node-children (second result))))))))

(test expand-web-link
  "[[display|url]] patterns expand to web-link nodes."
  (let ((result (lexis::expand-links "See [[Example|https://example.com]] here.")))
    (is (= 3 (length result)))
    (is (string= "See " (first result)))
    (is (typep (second result) 'lexis-web-link))
    (is (string= "https://example.com" (web-link-uri (second result))))
    (is (string= "Example" (node-text (first (node-children (second result))))))
    (is (string= " here." (third result)))))

(test expand-classic-link
  "[[display|classic:...]] patterns expand to classic-link nodes."
  (let ((result (lexis::expand-links
                 "See [[the article|classic:example.com,2026:articles/test]] now.")))
    (is (= 3 (length result)))
    (is (typep (second result) 'lexis-classic-link))
    (is (string= "classic:example.com,2026:articles/test"
                 (classic-link-uri (second result))))))

(test expand-cross-ref
  "[[target]] bare patterns expand to cross-ref nodes."
  (let ((result (lexis::expand-links "See [[Introduction]] for details.")))
    (is (= 3 (length result)))
    (is (typep (second result) 'lexis-cross-ref))
    (is (string= "Introduction" (cross-ref-target (second result))))))

;;; ============================================================
;;; Multi-pass expansion
;;; ============================================================

(test expand-multiple-patterns
  "Multiple patterns in one string are all expanded."
  (let ((result (lexis::expand-inline-markup
                 "Use `code` and **bold** together.")))
    ;; "Use " + code + " and " + strong + " together."
    (is (= 5 (length result)))
    (is (typep (second result) 'lexis-code))
    (is (typep (fourth result) 'lexis-strong))))

(test code-content-not-further-processed
  "Content inside code spans is not processed for other patterns."
  (let ((result (lexis::expand-inline-markup "Try `**not bold**` here.")))
    ;; "Try " + code("**not bold**") + " here."
    (is (= 3 (length result)))
    (is (typep (second result) 'lexis-code))
    (is (string= "**not bold**"
                 (node-text (first (node-children (second result))))))))

(test no-patterns-returns-original
  "Text without patterns returns a single-element list with the string."
  (let ((result (lexis::expand-inline-markup "Plain text with no patterns.")))
    (is (= 1 (length result)))
    (is (string= "Plain text with no patterns." (first result)))))

;;; ============================================================
;;; Tree-level processing
;;; ============================================================

(test process-text-paragraph
  "process-text expands inline markup in paragraph children."
  (let* ((doc (parse-document '(document (@ :title "Test")
                                (paragraph "This is *important* stuff."))))
         (processed (process-text doc))
         (para (first (node-children processed)))
         (children (node-children para)))
    ;; "This is " + emphasis("important") + " stuff."
    (is (= 3 (length children)))
    (is (typep (first children) 'lexis-text-node))
    (is (typep (second children) 'lexis-emphasis))
    (is (typep (third children) 'lexis-text-node))))

(test process-text-code-block-literal
  "process-text does not expand markup inside code-block."
  (let* ((doc (parse-document '(document (@ :title "Test")
                                (code-block (@ :language :lisp)
                                  "This has *asterisks* but no emphasis."))))
         (processed (process-text doc))
         (code (first (node-children processed)))
         (children (node-children code)))
    ;; Should remain a single text node, unexpanded
    (is (= 1 (length children)))
    (is (typep (first children) 'lexis-text-node))
    (is (string= "This has *asterisks* but no emphasis."
                 (node-text (first children))))))
