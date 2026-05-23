;;;; lexis.html.asd — ASDF system definition for Lexis HTML renderer
;;;;
;;;; Renders Lexis document object trees to Spinneret-compatible
;;;; (:html ...) forms and HTML strings.

(asdf:defsystem "lexis.html"
  :description "Lexis HTML renderer via Spinneret"
  :version "0.1.0"
  :license "BSD-3"
  :depends-on ("lexis" "spinneret")
  :pathname "src/html/"
  :serial t
  :components
  ((:file "package")
   (:file "render")))
