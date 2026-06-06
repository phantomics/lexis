# Lexis: Lisp EXpressions as Interchange Syntax

## Document Format Specification

**Version:** 0.1 (Draft)
**Date:** 2026-05-22
**Status:** Working draft


## 1. Introduction

Lexis is an s-expression document format for representing structured text
content. It encodes document semantics -- sections, paragraphs, emphasis,
references, lists, tables, figures -- as nested s-expressions that can be
read, written, stored, queried, and transformed using standard Lisp tooling.

Lexis is designed as a **data format**, not a macro language. A Lexis document
is a valid Common Lisp s-expression that can be read with `cl:read` and
written with `cl:write`. No special reader macros or compile-time evaluation
are required for the core format. Documents are pure data: serializable,
introspectable, and transportable.

### 1.1 Design Goals

- **Semantic, not presentational.** Tags represent document concepts
  (`section`, `emphasis`, `code-block`), not rendering instructions
  (`div`, `em`, `pre`). The mapping from Lexis nodes to a specific output
  format (HTML, terminal, PDF, JSON-LD) is the renderer's responsibility.

- **Data-first.** Lexis documents are s-expressions that can be stored as
  files, embedded in other s-expression formats, persisted as blobs in a
  database, and manipulated by any Lisp program without specialized tooling.

- **Extensible.** The core vocabulary covers common document elements.
  Domain-specific extensions (wiki infoboxes, scientific notation, legal
  citations) add new tag types that conforming processors may handle or
  ignore gracefully.

- **Medium-independent.** The same Lexis document can be rendered to HTML
  for web publication, ANSI-formatted text for a terminal interface,
  plain text for search indexing, or JSON-LD for structured data export.

- **Optionally enriched.** The core format is self-contained and useful
  without any external system. An optional integration layer allows
  embedding references to external ontological systems (such as Classic)
  that enrich the document with typed relationships and semantic identity,
  without breaking compatibility with processors that do not understand
  those extensions.

### 1.2 Relationship to Prior Art

Lexis draws on several predecessors:

- **SXML** (Kiselyov): The `@` attribute marker convention and the
  principle of representing markup as pure s-expression data.
- **Skribilo** (Gallesio & Serrano): Semantic tag vocabulary independent
  of output format, with engine-based multi-target rendering.
- **CommonDoc** (Borretti): The node class taxonomy covering standard
  document elements (paragraph, markup types, lists, tables, figures).
- **Pollen** (Butterick): Extensible tag vocabularies defined per-document
  or per-project.
- **Scribble** (Flatt & Barzilay): Multi-pass processing with decode,
  resolve, and render phases.

Lexis differs from these in combining s-expression data representation
(not macros or compile-time forms), a semantic vocabulary (not HTML
mirroring), Common Lisp nativity, and an optional extension mechanism
for ontological enrichment.


## 2. Core Format

### 2.1 Document Structure

A Lexis document is a nested s-expression rooted at a `document` node.
Every node is either:

- A **tagged node**: a list whose first element is a symbol (the tag),
  optionally followed by an attribute list, followed by zero or more
  children.
- A **text node**: a string.

```
node     := tagged-node | text-node
tagged-node := (tag [attributes] child*)
text-node   := string
tag         := symbol
child       := node
```

A minimal document:

```lisp
(document
  (paragraph "Hello, world."))
```

### 2.2 Attributes

Attributes are metadata attached to a tagged node. They are introduced
by the distinguished symbol `@` as the first child of the tagged node:

```lisp
(tag (@ attribute*) child*)
```

The `@` symbol cannot be a valid tag name (by convention), so its
presence as the first child unambiguously signals an attribute list.

Attributes may be written in two forms. The form is determined by
the type of the first element after `@`:

**Keyword plist form.** When the first element after `@` is a keyword
symbol, the attribute list is parsed as a property list of alternating
keyword keys and values:

```lisp
(section (@ :id "intro" :title "Introduction" :depth 2)
  ...)
```

Values may be strings, numbers, symbols, or nested s-expressions.

**Association list form.** When the first element after `@` is a list,
the attribute list is parsed as an association list of `(key value)`
pairs:

```lisp
(image (@ (src "photo.jpg")
          (alt "A landscape photograph")
          (srcset ("photo-1x.jpg 1x" "photo-2x.jpg 2x")))
  ...)
```

The alist form is preferred when attribute values are themselves
structured (lists, nested attributes).

Both forms normalize to a canonical internal representation during
processing. A conforming processor must accept both forms and treat
them equivalently.

A tagged node without attributes omits the `@` list entirely:

```lisp
(paragraph "No attributes on this paragraph.")
```

### 2.3 Text Nodes

Text content is represented as string literals within a tagged node's
children. Adjacent strings within the same parent are logically
concatenated:

```lisp
(paragraph "This is one " "continuous paragraph.")
```

Text nodes may contain inline markup patterns that are expanded during
a text processing pass (see Section 3).

### 2.4 Whitespace

Whitespace handling follows these rules:

- Leading and trailing whitespace within a text node is preserved as-is
  (the s-expression reader handles string content literally).
- Whitespace between sibling nodes (outside of strings) is not
  significant (it is consumed by the s-expression reader).
- Line breaks within multi-line strings are preserved.

Renderers are responsible for collapsing or preserving whitespace as
appropriate for their output format (e.g., HTML collapses whitespace;
a terminal renderer may preserve it).


## 3. Inline Markup

Text strings within Lexis documents may contain lightweight inline
markup patterns. These are expanded by a **text processing pass** into
proper Lexis nodes before rendering. This pass is optional -- a
processor that skips it simply treats the patterns as literal text.

### 3.1 Links

```
[[display text|uri]]
```

Expands to a link node. The URI scheme determines the link type:

- `https://` or `http://` URIs expand to `web-link` nodes.
- `classic:` URIs expand to `classic-link` nodes (see Section 6).
- Bare text without a URI (`[[Page Name]]`) expands to a `cross-ref`
  node, interpreted as a reference to another document by title or
  identifier.

Examples:

```
"See [[Wikipedia|https://en.wikipedia.org]] for more."
"Refer to [[the architecture article|classic:janedoe.net,2026:articles/abc-arch]]."
"This concept is explained in [[Ontological Composition]]."
```

The `|` character separates display text from URI. If the display text
is omitted, the processor may derive it from the URI (e.g., by
resolving a Classic URI to its resource's title, or by using the
final path component of a web URL).

### 3.2 Emphasis

```
*italic text*     ->  (emphasis "italic text")
**bold text**     ->  (strong "bold text")
~~struck text~~   ->  (strikethrough "struck text")
`inline code`     ->  (code "inline code")
```

These patterns follow Markdown conventions. The rules for matching:

- `*` for emphasis: a single `*` not preceded or followed by whitespace
  opens emphasis; the next matching `*` closes it. Does not span across
  paragraph boundaries.
- `**` for strong: same rules, with doubled delimiters taking precedence
  over single.
- `~~` for strikethrough: same matching rules.
- Single backtick for inline code: content is literal (no further inline
  processing within backticks).

Inline patterns do not nest within each other via the text syntax.
For nested inline markup, use explicit Lexis nodes:

```lisp
(paragraph "This has " (strong "bold with " (emphasis "italic") " inside") ".")
```

### 3.3 Processing Order

The text processing pass scans each text string for inline patterns and
replaces them with the corresponding Lexis nodes. The pass operates on
a complete parsed Lexis tree, replacing text nodes with sequences of
text nodes and inline element nodes. Processing order within a string:

1. Code spans (backticks) -- extracted first, their content is not
   further processed.
2. Links (`[[...]]`) -- extracted next.
3. Strong (`**...**`) -- before emphasis to avoid ambiguity.
4. Emphasis (`*...*`).
5. Strikethrough (`~~...~~`).


## 4. Core Tag Vocabulary

The following tags constitute the core Lexis vocabulary. A conforming
processor must understand all of these. Additional tags may be defined
by extensions (see Section 5).

### 4.1 Document Structure

**`document`** -- The root node of a Lexis document.

Attributes:
- `:title` (string) -- Document title.
- `:author` (string or URI) -- Author name or identifier.
- `:date` (string) -- Publication or creation date (ISO 8601 recommended).
- `:language` (string) -- BCP 47 language tag (e.g., `"en"`, `"fr"`).
- `:version` (string) -- Document version identifier.
- `:rights` (string) -- Copyright or license statement.

Children: zero or more block-level nodes (`section`, `paragraph`, etc.).

```lisp
(document (@ :title "My Article" :author "Jane Doe" :date "2026-05-22")
  (section ...)
  (paragraph ...))
```

**`section`** -- A structural division of the document.

Attributes:
- `:title` (string) -- Section heading text. Required.
- `:id` (string) -- Unique identifier for cross-referencing.
- `:depth` (integer) -- Explicit nesting depth (normally inferred from
  structural nesting).

Children: zero or more block-level or inline nodes.

Sections may nest. The heading level in rendered output is determined
by nesting depth (a top-level section renders as `<h2>` in HTML, a
section within a section as `<h3>`, etc., with `<h1>` reserved for
the document title).

```lisp
(section (@ :title "Introduction" :id "intro")
  (paragraph "Opening text.")
  (section (@ :title "Background")
    (paragraph "Nested subsection.")))
```

### 4.2 Block-Level Content

**`paragraph`** -- A block of text content. The fundamental prose unit.

No required attributes. Children: text nodes and inline elements.

```lisp
(paragraph "A simple paragraph with " (emphasis "emphasis") ".")
```

**`code-block`** -- A block of preformatted code or text.

Attributes:
- `:language` (string or keyword) -- Programming language for syntax
  highlighting (e.g., `:lisp`, `"python"`, `"javascript"`).
- `:caption` (string) -- Optional caption.

Children: a single text node containing the code. No inline markup
processing is performed on code-block content.

```lisp
(code-block (@ :language :lisp)
  "(defclass classic-article (classic-creative-work)
  ((headline :accessor headline
             :initarg :headline))
  (:metaclass classic-class))")
```

**`blockquote`** -- A block-level quotation.

Attributes:
- `:source` (string) -- Attribution for the quotation.
- `:uri` (string) -- URI of the quoted source.

Children: block-level nodes (typically paragraphs).

```lisp
(blockquote (@ :source "Alan Kay")
  (paragraph "The best way to predict the future is to invent it."))
```

**`aside`** -- Tangential content (a sidebar, callout, or note).

Attributes:
- `:kind` (keyword) -- Categorization: `:note`, `:warning`, `:tip`,
  `:example`, or any domain-specific keyword.

Children: block-level nodes.

```lisp
(aside (@ :kind :warning)
  (paragraph "This operation cannot be undone."))
```

### 4.3 Lists

**`unordered-list`** -- A bulleted list.

Children: one or more `item` nodes.

**`ordered-list`** -- A numbered list.

Attributes:
- `:start` (integer) -- Starting number (default 1).

Children: one or more `item` nodes.

**`definition-list`** -- A list of term/definition pairs.

Children: one or more `definition` nodes.

**`item`** -- An entry in an ordered or unordered list.

Children: inline and/or block-level nodes. A list item containing only
inline content is rendered as a simple list entry; one containing
block-level nodes (paragraphs, nested lists) is rendered as a complex
list entry.

```lisp
(unordered-list
  (item "Simple text item.")
  (item (paragraph "Complex item with")
        (paragraph "multiple paragraphs.")))
```

**`definition`** -- A term/definition pair within a definition list.

Attributes:
- `:term` (string or list of nodes) -- The term being defined.

Children: the definition body (inline and/or block-level nodes).

```lisp
(definition-list
  (definition (@ :term "Lexis")
    (paragraph "An s-expression document format."))
  (definition (@ :term "Classic")
    (paragraph "A Common Lisp publishing framework.")))
```

### 4.4 Inline Elements

Inline elements appear within paragraphs and other text-containing
nodes. They may contain text nodes and other inline elements (nesting
is permitted via explicit s-expression syntax).

**`emphasis`** -- Emphatic stress (typically rendered as italics).

**`strong`** -- Strong importance (typically rendered as bold).

**`code`** -- Inline code fragment (typically rendered in a monospace font).

**`underline`** -- Underlined text.

**`strikethrough`** -- Text with a line through it, indicating deletion
or retraction.

**`superscript`** -- Superscripted text.

**`subscript`** -- Subscripted text.

All inline elements have the same structure: optional `@` attributes,
followed by children (text and/or nested inline elements).

```lisp
(paragraph "The formula is H" (subscript "2") "O, published in "
           (emphasis "Nature") " vol. " (strong "12") ".")
```

### 4.5 Links

**`web-link`** -- A hyperlink to a web resource.

Attributes:
- `:uri` (string) -- The target URI. Required.
- `:title` (string) -- Advisory title (tooltip text).

Children: display text (inline nodes).

```lisp
(web-link (@ :uri "https://example.com" :title "Example Site")
  "Visit the example site")
```

**`cross-ref`** -- A reference to another section or document within
the same publication or corpus.

Attributes:
- `:target` (string) -- The target identifier (section ID, document
  reference, or title).

Children: optional display text. If omitted, the renderer derives
display text from the target (e.g., the section title or document title).

```lisp
(cross-ref (@ :target "intro") "the introduction")
```

### 4.6 Media

**`image`** -- An image reference.

Attributes:
- `:src` (string) -- Image source path or URI. Required.
- `:alt` (string) -- Alternative text description. Required for
  accessibility.
- `:width` (integer or string) -- Display width.
- `:height` (integer or string) -- Display height.
- `:caption` (string) -- Image caption.

No children (void element).

```lisp
(image (@ :src "diagram.png" :alt "System architecture diagram"))
```

**`figure`** -- A figure with caption, wrapping an image or other
content.

Attributes:
- `:id` (string) -- Identifier for cross-referencing.

Children: one `image` node (or other content) followed by a `caption`
node.

**`caption`** -- The caption of a figure or table.

Children: inline nodes (text and markup).

```lisp
(figure (@ :id "fig-arch")
  (image (@ :src "architecture.png" :alt "Architecture diagram"))
  (caption "Figure 1: The Classic architecture."))
```

### 4.7 Tables

**`table`** -- A data table.

Attributes:
- `:id` (string) -- Identifier for cross-referencing.
- `:caption` (string) -- Table caption.

Children: one or more `row` nodes.

**`row`** -- A table row.

Attributes:
- `:header` (boolean) -- If true, this row is a header row.

Children: one or more `cell` nodes.

**`cell`** -- A table cell.

Attributes:
- `:colspan` (integer) -- Number of columns spanned.
- `:rowspan` (integer) -- Number of rows spanned.
- `:header` (boolean) -- If true, this cell is a header cell.

Children: inline and/or block-level nodes.

```lisp
(table (@ :caption "Comparison of Approaches")
  (row (@ :header t)
    (cell "Feature")
    (cell "Classic")
    (cell "WordPress"))
  (row
    (cell "Content model")
    (cell "Ontological classes")
    (cell "Post types + meta")))
```

### 4.8 Footnotes

**`note`** -- A footnote or endnote.

Attributes:
- `:id` (string) -- Identifier for back-referencing.
- `:kind` (keyword) -- `:footnote` (default) or `:endnote`.

Children: the note content (inline and/or block-level nodes).

Notes may appear inline within text. The renderer is responsible for
extracting them to the appropriate position (bottom of page, end of
section, end of document) based on `:kind` and output format.

```lisp
(paragraph "This claim requires substantiation."
  (note (@ :id "n1")
    (paragraph "See Smith et al., 2024.")))
```


## 5. Extension Mechanism

### 5.1 Custom Tags

Lexis is extensible via custom tags. Any symbol that is not part of the
core vocabulary is treated as a custom tag. Conforming processors must
handle unknown tags gracefully by one of:

1. Rendering the tag's children as if the tag were a generic container
   (pass-through rendering).
2. Ignoring the tag and its children entirely.
3. Signaling a warning and falling back to option 1 or 2.

The recommended behavior is option 1 (pass-through), which ensures
that content is never silently lost.

Custom tags follow the same syntax as core tags:

```lisp
(theorem (@ :id "thm-1" :title "Fundamental Theorem")
  (paragraph "For all " (emphasis "x") " in " (emphasis "S") "..."))
```

### 5.2 Custom Tag Registration

In a Lisp implementation, custom tags are registered by defining a
node class with a tag name:

```lisp
(define-lexis-node theorem (section)
  ((proof :accessor proof
          :initarg :proof))
  (:tag-name "theorem"))
```

The registration mechanism maps tag name symbols to node classes,
enabling the parser to instantiate the correct class when reading a
document. Unregistered tags are instantiated as generic container nodes.

### 5.3 Namespace Convention for Extensions

Extension attributes use a prefixed namespace to avoid collision with
core attributes. The convention is `prefix:attribute-name` as a keyword
symbol:

```lisp
(section (@ :title "Introduction" :wiki:category "overview")
  ...)
```

The prefix identifies the extension. Processors that do not understand
a namespace prefix ignore those attributes. Core attributes have no
prefix.

### 5.4 Medium-Dependent Passthrough

Some forms of content have no meaningful representation outside a
specific rendering target. HTML stylesheets and scripts, LaTeX preamble
commands, terminal escape sequences, JSON-LD blocks for SEO, RSS
channel metadata — each is intelligible only to its native medium and
opaque to every other. Inventing core tags for each such case would
pollute the semantic vocabulary with rendering-target concerns.

Lexis handles these cases with a single general mechanism: the
**passthrough** tag. A passthrough node carries opaque verbatim content
tagged for one or more specific media. Renderers for matching media
emit the content as-is; renderers for non-matching media silently
omit it.

```
(passthrough (@ :medium target-spec [extra-attrs]*)
  content*)

target-spec := keyword | (keyword+)
content     := string | target-native-form
```

The `:medium` attribute identifies the target media this content is
intended for. Its value is either a single keyword (`:html`, `:latex`,
`:terminal`, `:markdown`, `:pdf`, `:epub`, …) or a list of keywords for
content valid in more than one target. The set of recognized medium
keywords is an open registry shared between document authors and
renderer implementations; conventional values match the renderer
designators used in the multi-target rendering protocol.

The children of a passthrough form are **not** parsed as Lexis nodes.
They are preserved verbatim and handed to the matching renderer in
whatever form the medium expects:

- **Strings** are emitted by the renderer without escaping or
  transformation. The author is responsible for any encoding the
  target medium requires.

- **S-expressions** are interpreted by the renderer in its native
  convention. For the HTML renderer, this means Spinneret-style
  `(:tag ...)` forms.

Examples:

```lisp
;; HTML stylesheet link via Spinneret form
(passthrough (@ :medium :html)
  (:link :rel "stylesheet" :href "main.css"))

;; HTML script with attributes
(passthrough (@ :medium :html)
  (:script :src "app.js" :defer t))

;; Inline HTML as a raw string
(passthrough (@ :medium :html)
  "<meta name=\"viewport\" content=\"width=device-width\">")

;; LaTeX preamble line (ignored by non-LaTeX renderers)
(passthrough (@ :medium :latex)
  "\\usepackage{amsmath}")

;; Content valid in multiple media
(passthrough (@ :medium (:html :epub))
  (:link :rel "stylesheet" :href "common.css"))

;; Passthrough at an inline position within text
(paragraph "The value of " (code "x") " is "
  (passthrough (@ :medium :html)
    (:output :id "x-val" "42"))
  " in the current example.")
```

A passthrough node may carry additional attributes beyond `:medium`.
These have no defined meaning in the core specification but may be
used by individual renderers as hints. Common conventions include:

- `:kind` — a semantic category (`:stylesheet`, `:script`, `:metadata`,
  `:asset`) that a renderer may use for placement or grouping decisions.
- `:placement` — a rendering position hint (`:head`, `:body`, `:inline`).
- `:priority` — an ordering hint where assets compete for placement.

Renderers that do not recognize a hint ignore it. The passthrough still
renders verbatim at its document position by default.

**Text processing.** Passthrough content bypasses the inline-markup
expansion pass (Section 3). Asterisks, brackets, backticks and other
characters that would normally signal inline patterns are preserved
exactly as written. This is essential for stylesheet bodies, script
sources, and any other content where those characters carry their own
medium-specific meaning.

**Aliases.** Processors may accept `pthru` as a synonym for
`passthrough`. Both parse to the same node type.

**Security.** Passthrough content is, by design, opaque content that
the renderer emits without interpretation. Authors and processors must
treat passthrough nodes from untrusted sources with the same care they
would extend to raw HTML, raw shell commands, or raw any-other-medium
content. Renderers serving multi-tenant or user-generated documents
should consider stripping passthrough nodes outright, sandboxing the
target medium, or applying medium-specific content sanitization before
emission.

**Conformance.** A conforming processor must:

- Recognize the `passthrough` tag (and the `pthru` alias).
- Preserve passthrough children verbatim without recursive Lexis parsing.
- Skip inline-markup processing within passthrough content.

A conforming renderer must:

- Examine the `:medium` attribute and emit passthrough content
  verbatim if and only if the renderer's target medium is listed.
- Omit (with no visible output) passthrough nodes targeting other media.


## 6. Classic Integration

This section describes the optional integration between Lexis and the
Classic publishing framework. The features described here enrich Lexis
documents with semantic identity and typed relationships from Classic's
ontological model. They are additive -- a Lexis document using Classic
extensions remains a valid Lexis document, and processors that do not
understand Classic extensions process the document correctly by ignoring
the extension attributes.

### 6.1 The `classic:` Attribute Namespace

Attributes prefixed with `classic:` carry Classic-specific metadata:

**`:classic:uri`** -- Associates a Lexis node with a Classic resource
by its canonical URI. This enables the renderer to resolve the resource
against a triplestore for additional information (author profile, media
metadata, related content).

```lisp
(item (@ :classic:uri "classic:co.example,2026:agents/abc-jane")
  "Jane Doe, Principal Engineer")
```

**`:classic:type`** -- Specifies the Classic ontological class of the
content represented by this node. Used by renderers to select
class-specific rendering methods or to emit typed structured data
(JSON-LD, RDFa).

```lisp
(section (@ :title "Product Review" :classic:type "classic-article")
  ...)
```

**`:classic:predicate`** -- Specifies the RDF predicate relating this
node's content to its parent or context. Used for structured data
emission.

```lisp
(paragraph (@ :classic:predicate "schema:reviewBody")
  "This product exceeded expectations...")
```

### 6.2 Classic Link Type

The `classic-link` node is a link whose target is a Classic URI:

```lisp
(classic-link (@ :uri "classic:janedoe.net,2026:articles/abc-architecture")
  "the architecture article")
```

Classic links are also produced by the inline markup processor when
a `classic:` URI appears in `[[...]]` syntax:

```
"See [[the architecture article|classic:janedoe.net,2026:articles/abc-arch]]."
```

A Classic-aware renderer resolves the URI against the triplestore to:

- Verify the target exists (preventing broken links).
- Retrieve the target's title for display if no display text is provided.
- Generate structured `<a>` tags with appropriate `rel` attributes.
- Produce hover previews or summary cards.

A non-Classic renderer treats `classic-link` as a `web-link`, using the
Classic URI as an opaque string (or converting it to an HTTP URL via
the standard `classic:` to `https://` mapping).

### 6.3 Resource Embedding

A Classic-aware renderer may expand `:classic:uri` references into
rich content at render time. For example, an author reference:

```lisp
(paragraph "Written by "
  (author-ref (@ :classic:uri "classic:janedoe.net,2026:agents/abc-jane"))
  " in May 2026.")
```

A Classic renderer resolves the URI, retrieves the `classic-person`
entity, and renders a linked name, headshot, or author card depending
on the output medium and template. A non-Classic renderer renders the
`author-ref` tag's children (empty in this case) or the raw URI as
fallback text.

### 6.4 Document-Level Classic Metadata

The `document` node may carry Classic metadata identifying the document
as a Classic resource:

```lisp
(document (@ :title "Why Classic Matters"
             :author "Jane Doe"
             :date "2026-05-22"
             :classic:uri "classic:janedoe.net,2026:articles/xyz-why-classic"
             :classic:type "classic-article"
             :classic:workflow-state "published")
  ...)
```

This metadata connects the Lexis document to its Classic persistence
identity, enabling the publishing system to track the document's
lifecycle, authorship, and federation status.


## 7. Processing Model

A Lexis document is processed through a pipeline of passes. Not all
passes are required -- a minimal processor may skip the text processing
pass and render the raw s-expression tree directly.

### 7.1 Parse

Read the s-expression from a stream or string using `cl:read` (or a
format-specific reader). The result is a nested list structure.
Optionally, instantiate a typed node tree by mapping tag symbols to
node classes via the tag registry.

### 7.2 Text Processing

Scan all text nodes in the parsed tree for inline markup patterns
(`[[...]]`, `**...**`, `*...*`, `~~...~~`, backtick spans). Replace
matching patterns with the corresponding Lexis inline nodes. The
processing order defined in Section 3.3 ensures unambiguous expansion.

This pass transforms a tree of tags and strings into a tree of tags,
strings, and inline element nodes.

### 7.3 Resolution

Resolve cross-references and Classic URI references:

- `cross-ref` nodes: look up the target by ID or title, attach the
  resolved target information (for generating links and display text).
- `classic-link` and `:classic:uri` references: resolve against a
  Classic triplestore (if available) to retrieve resource metadata.

This pass may be skipped if no cross-references are present or if
Classic integration is not active.

### 7.4 Rendering

Traverse the processed tree and emit output in the target format.
Rendering is dispatched per-node-type and per-output-medium. A
rendering function receives a node, its attributes, its children, and
a medium designator, and produces the appropriate output.

Target formats include but are not limited to:

- **HTML** (via Spinneret s-expression forms or direct string emission).
- **PDF** (via `cl-pdf` with a layout solver, or via LaTeX as an
  intermediary).
- **ANSI terminal text** (for BBS/TUI interfaces).
- **Markdown** (for interchange with Markdown-based systems).
- **Plain text** (for search indexing, excerpts, RSS descriptions).
- **JSON-LD** (for structured data / SEO, particularly with Classic
  integration active).

Each target format is implemented as a set of methods on a rendering
generic function, one method per node type per medium. Unknown node
types fall through to a default method that renders children within
a generic container.


## 8. Multi-Target Rendering Considerations

Lexis is designed for medium-independent document representation. The
core tag vocabulary maps naturally to HTML, PDF, terminal text, Markdown,
and plain text output. However, not every tag has a direct equivalent in
every target medium, and renderers must make principled decisions about
how to handle these gaps.

This section describes the expected rendering behavior for each major
target format, focusing on cases where tags require adaptation.

### 8.1 HTML

HTML is the most natural target for Lexis. Every core tag has a direct
HTML counterpart. The renderer produces Spinneret-compatible s-expression
HTML as an intermediate form, which Spinneret then emits as HTML text.

Notable mappings:
- `section` with `:title` produces a heading element (`<h2>` through
  `<h6>` based on nesting depth, with `<h1>` reserved for the document
  title) followed by the section content.
- `note` nodes are extracted from their inline position and rendered as
  footnotes with back-references, or as sidenotes depending on template
  style.
- `web-link` `:title` attributes map to the HTML `title` attribute
  (tooltip text).
- `classic-link` nodes are rendered as `<a>` tags, with the Classic URI
  converted to an HTTP URL via the standard `classic:` to `https://`
  mapping, and optionally enriched with `rel` attributes and structured
  data.
- `table` cell `:colspan` and `:rowspan` attributes map directly to
  their HTML counterparts.

### 8.2 PDF

PDF output can be produced through a typesetting intermediary (LaTeX)
or through a direct PDF generation library such as `cl-pdf`. The choice
affects how Lexis tags are translated.

**Via LaTeX:** Most tags map directly to LaTeX commands and environments.
`section` -> `\section{}`, `emphasis` -> `\emph{}`, `code-block` ->
`lstlisting` or `minted` environment, `blockquote` -> `quote`
environment, lists -> `itemize`/`enumerate`/`description` environments,
`image` -> `\includegraphics`, `note` -> `\footnote{}`. Table cell
spanning attributes translate to `\multicolumn` and `\multirow`.

**Via cl-pdf:** The renderer drives page layout directly, computing text
flow, line breaking, and page breaking from the document structure. This
approach requires a layout solver -- a layer above `cl-pdf` that handles
pagination, float placement, and widow/orphan control. Lexis does not
prescribe layout behavior, but the document structure provides natural
hints for the solver:

- Sections are preferred page-break points.
- A `figure` should accompany the section text that contains it when
  possible (the structural nesting expresses this relationship).
- `note` nodes with `:kind :footnote` should appear on the same page as
  their reference point; `:kind :endnote` nodes collect at the end.

**PDF-specific extension attributes** in the `:pdf:` namespace can
provide additional hints without affecting other renderers:

```lisp
(section (@ :title "Chapter Two" :pdf:page-break-before t)
  ...)

(figure (@ :id "fig-1" :pdf:placement :top :pdf:width "0.8\\textwidth")
  (image (@ :src "diagram.png" :alt "Diagram"))
  (caption "Figure 1: System architecture."))
```

**Tags requiring adaptation for PDF:**

- **`web-link`:** Clickable in digital PDFs (via `hyperref` or `cl-pdf`
  link annotations). For print, the renderer should make URLs visible --
  either parenthesized after the display text, footnoted, or collected
  in a references section. The `:title` attribute (tooltip) has no PDF
  equivalent and is ignored.
- **`classic-link`:** Same treatment as `web-link`, with the Classic URI
  converted to an HTTP URL for the link target.
- **`code-block`:** Requires a monospace font and possibly syntax
  highlighting (either through LaTeX packages like `minted` or through
  a CL-side highlighter that annotates the code with color attributes
  before PDF emission).

### 8.3 Terminal / TUI

Terminal output uses ANSI escape codes for formatting within a
fixed-width character grid. The renderer wraps text to the terminal
width (negotiated via Telnet NAWS or SSH window-change signals) and
uses cursor positioning for layout.

Tag mappings:

| Tag | Terminal Rendering |
|-----|--------------------|
| `section` | Title in ANSI bold, followed by a horizontal rule (`---`) |
| `paragraph` | Text wrapped to terminal width, blank line separator |
| `emphasis` | ANSI italic (ESC[3m) or underline (ESC[4m) as fallback |
| `strong` | ANSI bold (ESC[1m) |
| `code` | ANSI reverse video or a distinct color |
| `code-block` | Indented block, possibly with a box-drawing border |
| `blockquote` | Indented with `>` prefix or `|` bar character |
| `unordered-list` | Bullet characters (`*`, `-`, or Unicode `bullet`) |
| `ordered-list` | Sequential numbers with period |
| `definition-list` | Term in bold on its own line, definition indented below |
| `table` | Box-drawing characters for borders; pre-pass to measure column widths |
| `web-link` | Display text followed by URL: `display text [1]` with references listed at end |
| `classic-link` | Same as `web-link`, with Classic URI converted to HTTP URL |
| `note` | Inline reference marker `[1]`, notes collected at section or document end |

**Tags with limited terminal representation:**

- **`image`:** Terminals generally cannot display images inline. The
  renderer displays the `:alt` text as a bracketed placeholder:
  `[Image: A landscape photograph]`. Terminals supporting the Sixel or
  Kitty graphics protocols may render actual images; this is a
  renderer capability, not a format concern.
- **`figure`:** Rendered as the image placeholder followed by the
  caption text.
- **`subscript` / `superscript`:** No ANSI equivalent. The renderer
  may use conventions like `H_2O` for subscript and `x^2` for
  superscript, or simply render inline.
- **Table cell spanning:** `:colspan` and `:rowspan` are difficult to
  represent in box-drawn terminal tables. The renderer may expand
  spanning cells into repeated content or ignore the spanning and
  render the content in the first cell position.

**Terminal-specific extension attributes** in the `:term:` namespace
may hint at rendering preferences:

```lisp
(section (@ :title "Status" :term:color :green)
  ...)
```

### 8.4 Markdown

Lexis-to-Markdown output reverses the direction of the inline markup
processing pass: Lexis nodes are flattened back into Markdown's
character-delimited syntax.

Direct mappings:

| Tag | Markdown Output |
|-----|-----------------|
| `section` | `## Title` (heading level from depth) |
| `paragraph` | Blank-line-separated text |
| `emphasis` | `*text*` |
| `strong` | `**text**` |
| `strikethrough` | `~~text~~` (GFM extension) |
| `code` | `` `text` `` |
| `code-block` | Fenced code block with language identifier |
| `blockquote` | `>` prefixed lines |
| `unordered-list` | `- item` lines |
| `ordered-list` | `1. item` lines |
| `web-link` | `[text](url)` |
| `image` | `![alt](src)` |
| `table` | GFM pipe table syntax |

**Tags with no standard Markdown equivalent:**

- **`definition-list`:** No core Markdown syntax. The renderer may use
  an extension syntax (PHP Markdown Extra: `Term\n: Definition`), or
  degrade to a formatted unordered list with the term in bold.
- **`note`:** No core Markdown footnote syntax. The renderer may use
  the `[^1]` extension syntax (supported by Pandoc, PHP Markdown Extra,
  and many static site generators) or inline the note text in
  parentheses.
- **`aside`:** No Markdown equivalent. The renderer may produce a
  blockquote with a bold prefix: `> **Note:** content`.
- **`subscript` / `superscript`:** No standard Markdown syntax. The
  renderer may emit raw HTML (`<sub>`, `<sup>`) which most Markdown
  processors pass through, or use a convention like `H~2~O` (Pandoc
  extension).
- **`underline`:** No Markdown syntax. May emit raw HTML (`<u>`) or
  degrade to emphasis.
- **Nested inline markup:** Markdown's delimiter-based inline syntax
  handles some nesting (`***bold italic***`) but is inconsistent across
  implementations for complex cases. The Markdown renderer should
  flatten nesting where possible and fall back to raw HTML for cases
  that Markdown cannot represent.

These limitations are inherent to Markdown's simpler vocabulary, not to
Lexis's format design. The Lexis document preserves full structural
information; the Markdown renderer approximates it within Markdown's
capabilities.

### 8.5 Plain Text

Plain text output strips all formatting, producing a readable text
document suitable for search indexing, accessibility readers, or
terminal environments without ANSI support.

- All inline markup is removed; text content is preserved.
- Sections produce their title followed by a blank line.
- Lists produce indented lines with `-` or number prefixes.
- Links produce the display text followed by the URL in parentheses,
  or just the display text if brevity is preferred.
- Images produce their `:alt` text in brackets.
- Tables produce aligned columns using spaces (fixed-width assumption)
  or are linearized (each cell on its own line with a label prefix).
- Code blocks are indented by a fixed amount.
- Notes are either inlined in parentheses or collected at the end.

### 8.6 JSON-LD / Structured Data

When Classic integration is active, a JSON-LD renderer produces
Schema.org structured data from the document and its Classic metadata:

- `document` with `:classic:type "classic-article"` emits a
  `schema:Article` object with `headline`, `author`, `datePublished`.
- `image` nodes within the document contribute to the article's
  `schema:image` property.
- `classic-link` references to `classic-person` resources emit
  `schema:author` with `schema:Person` objects.
- Section titles contribute to the article's `schema:about` topics.

This output is driven primarily by Classic metadata rather than by
Lexis core vocabulary, and is only available when a Classic persistence
context is present for URI resolution.

### 8.7 General Principles for Renderers

When a tag has no natural equivalent in the target medium, renderers
should follow these principles in order of preference:

1. **Approximate semantically.** Use the closest available construct
   in the target medium that preserves the tag's meaning (e.g.,
   `definition-list` as a formatted unordered list in Markdown).

2. **Degrade to content.** If no approximation exists, render the
   tag's children without the tag's formatting (e.g., `underline` in
   a terminal that doesn't support ANSI underline -- just render the
   text).

3. **Provide metadata as text.** For tags carrying important metadata
   that would be lost (e.g., `web-link` URLs in print PDF), surface
   the metadata as visible text (footnotes, parenthetical references).

4. **Never silently discard content.** A renderer may omit formatting
   but must not omit text content or meaningful metadata without
   signaling this to the user or document author.


## 9. Examples

### 9.1 A Simple Blog Post

```lisp
(document (@ :title "Getting Started with Lexis"
             :author "Jane Doe"
             :date "2026-05-22")

  (section (@ :title "What is Lexis?" :id "what")
    (paragraph "Lexis is an s-expression document format. It represents
      documents as nested lists that any Lisp program can read and
      transform.")
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
      (item "CommonDoc -- a Common Lisp document object model"))))
```

### 9.2 A Wiki Article with Classic Integration

```lisp
(document (@ :title "Han Solo"
             :classic:uri "classic:starwars.wiki,2026:characters/abc-han-solo"
             :classic:type "wiki-character")

  (character-infobox
    (@ :classic:uri "classic:starwars.wiki,2026:characters/abc-han-solo"
       :species "classic:starwars.wiki,2026:species/def-human"
       :affiliation "classic:starwars.wiki,2026:orgs/ghi-rebellion")
    (image (@ :src "han-solo.jpg" :alt "Han Solo")))

  (section (@ :title "Biography" :id "bio")
    (paragraph "Han Solo was a smuggler from
      [[Corellia|classic:starwars.wiki,2026:locations/jkl-corellia]]
      who became a key figure in the
      [[Rebel Alliance|classic:starwars.wiki,2026:orgs/ghi-rebellion]].")
    (paragraph "He was the captain of the
      [[Millennium Falcon|classic:starwars.wiki,2026:items/mno-falcon]],
      a modified YT-1300 light freighter."))

  (section (@ :title "Appearances" :id "appearances")
    (unordered-list
      (item "[[A New Hope|classic:starwars.wiki,2026:works/pqr-anh]]")
      (item "[[The Empire Strikes Back|classic:starwars.wiki,2026:works/stu-esb]]")
      (item "[[Return of the Jedi|classic:starwars.wiki,2026:works/vwx-rotj]]"))))
```

### 9.3 A Business Page

```lisp
(document (@ :title "About Our Firm"
             :classic:type "classic-page")

  (section (@ :title "Our Practice" :id "practice")
    (paragraph "We specialize in intellectual property law with a
      focus on software patents and open source licensing.")
    (paragraph "Our team brings over 50 years of combined experience
      in technology law."))

  (section (@ :title "Our Team" :id "team")
    (team-member
      (@ :classic:uri "classic:lawfirm.com,2026:agents/abc-jane"
         :position "Managing Partner")
      (image (@ :src "jane.jpg" :alt "Jane Smith"))
      (paragraph "Jane founded the firm in 2015 after two decades
        at a major technology company."))
    (team-member
      (@ :classic:uri "classic:lawfirm.com,2026:agents/def-bob"
         :position "Senior Associate")
      (image (@ :src "bob.jpg" :alt "Bob Chen"))
      (paragraph "Bob specializes in open source compliance and
        software licensing disputes.")))

  (section (@ :title "Contact" :id "contact")
    (paragraph "Reach us at **info@lawfirm.com** or call
      ~~the old number~~ our new line at (555) 123-4567.")))
```

### 9.4 A Technical Document with Tables and Footnotes

```lisp
(document (@ :title "Persistence Strategy Comparison"
             :author "Jane Doe"
             :date "2026-05-22")

  (section (@ :title "Overview")
    (paragraph "Classic supports multiple persistence backends."
      (note (@ :id "n1")
        (paragraph "The in-memory backend is for development only.")))
    (paragraph "Each backend implements the same protocol."))

  (section (@ :title "Comparison")
    (table (@ :caption "Backend Comparison")
      (row (@ :header t)
        (cell "Backend")
        (cell "Scale")
        (cell "Query"))
      (row
        (cell "In-memory")
        (cell "Development")
        (cell "Hash lookup"))
      (row
        (cell "Flat file")
        (cell "Personal blog")
        (cell "File scan + indexes"))
      (row
        (cell "Triplestore")
        (cell "Production cluster")
        (cell "SPARQL")))

    (paragraph "The flat file backend uses `storage-granularity` to
      determine whether items are stored individually or bundled
      per-container.")))
```


## 10. Conformance

### 10.1 Conforming Document

A conforming Lexis document:

- Is a well-formed s-expression readable by a standard Common Lisp
  reader.
- Has a `document` node as its root.
- Uses only core vocabulary tags and registered extension tags (unknown
  tags are permitted but should be documented).
- Follows the attribute syntax defined in Section 2.2.

### 10.2 Conforming Processor

A conforming Lexis processor:

- Parses any conforming Lexis document without error.
- Handles all core vocabulary tags defined in Section 4.
- Handles unknown tags gracefully (Section 5.1) without data loss.
- Handles unknown attribute namespaces by ignoring them.
- Implements the text processing pass (Section 3) or documents that
  it does not.

### 10.3 Conforming Renderer

A conforming Lexis renderer:

- Is a conforming processor.
- Produces output in at least one target format.
- Renders all core vocabulary tags with semantically appropriate output
  for its target format.
- Renders unknown tags via pass-through (rendering their children).


## Appendix A: Core Tag Summary

| Tag | Category | Children | Key Attributes |
|-----|----------|----------|----------------|
| `document` | Structure | Block | `:title`, `:author`, `:date`, `:language` |
| `section` | Structure | Block/Inline | `:title`, `:id` |
| `paragraph` | Block | Inline/Text | -- |
| `code-block` | Block | Text (literal) | `:language`, `:caption` |
| `blockquote` | Block | Block | `:source`, `:uri` |
| `aside` | Block | Block | `:kind` |
| `unordered-list` | Block | `item` | -- |
| `ordered-list` | Block | `item` | `:start` |
| `definition-list` | Block | `definition` | -- |
| `item` | List | Inline/Block | -- |
| `definition` | List | Inline/Block | `:term` |
| `emphasis` | Inline | Inline/Text | -- |
| `strong` | Inline | Inline/Text | -- |
| `code` | Inline | Text (literal) | -- |
| `underline` | Inline | Inline/Text | -- |
| `strikethrough` | Inline | Inline/Text | -- |
| `superscript` | Inline | Inline/Text | -- |
| `subscript` | Inline | Inline/Text | -- |
| `web-link` | Inline | Inline/Text | `:uri`, `:title` |
| `cross-ref` | Inline | Inline/Text | `:target` |
| `image` | Media | (void) | `:src`, `:alt`, `:width`, `:height` |
| `figure` | Media | `image` + `caption` | `:id` |
| `caption` | Media | Inline/Text | -- |
| `table` | Block | `row` | `:id`, `:caption` |
| `row` | Table | `cell` | `:header` |
| `cell` | Table | Inline/Block | `:colspan`, `:rowspan`, `:header` |
| `note` | Inline | Inline/Block | `:id`, `:kind` |
| `passthrough` | Extension | Verbatim (target-native) | `:medium`, `:kind`, `:placement` |


## Appendix B: Inline Markup Summary

| Pattern | Expansion | Notes |
|---------|-----------|-------|
| `[[text\|uri]]` | `web-link` or `classic-link` | URI scheme determines type |
| `[[text]]` | `cross-ref` | Internal reference by title/ID |
| `*text*` | `emphasis` | Single asterisks |
| `**text**` | `strong` | Double asterisks |
| `~~text~~` | `strikethrough` | Double tildes |
| `` `text` `` | `code` | Backticks; content is literal |


## Appendix C: Classic Extension Attributes

| Attribute | Scope | Description |
|-----------|-------|-------------|
| `:classic:uri` | Any node | Classic resource URI |
| `:classic:type` | Any node | Classic ontological class name |
| `:classic:predicate` | Any node | RDF predicate relating node to context |
| `:classic:workflow-state` | `document` | Current workflow state label |
