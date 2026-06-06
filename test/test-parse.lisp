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

;;; ============================================================
;;; Passthrough parsing
;;; ============================================================

(test parse-passthrough-string-content
  "Passthrough with a single string child preserves it verbatim."
  (let ((node (parse-node '(passthrough (@ :medium :html)
                            "<script>console.log('hi');</script>"))))
    (is (typep node 'lexis-passthrough))
    (is (equal '(:html) (passthrough-targets node)))
    (is (null (node-children node)))
    (is (= 1 (length (passthrough-content node))))
    (is (string= "<script>console.log('hi');</script>"
                 (first (passthrough-content node))))))

(test parse-passthrough-spinneret-form
  "Passthrough children that are Spinneret forms are preserved as lists,
not parsed as Lexis nodes."
  (let* ((node (parse-node '(passthrough (@ :medium :html)
                             (:script :src "app.js" :defer t))))
         (content (passthrough-content node)))
    (is (typep node 'lexis-passthrough))
    (is (= 1 (length content)))
    ;; The child is preserved as the original list form, not as a
    ;; lexis-unknown-element for :SCRIPT
    (is (consp (first content)))
    (is (eq :script (first (first content))))
    (is (string= "app.js" (getf (rest (first content)) :src)))))

(test parse-passthrough-multiple-children
  "Multiple passthrough children are all preserved verbatim."
  (let* ((node (parse-node '(passthrough (@ :medium :html)
                             (:link :rel "stylesheet" :href "style.css")
                             (:script :src "app.js"))))
         (content (passthrough-content node)))
    (is (= 2 (length content)))
    (is (eq :link (first (first content))))
    (is (eq :script (first (second content))))))

(test parse-passthrough-multi-target
  "Passthrough :medium attribute accepts a list of target keywords."
  (let ((node (parse-node '(passthrough (@ :medium (:html :epub))
                            (:link :rel "stylesheet" :href "style.css")))))
    (is (equal '(:html :epub) (passthrough-targets node)))
    (is (passthrough-applies-p node :html))
    (is (passthrough-applies-p node :epub))
    (is (not (passthrough-applies-p node :latex)))))

(test parse-passthrough-nickname
  "The PTHRU nickname parses to lexis-passthrough as well."
  (let ((node (parse-node '(pthru (@ :medium :html)
                            "<meta name=\"viewport\" content=\"width=device-width\">"))))
    (is (typep node 'lexis-passthrough))
    (is (equal '(:html) (passthrough-targets node)))
    (is (= 1 (length (passthrough-content node))))))

(test parse-passthrough-metadata-attrs
  "Passthrough nodes may carry arbitrary metadata attributes alongside :medium."
  (let ((node (parse-node '(passthrough (@ :medium :html
                                           :kind :stylesheet
                                           :placement :head)
                            (:link :rel "stylesheet" :href "style.css")))))
    (is (typep node 'lexis-passthrough))
    (is (eq :stylesheet (get-attr node :kind)))
    (is (eq :head (get-attr node :placement)))))

(test parse-passthrough-no-medium
  "Passthrough without :medium has empty target list and applies to no medium."
  (let ((node (parse-node '(passthrough "<!-- no target -->"))))
    (is (null (passthrough-targets node)))
    (is (not (passthrough-applies-p node :html)))))

(test parse-passthrough-children-not-walked
  "Tokens inside passthrough content that look like Lexis tags are NOT
recursively parsed (no warnings, no element instances)."
  ;; If children were walked, :SCRIPT would trigger an unknown-tag-warning
  ;; for the keyword. Capture warnings and assert none was emitted for
  ;; passthrough's interior.
  (let ((unknown-warnings '()))
    (handler-bind ((unknown-tag-warning
                     (lambda (w)
                       (push (unknown-tag-warning-tag w) unknown-warnings)
                       (muffle-warning w))))
      (parse-node '(passthrough (@ :medium :html)
                    (:script "var x = 1;")
                    (:link :rel "stylesheet" :href "s.css"))))
    (is (null unknown-warnings))))
