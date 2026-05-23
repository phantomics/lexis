;;;; test-html.lisp — Tests for HTML rendering

(in-package #:lexis/tests)
(in-suite html-suite)

;;; ============================================================
;;; HTML tree generation
;;; ============================================================

(test render-paragraph-tree
  "Paragraph renders to (:p ...) form."
  (let* ((node (parse-node '(paragraph "Hello, world.")))
         (tree (render-html-tree node)))
    (is (eq :p (first tree)))
    (is (string= "Hello, world." (second tree)))))

(test render-emphasis-tree
  "Emphasis renders to (:em ...) form."
  (let* ((node (parse-node '(emphasis "italic")))
         (tree (render-html-tree node)))
    (is (equal '(:em "italic") tree))))

(test render-strong-tree
  "Strong renders to (:strong ...) form."
  (let* ((node (parse-node '(strong "bold")))
         (tree (render-html-tree node)))
    (is (equal '(:strong "bold") tree))))

(test render-code-inline-tree
  "Inline code renders to (:code ...) form."
  (let* ((node (parse-node '(code "defun")))
         (tree (render-html-tree node)))
    (is (equal '(:code "defun") tree))))

(test render-section-tree
  "Section renders with heading based on depth."
  (let* ((doc (parse-document '(document (@ :title "Test")
                                (section (@ :title "Intro" :id "intro")
                                  (paragraph "Hello.")))))
         (section (first (node-children doc)))
         (tree (render-html-tree section)))
    ;; Should be (:section :id "intro" (:h2 "Intro") (:p "Hello."))
    (is (eq :section (first tree)))
    (is (string= "intro" (getf (cdr tree) :id)))
    ;; Find the heading
    (let ((h2 (find-if (lambda (x) (and (listp x) (eq :h2 (car x)))) tree)))
      (is (not (null h2)))
      (is (string= "Intro" (second h2))))))

(test render-nested-section-depth
  "Nested sections use h3 for depth 2."
  (let* ((doc (parse-document '(document (@ :title "Test")
                                (section (@ :title "Top")
                                  (section (@ :title "Sub")
                                    (paragraph "Deep."))))))
         (top (first (node-children doc)))
         (sub (find-if (lambda (c) (typep c 'lexis-section))
                       (node-children top)))
         (tree (render-html-tree sub)))
    (let ((h3 (find-if (lambda (x) (and (listp x) (eq :h3 (car x)))) tree)))
      (is (not (null h3)))
      (is (string= "Sub" (second h3))))))

(test render-code-block-tree
  "Code block renders to (:pre (:code ...)) form."
  (let* ((node (parse-node '(code-block (@ :language :lisp) "(+ 1 2)")))
         (tree (render-html-tree node)))
    (is (eq :pre (first tree)))
    (let ((code-form (second tree)))
      (is (eq :code (first code-form)))
      ;; Should have :class "language-lisp"
      (is (string= "language-lisp" (getf (cdr code-form) :class))))))

(test render-web-link-tree
  "Web link renders to (:a :href url ...) form."
  (let* ((node (parse-node '(web-link (@ :uri "https://example.com" :title "Ex")
                             "Click")))
         (tree (render-html-tree node)))
    (is (eq :a (first tree)))
    (is (string= "https://example.com" (getf (cdr tree) :href)))
    (is (string= "Ex" (getf (cdr tree) :title)))))

(test render-classic-link-tree
  "Classic link renders as plain <a> with converted URI."
  (let* ((node (parse-node '(classic-link (@ :uri "classic:example.com,2026:articles/test")
                             "the article")))
         (tree (render-html-tree node)))
    (is (eq :a (first tree)))
    (is (string= "https://example.com/articles/test" (getf (cdr tree) :href)))))

(test render-unordered-list-tree
  "Unordered list renders to (:ul (:li ...) ...) form."
  (let* ((node (parse-node '(unordered-list
                             (item "First")
                             (item "Second"))))
         (tree (render-html-tree node)))
    (is (eq :ul (first tree)))
    (is (= 2 (length (cdr tree))))
    (is (equal '(:li "First") (second tree)))))

(test render-image-tree
  "Image renders to (:img :src ... :alt ...) form."
  (let* ((node (parse-node '(image (@ :src "photo.jpg" :alt "A photo"))))
         (tree (render-html-tree node)))
    (is (eq :img (first tree)))
    (is (string= "photo.jpg" (getf (cdr tree) :src)))
    (is (string= "A photo" (getf (cdr tree) :alt)))))

(test render-blockquote-tree
  "Blockquote renders with optional cite footer."
  (let* ((node (parse-node '(blockquote (@ :source "Alan Kay")
                             (paragraph "Predict the future."))))
         (tree (render-html-tree node)))
    (is (eq :blockquote (first tree)))
    ;; Should contain a :p and a :footer
    (let ((footer (find-if (lambda (x) (and (listp x) (eq :footer (car x))))
                           (cdr tree))))
      (is (not (null footer))))))

(test render-figure-tree
  "Figure renders with figcaption."
  (let* ((node (parse-node '(figure (@ :id "fig-1")
                             (image (@ :src "arch.png" :alt "Architecture"))
                             (caption "Figure 1."))))
         (tree (render-html-tree node)))
    (is (eq :figure (first tree)))
    (is (string= "fig-1" (getf (cdr tree) :id)))))

(test render-unknown-tag-tree
  "Unknown tags render as div with prefixed class."
  (let* ((node (handler-bind ((unknown-tag-warning #'muffle-warning))
                 (parse-node '(custom-widget "content"))))
         (tree (render-html-tree node)))
    (is (eq :div (first tree)))
    (is (string= "lexis-custom-widget" (getf (cdr tree) :class)))))

;;; ============================================================
;;; Document-level rendering
;;; ============================================================

(test render-document-fragment
  "Document in fragment mode produces (:article ...) form."
  (let* ((doc (parse-document '(document (@ :title "Hello")
                                (paragraph "World."))))
         (tree (let ((*standalone* nil)) (render-html-tree doc))))
    (is (eq :article (first tree)))))

(test render-document-standalone
  "Document in standalone mode produces full (:html ...) form."
  (let* ((doc (parse-document '(document (@ :title "Hello")
                                (paragraph "World."))))
         (tree (let ((*standalone* t)) (render-html-tree doc))))
    (is (eq :html (first tree)))))

;;; ============================================================
;;; End-to-end: render-html string output
;;; ============================================================

(test render-html-string-output
  "render-html produces a non-empty HTML string."
  (let ((html (render-html '(document (@ :title "Test")
                             (paragraph "Hello, world.")))))
    (is (stringp html))
    (is (> (length html) 0))
    ;; Should contain the paragraph text
    (is (search "Hello, world." html))
    ;; Should contain an article tag (fragment mode)
    (is (search "<article>" html))))

(test render-html-with-inline-markup
  "render-html expands inline markup in text."
  (let ((html (render-html '(document (@ :title "Test")
                             (paragraph "This is *important* stuff.")))))
    (is (search "<em>" html))
    (is (search "important" html))))

(test render-html-standalone-mode
  "render-html with :standalone t produces full HTML document."
  (let ((html (render-html '(document (@ :title "Test")
                             (paragraph "Hello."))
                           :standalone t)))
    (is (search "<html" html))
    (is (search "<head>" html))
    (is (search "<title>" html))
    (is (search "Test" html))
    (is (search "<body>" html))))
