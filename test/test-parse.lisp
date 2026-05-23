;;;; test-parse.lisp — Tests for s-expression parsing into node trees

(in-package #:lexis/tests)
(in-suite parse-suite)

;;; ============================================================
;;; Basic parsing
;;; ============================================================

(test parse-string-to-text-node
  "Strings parse to lexis-text-node."
  (let ((node (parse-node "Hello")))
    (is (typep node 'lexis-text-node))
    (is (string= "Hello" (node-text node)))))

(test parse-paragraph
  "Simple paragraph parses correctly."
  (let ((node (parse-node '(paragraph "Hello, world."))))
    (is (typep node 'lexis-paragraph))
    (is (eq 'paragraph (node-tag node)))
    (is (= 1 (length (node-children node))))
    (is (string= "Hello, world." (node-text (first (node-children node)))))))

(test parse-paragraph-with-inline
  "Paragraph with inline element parses nested structure."
  (let ((node (parse-node '(paragraph "This is " (emphasis "important") "."))))
    (is (typep node 'lexis-paragraph))
    (is (= 3 (length (node-children node))))
    (is (typep (second (node-children node)) 'lexis-emphasis))
    (is (string= "important"
                 (node-text (first (node-children (second (node-children node)))))))))

(test parse-section-with-attrs
  "Section with attributes parses title and id."
  (let ((node (parse-node '(section (@ :title "Intro" :id "intro")
                            (paragraph "Hello.")))))
    (is (typep node 'lexis-section))
    (is (string= "Intro" (section-title node)))
    (is (string= "intro" (section-id node)))
    (is (= 1 (length (node-children node))))
    (is (typep (first (node-children node)) 'lexis-paragraph))))

(test parse-code-block
  "Code block with language attribute."
  (let ((node (parse-node '(code-block (@ :language :lisp) "(defun foo () 42)"))))
    (is (typep node 'lexis-code-block))
    (is (string= "lisp" (code-block-language node)))
    (is (= 1 (length (node-children node))))))

(test parse-web-link
  "Web link with URI and children."
  (let ((node (parse-node '(web-link (@ :uri "https://example.com" :title "Example")
                            "Click here"))))
    (is (typep node 'lexis-web-link))
    (is (string= "https://example.com" (web-link-uri node)))
    (is (string= "Example" (web-link-title node)))))

(test parse-image
  "Image with src and alt."
  (let ((node (parse-node '(image (@ :src "photo.jpg" :alt "A photo")))))
    (is (typep node 'lexis-image))
    (is (string= "photo.jpg" (image-src node)))
    (is (string= "A photo" (image-alt node)))
    (is (null (node-children node)))))

(test parse-list
  "Unordered list with items."
  (let ((node (parse-node '(unordered-list
                            (item "First")
                            (item "Second")
                            (item "Third")))))
    (is (typep node 'lexis-unordered-list))
    (is (= 3 (length (node-children node))))
    (is (every (lambda (c) (typep c 'lexis-item)) (node-children node)))))

;;; ============================================================
;;; Document-level parsing
;;; ============================================================

(test parse-document-basic
  "parse-document handles a minimal document."
  (let ((doc (parse-document '(document (@ :title "Test")
                               (paragraph "Hello.")))))
    (is (typep doc 'lexis-document))
    (is (string= "Test" (document-title doc)))
    (is (= 1 (length (node-children doc))))))

(test parse-document-rejects-non-document
  "parse-document signals error for non-document root."
  (signals malformed-document
    (parse-document '(section (@ :title "Not a doc")))))

;;; ============================================================
;;; Depth computation
;;; ============================================================

(test section-depth-computation
  "Nested sections get correct computed depths."
  (let ((doc (parse-document
              '(document (@ :title "Test")
                (section (@ :title "Top")
                  (paragraph "text")
                  (section (@ :title "Nested")
                    (paragraph "deeper")))))))
    (let* ((top-section (first (node-children doc)))
           (nested-section (find-if (lambda (c) (typep c 'lexis-section))
                                    (node-children top-section))))
      (is (= 1 (section-depth top-section)))
      (is (= 2 (section-depth nested-section))))))

;;; ============================================================
;;; Unknown tags
;;; ============================================================

(test parse-unknown-tag
  "Unknown tags produce lexis-unknown-element with a warning."
  (let ((node (handler-bind ((unknown-tag-warning #'muffle-warning))
                (parse-node '(custom-widget (@ :id "w1") "content")))))
    (is (typep node 'lexis-unknown-element))
    (is (eq 'custom-widget (node-tag node)))
    (is (= 1 (length (node-children node))))))
