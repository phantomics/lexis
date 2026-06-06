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

;;; ============================================================
;;; Passthrough rendering
;;; ============================================================

(test render-passthrough-spinneret-form
  "A passthrough targeting :html with a single Spinneret form renders
that form verbatim into the output."
  (let* ((node (parse-node '(passthrough (@ :medium :html)
                             (:link :rel "stylesheet" :href "style.css"))))
         (tree (render-html-tree node)))
    (is (eq :link (first tree)))
    (is (string= "stylesheet" (getf (cdr tree) :rel)))
    (is (string= "style.css" (getf (cdr tree) :href)))))

(test render-passthrough-string-content
  "A passthrough with a single string child emits it as raw HTML
via (:raw ...)."
  (let* ((node (parse-node '(passthrough (@ :medium :html)
                             "<meta name=\"viewport\" content=\"x\">")))
         (tree (render-html-tree node)))
    (is (eq :raw (first tree)))
    (is (string= "<meta name=\"viewport\" content=\"x\">" (second tree)))))

(test render-passthrough-non-matching-medium
  "A passthrough whose :medium does not include an HTML target renders
to NIL (and contributes nothing to the parent)."
  (let* ((node (parse-node '(passthrough (@ :medium :latex)
                             "\\usepackage{amsmath}")))
         (tree (render-html-tree node)))
    (is (null tree))))

(test render-passthrough-multi-target-includes-html
  "A passthrough targeting multiple media including :html does render
to HTML."
  (let* ((node (parse-node '(passthrough (@ :medium (:html :epub))
                             (:link :rel "stylesheet" :href "s.css"))))
         (tree (render-html-tree node)))
    (is (eq :link (first tree)))))

(test render-passthrough-in-document
  "A passthrough inside a document renders into the document output."
  (let ((html (render-html
               '(document (@ :title "Test")
                 (passthrough (@ :medium :html)
                   "<style>.note { color: red; }</style>")
                 (paragraph "Body.")))))
    (is (search "<style>.note { color: red; }</style>" html))
    (is (search "<p>" html))))

(test render-passthrough-non-html-is-omitted
  "A non-HTML passthrough inside a document is silently omitted."
  (let ((html (render-html
               '(document (@ :title "Test")
                 (passthrough (@ :medium :latex) "\\section{Foo}")
                 (paragraph "Body.")))))
    (is (not (search "\\section" html)))
    (is (search "<p>" html))))

(test render-passthrough-multiple-items-spliced
  "A passthrough with multiple raw items splices them at the parent
level (no wrapper element introduced)."
  (let ((html (render-html
               '(document (@ :title "Test")
                 (passthrough (@ :medium :html)
                   (:link :rel "stylesheet" :href "a.css")
                   (:link :rel "stylesheet" :href "b.css"))
                 (paragraph "Body.")))))
    (is (search "href=a.css" html))
    (is (search "href=b.css" html))
    ;; No :LEXIS-SPLICE leaked into the output as a tag
    (is (not (search "lexis-splice" html)))
    (is (not (search "lexis_splice" html)))))

(test render-passthrough-inline-position
  "A passthrough placed in inline position (inside a paragraph) renders
inline at its position."
  (let ((html (render-html
               '(document (@ :title "Test")
                 (paragraph "Before "
                            (passthrough (@ :medium :html)
                              "<span class=\"hl\">marked</span>")
                            " after.")))))
    (is (search "Before" html))
    (is (search "<span class=\"hl\">marked</span>" html))
    (is (search "after." html))))

(test render-passthrough-preserves-script-body
  "Inline script content with characters that would otherwise be
markup-expanded (asterisks, brackets, backticks) is preserved verbatim
in the HTML output."
  (let* ((script-body "var x = 1 * 2; // [[link]] *not markup*")
         (html (render-html
                `(document (@ :title "Test")
                  (passthrough (@ :medium :html)
                    (:script ,script-body))
                  (paragraph "After script.")))))
    (is (search script-body html))))

(test render-passthrough-nickname-pthru
  "The PTHRU nickname renders identically to PASSTHROUGH."
  (let ((html (render-html
               '(document (@ :title "Test")
                 (pthru (@ :medium :html)
                   "<meta charset=\"utf-8\">")))))
    (is (search "<meta charset=\"utf-8\">" html))))
