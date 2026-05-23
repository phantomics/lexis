# Lexis

**Lisp EXpressions as Interchange Syntax**

Lexis is an s-expression document format and a Common Lisp library for
processing it. Documents are written as nested s-expressions using a
semantic tag vocabulary — `section`, `paragraph`, `emphasis`, `code-block`
— rather than HTML elements. The library parses these into a CLOS object
tree and renders them to HTML via Spinneret.

Lexis is designed as a data format. A Lexis document is a valid Common Lisp
s-expression that can be read with `cl:read`, stored as a file, embedded in
other s-expression structures, and transformed by any Lisp program. No
reader macros or compile-time evaluation are required.

## Quick Start

Load the system and render a document at the REPL:

```lisp
(ql:quickload "lexis.html")

(lexis.html:render-html
 '(document (@ :title "Hello")
   (section (@ :title "Greeting" :id "greet")
     (paragraph "This is *Lexis* — an s-expression document format.")
     (paragraph "It supports [[links|https://example.com]] and **bold** text."))))
```

Output:

```html
<article>
 <header>
  <h1>Hello</h1>
 </header>
 <section id=greet>
  <h2>Greeting</h2>
  <p>This is <em>Lexis</em> — an s-expression document format.</p>
  <p>It supports <a href=https://example.com>links</a> and <strong>bold</strong> text.</p>
 </section>
</article>
```

The inline markup (`*...*`, `**...**`, `[[...|...]]`) is expanded
automatically by the text processing pass before rendering.

## Installation

Lexis depends on `cl-ppcre` (core) and `spinneret` (HTML renderer), both
available via Quicklisp. Place or symlink the `lexis/` directory into your
ASDF source registry or `~/quicklisp/local-projects/`:

```sh
ln -s /path/to/lexis ~/quicklisp/local-projects/lexis
```

Then:

```lisp
(ql:quickload "lexis")       ; core: parsing, text processing, object model
(ql:quickload "lexis.html")  ; HTML renderer (loads core automatically)
```

## Architecture

The rendering pipeline has four stages:

```
Lexis s-expr  →  parse  →  process-text  →  render-html-tree  →  HTML string
   (read)       CLOS tree    expand inline     Spinneret form     (interpret-html-tree)
```

1. **Parse** — `cl:read` produces a nested list; `lexis:parse-document`
   walks it, instantiating CLOS node objects from the tag registry.

2. **Text processing** — `lexis:process-text` scans text nodes for inline
   markup patterns and expands them into proper element nodes.

3. **Render** — `lexis.html:render-html-tree` dispatches a generic function
   per node class, producing a Spinneret-compatible `(:tag ...)` tree.

4. **Emit** — Spinneret's `interpret-html-tree` writes the HTML string.

`lexis.html:render-html` runs the full pipeline in one call.

## API Reference

### Core (`"lexis"` system)

#### Parsing

```lisp
(lexis:parse-document form)  ; → lexis-document instance
(lexis:parse-node form)      ; → lexis-node (text-node or element subclass)
```

`parse-document` expects a list beginning with `document`. It parses the
tree and computes section nesting depths. `parse-node` handles individual
nodes and is called recursively during parsing.

#### Text Processing

```lisp
(lexis:process-text node)  ; → node (with inline markup expanded)
```

Expands the following patterns within text strings, in order:

| Pattern | Expansion |
|---------|-----------|
| `` `code` `` | `lexis-code` |
| `[[text\|uri]]` | `lexis-web-link` or `lexis-classic-link` |
| `[[target]]` | `lexis-cross-ref` |
| `**bold**` | `lexis-strong` |
| `*italic*` | `lexis-emphasis` |
| `~~struck~~` | `lexis-strikethrough` |

Content inside backtick code spans is not further processed.

#### Node Access

```lisp
(lexis:node-tag element)       ; → symbol (e.g. SECTION, PARAGRAPH)
(lexis:node-attrs element)     ; → plist (:title "..." :id "...")
(lexis:node-children element)  ; → list of child nodes
(lexis:node-text text-node)    ; → string content
(lexis:get-attr element :key)  ; → attribute value or NIL
```

Each tag class provides typed accessors:

```lisp
(lexis:section-title section)       ; → string
(lexis:section-id section)          ; → string or NIL
(lexis:section-depth section)       ; → integer (1 = top-level)
(lexis:document-title doc)          ; → string
(lexis:code-block-language block)   ; → string (e.g. "lisp")
(lexis:web-link-uri link)           ; → string
(lexis:image-src image)             ; → string
(lexis:image-alt image)             ; → string
```

#### Tag Registry

```lisp
(lexis:register-tag 'my-tag 'my-tag-class)  ; extend the vocabulary
(lexis:tag->class 'some-tag)                ; → class name or 'lexis-unknown-element
```

Tags not in the registry parse as `lexis-unknown-element` (with a warning)
and render via pass-through.

### HTML Renderer (`"lexis.html"` system)

```lisp
(lexis.html:render-html document &key standalone process-text)
```

Renders a Lexis document (s-expression or parsed node tree) to an HTML
string. Options:

- `:standalone t` — Produce a full `<html><head>...<body>...` page.
  Default `nil` produces an `<article>` fragment.
- `:process-text t` — Expand inline markup before rendering (default `t`).

```lisp
(lexis.html:render-html-tree node)
```

Renders a single node to a Spinneret tree form (a nested list like
`(:section :id "intro" (:h2 "Title") (:p "..."))`) without emitting HTML
text. Useful for embedding Lexis-rendered content inside larger Spinneret
templates.

#### Tag-to-HTML Mapping

| Lexis Tag | HTML Output |
|-----------|-------------|
| `document` | `<article>` (or full page in standalone mode) |
| `section` | `<section>` with `<h2>`–`<h6>` based on depth |
| `paragraph` | `<p>` |
| `emphasis` | `<em>` |
| `strong` | `<strong>` |
| `code` | `<code>` (inline) |
| `code-block` | `<pre><code class="language-X">` |
| `blockquote` | `<blockquote>` with `<footer><cite>` |
| `web-link` | `<a href="...">` |
| `classic-link` | `<a href="...">` (classic: URI converted to https://) |
| `cross-ref` | `<a href="#target">` |
| `unordered-list` | `<ul>` |
| `ordered-list` | `<ol>` |
| `item` | `<li>` |
| `image` | `<img>` |
| `figure` | `<figure>` |
| `caption` | `<figcaption>` |
| `strikethrough` | `<s>` |
| Unknown tags | `<div class="lexis-tagname">` |

## Extending Lexis

Define a new tag class and register it:

```lisp
(defclass my-callout (lexis:lexis-element)
  ()
  (:default-initargs :tag 'callout))

(lexis:register-tag 'callout 'my-callout)
```

Add a render method:

```lisp
(defmethod lexis.html:render-html-tree ((node my-callout))
  `(:aside :class "callout"
    ,@(lexis.html::render-children node)))
```

The node will now parse and render without warnings.

## Examples

A fuller demonstration is in `examples/demo.lisp`. After loading
`"lexis.html"`, load the file and call the demo functions:

```lisp
(ql:quickload "lexis.html")
(load "examples/demo.lisp")

(demo-fragment)    ; render sample blog post as HTML fragment
(demo-standalone)  ; render as complete HTML page
(demo-tree)        ; show the intermediate Spinneret tree
(demo-parse)       ; inspect the parsed CLOS object tree
```

## Running Tests

```lisp
(ql:quickload "lexis/tests")
(lexis/tests:run-tests)
```

Or from the shell:

```sh
sbcl --non-interactive \
  --eval '(ql:quickload "lexis/tests" :silent t)' \
  --eval '(unless (lexis/tests:run-tests) (uiop:quit 1))'
```

## Document Format

See `doc/lexis-spec.md` for the full format specification, including:

- Core tag vocabulary (Section 4)
- Inline markup patterns (Section 3)
- Attribute syntax — keyword plist and alist forms (Section 2.2)
- Extension mechanism for custom tags (Section 5)
- Optional Classic integration for semantic enrichment (Section 6)
- Multi-target rendering considerations (Section 8)

## Status

This is a proof-of-concept implementation covering the core tag subset.
The format specification is at version 0.1 (working draft). Both are
expected to evolve.

**Implemented:**
- Full parsing pipeline with CLOS object model
- Inline text processing (code spans, links, strong, emphasis, strikethrough)
- HTML rendering via Spinneret for the core tag vocabulary
- Package-independent document parsing (documents can be read in any CL package)
- Graceful handling of unknown/extension tags
- Classic URI to HTTP conversion for `classic-link` nodes

**Planned:**
- Additional renderers (terminal/ANSI, Markdown, plain text)
- Resolution pass for cross-references
- Classic integration (triplestore-backed URI resolution)
- Definition lists, tables, footnotes (remaining core tags)
- Document validation

## License

TBD
