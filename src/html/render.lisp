;;;; render.lisp — Lexis to Spinneret HTML tree rendering
;;;;
;;;; Produces Spinneret-compatible s-expression HTML forms from
;;;; Lexis document node trees.

(in-package #:lexis.html)

;;; ============================================================
;;; Configuration
;;; ============================================================

(defvar *standalone* nil
  "When T, render-html-tree produces a complete HTML document
(:html (:head ...) (:body ...)).  When NIL (default), produces
an (:article ...) fragment suitable for embedding in a page layout.")

(defvar *css-class-prefix* "lexis-"
  "Prefix applied to CSS class names generated for unknown/extension tags.")

;;; ============================================================
;;; Generic rendering protocol
;;; ============================================================

(defgeneric render-html-tree (node)
  (:documentation "Render a Lexis node to a Spinneret HTML tree form.
Returns a nested list structure suitable for spinneret:interpret-html-tree
or embedding within spinneret:with-html."))

;;; ============================================================
;;; Top-level entry point
;;; ============================================================

(defun render-html (document &key (standalone *standalone*) (process-text t))
  "Render a Lexis document to an HTML string.
DOCUMENT may be either a lexis-document instance or a raw s-expression.
If PROCESS-TEXT is T (default), inline markup in text strings is expanded first.
If STANDALONE is T, produces a complete HTML page; otherwise an article fragment."
  (let* ((*standalone* standalone)
         (doc (etypecase document
                (lexis-document document)
                (cons (parse-document document))))
         (processed (if process-text (process-text doc) doc))
         (tree (render-html-tree processed))
         (out (make-string-output-stream)))
    (let ((spinneret:*html-style* :tree)
          (spinneret:*html* out))
      (spinneret:interpret-html-tree tree))
    (get-output-stream-string out)))

;;; ============================================================
;;; Text nodes
;;; ============================================================

(defmethod render-html-tree ((node lexis-text-node))
  "Text nodes render as their string content."
  (node-text node))

;;; ============================================================
;;; Document
;;; ============================================================

(defmethod render-html-tree ((node lexis-document))
  (let ((title (document-title node))
        (body-content (render-children node)))
    (if *standalone*
        `(:html
          (:head
           ,@(when title `((:title ,title)))
           (:meta :charset "utf-8")
           (:meta :name "viewport" :content "width=device-width, initial-scale=1"))
          (:body
           (:article
            ,@(when title `((:header (:h1 ,title))))
            ,@body-content)))
        `(:article
          ,@(when title `((:header (:h1 ,title))))
          ,@body-content))))

;;; ============================================================
;;; Sections
;;; ============================================================

(defmethod render-html-tree ((node lexis-section))
  (let* ((title (section-title node))
         (id (section-id node))
         (depth (section-depth node))
         ;; h1 reserved for document title; sections start at h2
         (heading-level (min (1+ depth) 6))
         (heading-tag (intern (format nil "H~D" heading-level) :keyword)))
    `(:section
      ,@(when id `(:id ,id))
      ,@(when title `((,heading-tag ,title)))
      ,@(render-children node))))

;;; ============================================================
;;; Block-level content
;;; ============================================================

(defmethod render-html-tree ((node lexis-paragraph))
  `(:p ,@(render-children node)))

(defmethod render-html-tree ((node lexis-code-block))
  (let ((lang (code-block-language node))
        (content (render-children-as-text node)))
    `(:pre
      (:code
       ,@(when lang `(:class ,(format nil "language-~A" lang)))
       ,content))))

(defmethod render-html-tree ((node lexis-blockquote))
  (let ((source (blockquote-source node)))
    `(:blockquote
      ,@(render-children node)
      ,@(when source
          `((:footer (:cite ,source)))))))

;;; ============================================================
;;; Lists
;;; ============================================================

(defmethod render-html-tree ((node lexis-unordered-list))
  `(:ul ,@(render-children node)))

(defmethod render-html-tree ((node lexis-ordered-list))
  (let ((start (ordered-list-start node)))
    `(:ol
      ,@(unless (= start 1) `(:start ,start))
      ,@(render-children node))))

(defmethod render-html-tree ((node lexis-item))
  `(:li ,@(render-children node)))

;;; ============================================================
;;; Media
;;; ============================================================

(defmethod render-html-tree ((node lexis-image))
  (let ((src (image-src node))
        (alt (image-alt node)))
    `(:img :src ,src ,@(when alt `(:alt ,alt)))))

(defmethod render-html-tree ((node lexis-figure))
  (let ((id (figure-id node)))
    `(:figure
      ,@(when id `(:id ,id))
      ,@(render-children node))))

(defmethod render-html-tree ((node lexis-caption))
  `(:figcaption ,@(render-children node)))

;;; ============================================================
;;; Inline elements
;;; ============================================================

(defmethod render-html-tree ((node lexis-emphasis))
  `(:em ,@(render-children node)))

(defmethod render-html-tree ((node lexis-strong))
  `(:strong ,@(render-children node)))

(defmethod render-html-tree ((node lexis-code))
  `(:code ,@(render-children node)))

(defmethod render-html-tree ((node lexis-strikethrough))
  `(:s ,@(render-children node)))

;;; ============================================================
;;; Links
;;; ============================================================

(defmethod render-html-tree ((node lexis-web-link))
  (let ((uri (web-link-uri node))
        (title (web-link-title node)))
    `(:a :href ,uri
         ,@(when title `(:title ,title))
         ,@(render-children node))))

(defmethod render-html-tree ((node lexis-classic-link))
  "Render Classic links as plain <a> tags.
Converts classic: URI scheme to https:// via standard mapping."
  (let* ((uri (classic-link-uri node))
         (http-uri (classic-uri-to-http uri)))
    `(:a :href ,http-uri
         ,@(render-children node))))

(defmethod render-html-tree ((node lexis-cross-ref))
  (let ((target (cross-ref-target node)))
    `(:a :href ,(format nil "#~A" target)
         ,@(render-children node))))

;;; ============================================================
;;; Unknown/extension tags — pass-through rendering
;;; ============================================================

(defmethod render-html-tree ((node lexis-unknown-element))
  "Unknown tags render as a div with a CSS class derived from the tag name."
  (let ((class-name (format nil "~A~A" *css-class-prefix*
                            (string-downcase (symbol-name (node-tag node))))))
    `(:div :class ,class-name
           ,@(render-children node))))

;;; ============================================================
;;; Helpers
;;; ============================================================

(defun render-children (node)
  "Render all children of NODE, returning a list of HTML tree forms.
Filters out empty strings."
  (loop for child in (node-children node)
        for rendered = (render-html-tree child)
        when rendered
          collect rendered))

(defun render-children-as-text (node)
  "Concatenate all text content of NODE's children into a single string.
Used for code-block where content is always literal text."
  (with-output-to-string (s)
    (labels ((collect-text (n)
               (etypecase n
                 (lexis-text-node (write-string (node-text n) s))
                 (lexis-element (mapc #'collect-text (node-children n))))))
      (mapc #'collect-text (node-children node)))))

(defun classic-uri-to-http (classic-uri)
  "Convert a classic: URI to an https:// URL.
classic:authority,date:path → https://authority/path
If the URI doesn't start with 'classic:', return it unchanged."
  (if (and (>= (length classic-uri) 8)
           (string= "classic:" classic-uri :end2 8))
      (let* ((rest (subseq classic-uri 8))
             ;; Find the comma separating authority from date
             (comma-pos (position #\, rest))
             (authority (if comma-pos (subseq rest 0 comma-pos) rest))
             ;; Find the colon after the date that starts the path
             (colon-pos (when comma-pos (position #\: rest :start (1+ comma-pos))))
             (path (if colon-pos (subseq rest (1+ colon-pos)) "")))
        (format nil "https://~A/~A" authority path))
      classic-uri))
