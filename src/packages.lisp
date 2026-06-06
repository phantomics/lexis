;;;; packages.lisp — Package definition for Lexis core

(defpackage #:lexis
  (:use #:cl)
  (:export

   ;; ---- Conditions ----
   #:lexis-error
   #:malformed-document
   #:unknown-tag-warning

   ;; ---- Utilities ----
   #:normalize-attrs
   #:get-attr
   #:extract-tag-parts

   ;; ---- Node base classes ----
   #:lexis-node
   #:lexis-text-node
   #:node-text

   #:lexis-element
   #:node-tag
   #:node-attrs
   #:node-children

   ;; ---- Tag classes (PoC subset) ----
   #:lexis-document
   #:document-title
   #:document-author
   #:document-date

   #:lexis-section
   #:section-title
   #:section-id
   #:section-depth

   #:lexis-paragraph

   #:lexis-code-block
   #:code-block-language

   #:lexis-blockquote
   #:blockquote-source

   #:lexis-unordered-list
   #:lexis-ordered-list
   #:ordered-list-start
   #:lexis-item

   #:lexis-image
   #:image-src
   #:image-alt

   #:lexis-figure
   #:figure-id
   #:lexis-caption

   ;; ---- Inline elements ----
   #:lexis-emphasis
   #:lexis-strong
   #:lexis-code
   #:lexis-strikethrough
   #:lexis-web-link
   #:web-link-uri
   #:web-link-title
   #:lexis-classic-link
   #:classic-link-uri
   #:lexis-cross-ref
   #:cross-ref-target

   ;; ---- Medium-dependent passthrough ----
   #:lexis-passthrough
   #:passthrough-content
   #:passthrough-targets
   #:passthrough-applies-p

   ;; ---- Unknown/extension tags ----
   #:lexis-unknown-element

   ;; ---- Parsing ----
   #:parse-document
   #:parse-node
   #:register-tag
   #:tag->class

   ;; ---- Text processing ----
   #:process-text))
