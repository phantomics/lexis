;;;; tags.lisp — Tag subclasses for the PoC subset of Lexis vocabulary

(in-package #:lexis)

;;; ============================================================
;;; Document structure
;;; ============================================================

(defclass lexis-document (lexis-element)
  ()
  (:default-initargs :tag 'document)
  (:documentation "The root node of a Lexis document.
Carries :title, :author, :date, :language metadata."))

(defmethod document-title ((node lexis-document))
  (get-attr node :title))

(defmethod document-author ((node lexis-document))
  (get-attr node :author))

(defmethod document-date ((node lexis-document))
  (get-attr node :date))

;;; ---

(defclass lexis-section (lexis-element)
  ((depth :accessor section-depth
          :initarg :depth
          :initform 1
          :type integer
          :documentation "Nesting depth of this section (1 = top-level).
Determines heading level in output: depth 1 → h2, depth 2 → h3, etc.
(h1 is reserved for document title.)"))
  (:default-initargs :tag 'section)
  (:documentation "A structural division of the document with a title.
Sections nest; depth is either explicit (:depth attr) or computed from nesting."))

(defmethod section-title ((node lexis-section))
  (get-attr node :title))

(defmethod section-id ((node lexis-section))
  (get-attr node :id))

;;; ============================================================
;;; Block-level content
;;; ============================================================

(defclass lexis-paragraph (lexis-element)
  ()
  (:default-initargs :tag 'paragraph)
  (:documentation "A block of text content — the fundamental prose unit."))

;;; ---

(defclass lexis-code-block (lexis-element)
  ()
  (:default-initargs :tag 'code-block)
  (:documentation "A block of preformatted code.
Content is literal — no inline markup processing is performed."))

(defmethod code-block-language ((node lexis-code-block))
  "Return the language as a string (normalizing keyword values)."
  (let ((lang (get-attr node :language)))
    (etypecase lang
      (null nil)
      (keyword (string-downcase (symbol-name lang)))
      (string lang)
      (symbol (string-downcase (symbol-name lang))))))

;;; ---

(defclass lexis-blockquote (lexis-element)
  ()
  (:default-initargs :tag 'blockquote)
  (:documentation "A block-level quotation with optional source attribution."))

(defmethod blockquote-source ((node lexis-blockquote))
  (get-attr node :source))

;;; ============================================================
;;; Lists
;;; ============================================================

(defclass lexis-unordered-list (lexis-element)
  ()
  (:default-initargs :tag 'unordered-list)
  (:documentation "A bulleted list. Children are lexis-item nodes."))

(defclass lexis-ordered-list (lexis-element)
  ()
  (:default-initargs :tag 'ordered-list)
  (:documentation "A numbered list. Children are lexis-item nodes."))

(defmethod ordered-list-start ((node lexis-ordered-list))
  (get-attr node :start 1))

(defclass lexis-item (lexis-element)
  ()
  (:default-initargs :tag 'item)
  (:documentation "An entry in an ordered or unordered list."))

;;; ============================================================
;;; Media
;;; ============================================================

(defclass lexis-image (lexis-element)
  ()
  (:default-initargs :tag 'image)
  (:documentation "An image reference. Void element (no children)."))

(defmethod image-src ((node lexis-image))
  (get-attr node :src))

(defmethod image-alt ((node lexis-image))
  (get-attr node :alt))

(defclass lexis-figure (lexis-element)
  ()
  (:default-initargs :tag 'figure)
  (:documentation "A figure wrapping an image or other content with a caption."))

(defmethod figure-id ((node lexis-figure))
  (get-attr node :id))

(defclass lexis-caption (lexis-element)
  ()
  (:default-initargs :tag 'caption)
  (:documentation "The caption of a figure or table."))

;;; ============================================================
;;; Inline elements
;;; ============================================================

(defclass lexis-emphasis (lexis-element)
  ()
  (:default-initargs :tag 'emphasis)
  (:documentation "Emphatic stress (typically rendered as italics)."))

(defclass lexis-strong (lexis-element)
  ()
  (:default-initargs :tag 'strong)
  (:documentation "Strong importance (typically rendered as bold)."))

(defclass lexis-code (lexis-element)
  ()
  (:default-initargs :tag 'code)
  (:documentation "Inline code fragment (typically monospace)."))

(defclass lexis-strikethrough (lexis-element)
  ()
  (:default-initargs :tag 'strikethrough)
  (:documentation "Text with a line through it."))

;;; ============================================================
;;; Links
;;; ============================================================

(defclass lexis-web-link (lexis-element)
  ()
  (:default-initargs :tag 'web-link)
  (:documentation "A hyperlink to a web resource."))

(defmethod web-link-uri ((node lexis-web-link))
  (get-attr node :uri))

(defmethod web-link-title ((node lexis-web-link))
  (get-attr node :title))

(defclass lexis-classic-link (lexis-element)
  ()
  (:default-initargs :tag 'classic-link)
  (:documentation "A link whose target is a Classic URI.
Non-Classic renderers treat this as a plain hyperlink."))

(defmethod classic-link-uri ((node lexis-classic-link))
  (get-attr node :uri))

(defclass lexis-cross-ref (lexis-element)
  ()
  (:default-initargs :tag 'cross-ref)
  (:documentation "A reference to another section or document."))

(defmethod cross-ref-target ((node lexis-cross-ref))
  (get-attr node :target))

;;; ============================================================
;;; Medium-dependent passthrough
;;; ============================================================

(defclass lexis-passthrough (lexis-element)
  ((raw-content
    :accessor passthrough-content
    :initarg :raw-content
    :initform nil
    :type list
    :documentation "Verbatim child forms preserved without recursive
Lexis parsing. Elements may be strings (emitted raw by the renderer)
or target-native s-expressions (e.g. Spinneret (:tag ...) forms for
the HTML medium)."))
  (:default-initargs :tag 'passthrough)
  (:documentation "Medium-dependent verbatim content.

A passthrough node carries opaque content intended for one or more
specific rendering targets, identified by the :medium attribute.
Renderers for matching media emit the content verbatim; renderers for
other media skip the node silently.

This is the canonical extension mechanism for target-specific output
that has no semantic equivalent in other media — HTML stylesheets and
scripts, LaTeX preamble commands, terminal escape sequences, JSON-LD
blocks for SEO, RSS channel metadata, and so on.

Attributes:
- :medium (keyword or list of keywords) — target medium designator(s).
  Common values: :html, :markdown, :latex, :terminal, :pdf, :epub.
  May also carry renderer-specific metadata attributes (:placement,
  :kind, :priority, etc.) that hosting renderers may interpret.

The children of a passthrough form are NOT parsed as Lexis nodes;
they are preserved in the raw-content slot and handed verbatim to
matching renderers."))

(defmethod passthrough-targets ((node lexis-passthrough))
  "Return the list of target medium keywords for this passthrough node.
A single-keyword :medium value is wrapped into a single-element list.
Returns NIL if no :medium attribute is present."
  (let ((value (get-attr node :medium)))
    (etypecase value
      (null nil)
      (keyword (list value))
      (list value))))

(defmethod passthrough-applies-p ((node lexis-passthrough) medium)
  "Return T if NODE's :medium attribute names MEDIUM as a target."
  (and (keywordp medium)
       (member medium (passthrough-targets node))
       t))

;;; ============================================================
;;; Unknown/extension tags
;;; ============================================================

(defclass lexis-unknown-element (lexis-element)
  ()
  (:documentation "Catch-all class for tags not in the core vocabulary.
Conforming processors render these by passing through their children."))
