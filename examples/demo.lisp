;;;; demo.lisp — Demonstration of Lexis rendering
;;;;
;;;; Load this file after (asdf:load-system "lexis.html") to see
;;;; the rendering pipeline in action.

(in-package #:cl-user)

;;; A sample Lexis document (from the spec, Section 9.1)
(defparameter *sample-blog-post*
  '(document (@ :title "Getting Started with Lexis"
                :author "Jane Doe"
                :date "2026-05-22")

    (section (@ :title "What is Lexis?" :id "what")
      (paragraph "Lexis is an s-expression document format. It represents
documents as nested lists that any Lisp program can read and transform.")
      (paragraph "Unlike Markdown, Lexis separates *semantic structure*
from presentation. Unlike HTML, it uses a vocabulary of
**document concepts** rather than rendering instructions."))

    (section (@ :title "A Quick Example" :id "example")
      (paragraph "Here is a Lexis code block:")
      (code-block (@ :language :lisp)
        "(document (@ :title \"Hello\")
  (paragraph \"World.\"))")
      (paragraph "The format is simple enough to write by hand and
structured enough for programmatic generation."))

    (section (@ :title "Further Reading" :id "further")
      (paragraph "See [[the Lexis specification|https://example.com/lexis]]
for the full format description.")
      (unordered-list
        (item "SXML -- the s-expression XML representation")
        (item "Skribilo -- functional document authoring in Scheme")
        (item "CommonDoc -- a Common Lisp document object model")))))

;;; Render to HTML fragment
(defun demo-fragment ()
  "Render the sample document as an HTML fragment and print it."
  (let ((html (lexis.html:render-html *sample-blog-post*)))
    (format t "~%=== HTML Fragment ===~%~A~%" html)
    html))

;;; Render to full standalone HTML
(defun demo-standalone ()
  "Render the sample document as a complete HTML page and print it."
  (let ((html (lexis.html:render-html *sample-blog-post* :standalone t)))
    (format t "~%=== Standalone HTML ===~%~A~%" html)
    html))

;;; Show the intermediate Spinneret tree
(defun demo-tree ()
  "Parse and render to the intermediate Spinneret tree form."
  (let* ((doc (lexis:parse-document *sample-blog-post*))
         (processed (lexis:process-text doc))
         (tree (lexis.html:render-html-tree processed)))
    (format t "~%=== Spinneret Tree ===~%")
    (pprint tree)
    tree))

;;; Show the parsed document structure
(defun demo-parse ()
  "Parse the sample document and inspect the object tree."
  (let ((doc (lexis:parse-document *sample-blog-post*)))
    (format t "~%=== Parsed Document ===~%")
    (describe doc)
    (format t "~%--- Children ---~%")
    (dolist (child (lexis:node-children doc))
      (format t "  ~A~%" child)
      (when (typep child 'lexis:lexis-section)
        (dolist (grandchild (lexis:node-children child))
          (format t "    ~A~%" grandchild))))
    doc))
