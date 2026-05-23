;;;; test-util.lisp — Tests for attribute normalization and utilities

(in-package #:lexis/tests)
(in-suite util-suite)

;;; ============================================================
;;; normalize-attrs
;;; ============================================================

(test normalize-keyword-plist
  "Keyword plist attributes are preserved as-is."
  (let ((result (normalize-attrs '(:id "intro" :title "Introduction" :depth 2))))
    (is (equal '(:id "intro" :title "Introduction" :depth 2) result))))

(test normalize-alist
  "Association list attributes are converted to keyword plist."
  (let ((result (normalize-attrs '((src "photo.jpg") (alt "A landscape")))))
    (is (equal '(:src "photo.jpg" :alt "A landscape") result))))

(test normalize-empty-attrs
  "NIL attributes normalize to NIL."
  (is (null (normalize-attrs nil))))

(test normalize-keyword-alist-keys
  "Alist entries with keyword keys pass through."
  (let ((result (normalize-attrs '((:src "photo.jpg") (:alt "test")))))
    (is (equal '(:src "photo.jpg" :alt "test") result))))

(test normalize-invalid-plist-signals
  "Non-keyword in plist position signals malformed-document."
  (signals malformed-document
    (normalize-attrs '("not-a-keyword" "value"))))

;;; ============================================================
;;; extract-tag-parts
;;; ============================================================

(test extract-parts-no-attrs
  "Tag without attributes returns nil attrs and all children."
  (multiple-value-bind (tag attrs children)
      (extract-tag-parts '(paragraph "Hello" "world"))
    (is (eq 'paragraph tag))
    (is (null attrs))
    (is (equal '("Hello" "world") children))))

(test extract-parts-with-attrs
  "Tag with @ attributes extracts attrs and remaining children."
  (multiple-value-bind (tag attrs children)
      (extract-tag-parts '(section (@ :id "intro" :title "Intro") "content"))
    (is (eq 'section tag))
    (is (equal '(:id "intro" :title "Intro") attrs))
    (is (equal '("content") children))))

(test extract-parts-attrs-only
  "Tag with attributes but no children."
  (multiple-value-bind (tag attrs children)
      (extract-tag-parts '(image (@ :src "test.png" :alt "Test")))
    (is (eq 'image tag))
    (is (equal '(:src "test.png" :alt "Test") attrs))
    (is (null children))))
