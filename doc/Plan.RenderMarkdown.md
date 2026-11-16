---
id:            LEXIS-DRAFT-rendermarkdown
title:         "Markdown as an Input Format for Lexis: Development Plan"
genre:         Plan
scope:         project
project:       Lexis
component:     lexis.markdown
language:      en
status:        Draft
provenance:
  assistant:   claude-opus-5-5
relates-to:
  - SEED-0011
  - CLASSIC-0011
cites:
  - title:     "3bmd — Markdown Processor in CL Using Esrap"
    locator:   "https://github.com/3b/3bmd; Quicklisp release 3bmd-20230618-git"
    external:  true
  - title:     "CommonMark Spec"
    locator:   "https://spec.commonmark.org/"
    external:  true
decisions:
  - LEXIS-DRAFT-rendermarkdown-D1
  - LEXIS-DRAFT-rendermarkdown-D2
  - LEXIS-DRAFT-rendermarkdown-D3
  - LEXIS-DRAFT-rendermarkdown-D4
  - LEXIS-DRAFT-rendermarkdown-D5
  - LEXIS-DRAFT-rendermarkdown-D6
  - LEXIS-DRAFT-rendermarkdown-D7
  - LEXIS-DRAFT-rendermarkdown-D8
  - LEXIS-DRAFT-rendermarkdown-D9
  - LEXIS-DRAFT-rendermarkdown-D10
  - LEXIS-DRAFT-rendermarkdown-D11
open-questions:
  - LEXIS-DRAFT-rendermarkdown-O1
  - LEXIS-DRAFT-rendermarkdown-O2
  - LEXIS-DRAFT-rendermarkdown-O3
  - LEXIS-DRAFT-rendermarkdown-O4
  - LEXIS-DRAFT-rendermarkdown-O5
---

# Markdown as an Input Format for Lexis: Development Plan

This plan adds a Markdown reader to Lexis: a new system, `lexis.markdown`,
that converts Markdown text into a Lexis s-expression, so that Classic
content stored as Markdown can be previewed, rendered and searched for
links through the same path as content written in Lexis. It carries out
the recommendation "A Markdown→Lexis reader" in the Classic interface
Survey ([SEED-0011](../../seed/doc/Survey.ClassicInterface.md)),
corrected by what running the suggested parser, 3bmd, showed. The first
version is deliberately narrow: several features are dropped or simplified
and listed under [Deferred Work](#deferred-work), and the parser is
expected to be replaced. Lexis code references are pinned to revision
`9ebd54f`, Classic's to `807640b`.


## Problem

Classic stores the bodies of articles and wiki pages as strings with a
declared format, and Markdown is its default (the `:format` slot option in
`CLASSIC:src/mop/metaclass.lisp@807640b`). Classic's Composer turns a slot
into Lexis according to a display mode ([CLASSIC-0011](../../classic/doc/theme/Ref.Theme.md)),
and its `:markdown` mode is a placeholder: `render-markdown-stub` (in
`src/lens.lisp` of the classic.composer repository, revision `b9ad8c1`)
splits the text on blank lines, wraps each block in a paragraph, and
leaves the rest to Lexis's inline markup. Headings, lists, code blocks and
links are not recognised. The Survey makes a Markdown reader a
prerequisite for the CMS preview and for wiki link resolution.

Lexis has no block-level reader of any kind. Its only text processing is
the inline pass, `src/text-processing.lisp:process-text@9ebd54f`, which
expands `` `code` ``, `[[links]]`, `**strong**`, `*emphasis*` and
`~~strikethrough~~` inside text strings.

Running 3bmd on sample input found five things the Survey's proposal does
not account for:

1. **Text would be interpreted twice.** The Composer returns Lexis
   s-expressions, and Lexis runs the inline pass over them before
   rendering. 3bmd resolves Markdown escapes, so `\*not emphasis\*` comes
   back as the strings `"*" "not emphasis" "*"`; joined, they would become
   an emphasis. Lexis has no escape syntax and no way to mark text as
   literal.
2. **Some Markdown has no Lexis tag.** Tables and definition lists are
   specified in [the Lexis specification](Spec.Lexis.md) (§4.3, §4.7) but not
   implemented. Horizontal rules and hard line breaks have no tag at all.
3. **The Survey's mapping table is incomplete.** 3bmd also produces
   `:plain` (tight list items and table cells), `:verbatim` (indented
   code), `:reference` and `:reference-link` (links defined elsewhere in
   the text), `:link` (autolinks), `:image`, `:raw-html` and `:html`
   (inline and block HTML), `:line-break`, `:horizontal-rule`, `:entity`,
   and, with smart quotes enabled, quotation and dash nodes.
4. **Headings contain inline markup, but a section title is a string.**
5. **3bmd follows the original Markdown, not CommonMark.** A nested list
   indented by two spaces is not nested; a numbered list that follows a
   bullet list is merged into it; lists lose their starting number; there
   is no strikethrough and there are no footnotes.

Markdown bodies come from users, so the reader is also a boundary for
untrusted input: raw HTML and `javascript:` URIs must not reach the
rendered page unchanged.


## Goals

- `markdown->lexis` converts a Markdown string into a Lexis s-expression
  that `src/parse.lisp:parse-document@9ebd54f` and
  `src/html/render.lisp:render-html@9ebd54f` accept, with
  the text rendered exactly as the Markdown author wrote it.
- Paragraphs, headings, emphasis, strong, inline code, code blocks, block
  quotes, lists, links, images, tables, definition lists and wiki links
  are translated to their Lexis tags.
- The core `lexis` system keeps `cl-ppcre` as its only dependency.
- Untrusted input is safe by default: raw HTML is escaped and links with
  unsafe URI schemes are removed.
- The parser can be replaced without changing the entry point or the
  tests.
- Classic's Composer can replace its `:markdown` placeholder with one call.


## Settled Decisions

### LEXIS-DRAFT-rendermarkdown-D1 — Adapt an existing parser in a separate system

**Status:** Proposed
**Context:** Markdown parsing is a large problem with many edge cases;
Lexis is a small library whose core depends only on `cl-ppcre`.
**Decision:** The reader is an adapter that translates the tree produced
by an existing Markdown parser. It lives in a new system, `lexis.markdown`,
defined in `lexis.markdown.asd`, alongside `lexis.html`. Only that system
depends on the parser.
**Alternatives:** Writing a parser in Lexis was rejected as far more work
for no gain at this stage. Putting the reader in the core `lexis` system
was rejected because it would make every user of Lexis load a Markdown
parser.

### LEXIS-DRAFT-rendermarkdown-D2 — 3bmd first, behind a replaceable entry point

**Status:** Proposed
**Context:** 3bmd is available through Quicklisp, is written in Common
Lisp, and produces a Lisp tree rather than HTML. It follows the original
Markdown rather than CommonMark, with the divergences listed under
[Problem](#problem). cl-cmark binds the C library libcmark.
**Decision:** The first version uses 3bmd, with its fenced code block,
table, wiki link and definition list extensions. 3bmd is expected to be
replaced later, so the code that reads 3bmd's tree is confined to one
file, the later passes work on Lexis forms rather than on 3bmd's tree, and
the tests are written as Markdown input against Lexis output.
**Alternatives:** cl-cmark was rejected because it depends on a C
library. Waiting for a CommonMark parser in Common Lisp was rejected
because the CMS needs the reader now.

### LEXIS-DRAFT-rendermarkdown-D3 — The reader returns Lexis s-expressions

**Status:** Proposed
**Context:** The Composer builds and returns Lexis s-expressions, not
parsed node objects. The Survey's one-way migration from a Markdown body
to a Lexis-native body (SEED-O21) needs a form that
can be stored.
**Decision:** `markdown->lexis` returns an s-expression: a list of block
forms, or a `document` form when asked. A convenience function parses the
result into a `lexis-document`.
**Alternatives:** Returning parsed node objects would suit rendering but
not the Composer or storage, and Lexis has no way to print a node tree
back to an s-expression.

### LEXIS-DRAFT-rendermarkdown-D4 — A `literal` tag protects text from the inline pass

**Status:** Proposed
**Context:** Text that 3bmd has already interpreted must not be
interpreted again by `process-text` (the first item under
[Problem](#problem)).
**Decision:** Lexis core gains an inline tag, `literal`, with class
`lexis-literal`. Its children are text; `process-text` leaves it
unchanged and the HTML renderer emits its text. The reader wraps a text
string in `literal` only when the string contains `` ` ``, `*`, `~~` or
`[[`, so most output stays plain. The tag is also available to authors
writing Lexis by hand.
**Alternatives:** Backslash escapes in Lexis's inline syntax would change
how existing text containing backslashes is read. A flag on the root form
that disables the inline pass would be lost when the Composer splices the
result into a larger document.

### LEXIS-DRAFT-rendermarkdown-D5 — Strikethrough stays literal text for now

**Status:** Proposed
**Context:** 3bmd has no strikethrough syntax, so `~~text~~` reaches the
reader as text, and the `literal` wrapping of
LEXIS-DRAFT-rendermarkdown-D4 keeps Lexis from expanding it.
**Decision:** The first version leaves `~~text~~` as literal text.
**Alternatives:** Detecting strikethrough in the reader, or leaving `~~`
unwrapped for Lexis to expand, were deferred; a replacement parser may
support strikethrough itself.

### LEXIS-DRAFT-rendermarkdown-D6 — Heading content becomes a plain-text title

**Status:** Proposed
**Context:** A `section` title is a string attribute, but a Markdown
heading can contain emphasis, code and links.
**Decision:** The first version flattens a heading's content to plain text
for the section's `:title`. Definition list terms are flattened the
same way for now, although the specification allows a term to be a list
of nodes ([LEXIS-DRAFT-lexis](Spec.Lexis.md), §4.3), so rich terms are
already possible.
**Alternatives:** Extending `section` to take a title of Lexis nodes is
the intended next step, after the first version works (see
[Deferred Work](#deferred-work)).

### LEXIS-DRAFT-rendermarkdown-D7 — Horizontal rules and line breaks are dropped for now

**Status:** Proposed
**Context:** Lexis has no tag for a horizontal rule or a hard line break.
**Decision:** The first version drops both. Adding them is the first item
under [Deferred Work](#deferred-work).
**Alternatives:** Adding the tags now was deferred to keep the first
version small. Passthrough HTML would work for one medium only.

### LEXIS-DRAFT-rendermarkdown-D8 — Raw HTML is escaped by default

**Status:** Proposed
**Context:** Markdown allows raw HTML, inline and as blocks. Markdown
bodies come from users, and raw HTML in a page is a script injection
risk.
**Decision:** A `:raw-html` option chooses the policy. `:escape`, the
default, keeps the HTML as literal text, which the renderer escapes.
`:drop` removes it. `:passthrough` emits a passthrough form,
`(passthrough (@ :medium :html) …)`, for trusted sources only.
**Alternatives:** Passing HTML through by default, as most Markdown
processors do, was rejected for untrusted input. Sanitising HTML to a
safe subset was deferred.

### LEXIS-DRAFT-rendermarkdown-D9 — Links with unsafe URI schemes are removed

**Status:** Proposed
**Context:** A Markdown link or image can name any URI, including
`javascript:` and `data:`. Lexis's HTML renderer does not check URIs.
**Decision:** The reader accepts URIs without a scheme (relative paths and
`#anchors`) and URIs whose scheme is in an allowed list, by default
`http`, `https`, `mailto` and `classic`. A link with any other scheme is
replaced by its text; an image is replaced by its alt text.
**Alternatives:** Checking URIs in the HTML renderer would also protect
Lexis written by hand, and may be added later, but the reader cannot rely
on every renderer doing it.

### LEXIS-DRAFT-rendermarkdown-D10 — Wiki links go through a resolver the caller supplies

**Status:** Proposed
**Context:** 3bmd reads `[[Target|Display]]`, target first. Classic
resolves a wiki target by page name against a particular wiki
(`CLASSIC:mod/classic.models.common/wiki.lisp:find-page-by-anchor@807640b`),
which Lexis cannot do.
**Decision:** A `:wiki-link-resolver` option takes a function of the
target and the display text that returns a Lexis form. The default
returns `(cross-ref (@ :target target) display)`. Classic supplies a
resolver that returns a `classic-link` to the page's URI.
**Alternatives:** Producing a `classic-link` without a URI would not
render. The Survey's proposal to change Lexis's own `[[display|uri]]`
order is a separate question; it does not affect this reader, because
3bmd parses wiki links itself.

### LEXIS-DRAFT-rendermarkdown-D11 — Tables and definition lists are implemented in core

**Status:** Proposed
**Context:** Markdown tables and definition lists are common, and Lexis
already specifies `table`, `row` and `cell`, and `definition-list` and
`definition`, without implementing them.
**Decision:** Implement these five tags in core as specified, with HTML
rendering, before the reader uses them.
**Alternatives:** Dropping tables and definition lists like horizontal
rules would lose content that users write often. Emitting them as unknown
elements would render as generic `div`s and warn on every parse.


## Design

### Changes to Lexis core

Table: Additions to the core `lexis` and `lexis.html` systems.

| Addition | Where | Behaviour |
|---|---|---|
| `literal` tag, class `lexis-literal` | `src/tags.lisp`, `src/parse.lisp`, `src/packages.lisp` | Registered tag; children are text |
| `process-text` method for `lexis-literal` | `src/text-processing.lisp` | Returns the node unchanged |
| `table`, `row`, `cell` | `src/tags.lisp`, `src/parse.lisp`, `src/packages.lisp` | As in the specification's §4.7 |
| `definition-list`, `definition` | `src/tags.lisp`, `src/parse.lisp`, `src/packages.lisp` | As in the specification's §4.3 |
| `render-html-tree` methods | `src/html/render.lisp` | `literal` as its text; `<table>`, `<caption>`, `<tr>`, `<th>`, `<td>`; `<dl>`, `<dt>`, `<dd>` |

Each addition gets tests in the existing suites, and the specification
gains entries for `literal` in §3 and §4.4.

### The `lexis.markdown` system

```lisp
(lexis.markdown:markdown->lexis string
  &key document            ; NIL: list of block forms; T: a DOCUMENT form
       title               ; the document's :title when DOCUMENT is true
       (raw-html :escape)  ; :escape, :drop or :passthrough
       (uri-schemes '("http" "https" "mailto" "classic"))
       wiki-link-resolver) ; function (target display) -> Lexis form

(lexis.markdown:parse-markdown string &rest keys)  ; -> lexis-document
```

Table: Files of the new system.

| File | Contents |
|---|---|
| `lexis.markdown.asd` | The `lexis.markdown` and `lexis.markdown/tests` systems |
| `src/markdown/package.lisp` | The `lexis.markdown` package |
| `src/markdown/translate.lisp` | Calls 3bmd and translates its tree into Lexis forms; the only file that knows 3bmd |
| `src/markdown/passes.lisp` | Passes over Lexis forms: joining text, decoding entities, nesting sections, wrapping literals, filtering URIs |
| `src/markdown/markdown.lisp` | `markdown->lexis`, `parse-markdown`, the options |
| `test/markdown/` | The test package and tests |

The steps of a conversion:

1. Parse with 3bmd, with its extension switches bound on.
2. Collect `:reference` definitions into a table, keyed by label without
   regard to case.
3. Translate the tree into Lexis forms, node by node (below).
4. Join adjacent strings, and decode HTML entities, named and numeric;
   unknown entities stay as text. Soft line breaks stay as newlines,
   which renderers collapse.
5. Group the flat sequence of headings into nested sections. A heading
   closes the open sections at its level or deeper and opens a section
   inside the one that remains. Content before the first heading stays at
   the top level.
6. Wrap strings containing inline markup characters in `literal`
   (LEXIS-DRAFT-rendermarkdown-D4). Code and code-block text is already
   literal and is not wrapped.

Output symbols are interned in the `lexis` package. A 3bmd node the
translator does not know signals a warning and is translated as its
text, so a change in 3bmd degrades output rather than failing.

### Node mapping

Table: How each 3bmd node is translated.

| 3bmd node | Lexis form |
|---|---|
| `(:heading :level N :contents …)` | `(section (@ :title "…") …)`, nested by step 5; title flattened (LEXIS-DRAFT-rendermarkdown-D6) |
| `(:paragraph …)` | `(paragraph …)` |
| `(:plain …)` | Its contents, inline, in the enclosing item or cell |
| `(:emph …)`, `(:strong …)` | `(emphasis …)`, `(strong …)` |
| `(:code "…")` | `(code "…")` |
| `(code-block :lang L :content "…")` | `(code-block (@ :language L) "…")`; no `:language` when L is absent |
| `(:verbatim "…")` | `(code-block "…")`, trailing newline removed |
| `(:block-quote …)` | `(blockquote …)` |
| `(:bullet-list …)`, `(:counted-list …)` | `(unordered-list …)`, `(ordered-list …)` |
| `(:list-item …)` | `(item …)` |
| `(:explicit-link :label … :source U :title T)` | `(web-link (@ :uri U :title T) …)`, or `classic-link` for a `classic:` URI; filtered by LEXIS-DRAFT-rendermarkdown-D9 |
| `(:reference-link :label … :tail …)` | As an explicit link, resolved from the table of step 2; unresolved, the original text |
| `(:link "U")`, `(:mailto "U")` | `(web-link (@ :uri "U") "U")` |
| `(:image (:explicit-link …))` | `(image (@ :src U :alt "…"))`; alt text flattened |
| `(wiki-link :label (T) :args (D))` | The resolver's result (LEXIS-DRAFT-rendermarkdown-D10) |
| `(table :head … :body …)` | `(table (row (@ :header t) (cell (@ :header t) …)) (row (cell …)))`; column alignment dropped |
| `(definition-list (:terms … :definitions …))` | `(definition-list (definition (@ :term "…") …))`; several terms joined with commas |
| `(:raw-html "…")`, `(:html "…")` | By the `:raw-html` policy (LEXIS-DRAFT-rendermarkdown-D8); a block becomes a paragraph |
| `(:entity "&…;")` | The decoded character, joined by step 4 |
| `(:line-break)`, `(:horizontal-rule)` | Dropped (LEXIS-DRAFT-rendermarkdown-D7) |
| `(:reference …)` | Removed after step 2 |

3bmd's smart quotes extension stays off, so the author's quotation marks
and dashes are kept as written.

### Tests

A separate system, `lexis.markdown/tests`, so that the core tests do not
load 3bmd. Tests give Markdown input and compare the Lexis output, so
they survive a change of parser. They cover:

- each row of the node mapping;
- section nesting: skipped levels, content before the first heading,
  sibling and nested sections;
- literal text: escaped `\*`, `[[`, `~~` and backticks rendering as
  written through `render-html`;
- reference links, resolved and unresolved;
- the raw HTML policies and the URI filter, including `javascript:`;
- the default and a custom wiki link resolver;
- end-to-end rendering of a sample post through `lexis.html`;
- 3bmd's known divergences, grouped and marked as such, so that a
  replacement parser shows which ones it fixes.

The core additions are tested in the existing `lexis/tests` suites.

### Using the reader from Classic

Classic's Composer replaces `render-markdown-stub` with a call to
`markdown->lexis`, and supplies a wiki link resolver in wiki contexts.
That change belongs to the classic.composer repository and is outside
this plan; LEXIS-DRAFT-rendermarkdown-O3 records a question it raises.


## Deferred Work

In order of priority:

1. **Horizontal rules and hard line breaks** (LEXIS-DRAFT-rendermarkdown-D7):
   add Lexis tags for both, with HTML rendering, and translate them.
2. **Headings with inline markup** (LEXIS-DRAFT-rendermarkdown-D6): let a
   section carry a title made of Lexis nodes, and stop flattening
   headings. Definition list terms can keep their markup without a
   change to Lexis, since a term may already be a list of nodes.
3. **Replacing 3bmd** (LEXIS-DRAFT-rendermarkdown-D2) with a parser that
   follows CommonMark, which would fix the divergences under
   [Problem](#problem).
4. Strikethrough (LEXIS-DRAFT-rendermarkdown-D5), footnotes into `note`,
   table column alignment, and ordered list start numbers, as a parser
   provides them.


## Scope and Non-Goals

- **Conformance to CommonMark** is not a goal of the first version.
- **Rendering Lexis to Markdown** (the specification's §8.4) and a round
  trip between the two are out of scope; the Survey's fidelity principle
  makes the stored Markdown authoritative.
- **Changing Lexis's `[[display|uri]]` link order**, which the Survey also
  suggests, is a separate change.
- **Classic's side**: the Composer change and wiki link extraction from
  Markdown bodies are Classic work.


## Open Questions

### LEXIS-DRAFT-rendermarkdown-O1 — A leading level-one heading

When `:document` is true, should a leading `# Title` become the
document's `:title` rather than a section? Current thinking: yes when it
is the only level-one heading and no `:title` is given; otherwise every
heading becomes a section.

### LEXIS-DRAFT-rendermarkdown-O2 — Section identifiers

Should sections get `:id`s derived from their headings, so that
`[text](#anchor)` links and cross-references work? Current thinking: yes,
in the style GitHub uses — lower case, hyphens for spaces, a numeric
suffix for duplicates.

### LEXIS-DRAFT-rendermarkdown-O3 — Heading depth inside the Composer

The Composer wraps a multi-block body in an untitled `section`, which
pushes the body's headings one level deeper when rendered. Should the
reader take a starting depth, or should the Composer stop wrapping?
Current thinking: the Composer should stop wrapping, since an untitled
section is not a real section.

### LEXIS-DRAFT-rendermarkdown-O4 — YAML front-matter

Compass documents and many wiki pages begin with a YAML front-matter
block, which 3bmd would read as a horizontal rule and text. Should the
reader strip it, or read it into document attributes? This matters for
the Survey's goal of editing Compass documents through the wiki.

### LEXIS-DRAFT-rendermarkdown-O5 — Where the Markdown mapping is documented

The mapping and the reader's options need a reference. The Lexis
specification is now a Compass `Spec`
([LEXIS-DRAFT-lexis](Spec.Lexis.md)). Should the mapping become a
section of it, or a new Compass `Ref` for `lexis.markdown`?


## Prior Art

The systems below are named from general knowledge, except 3bmd, whose
output was checked for this plan by running it on sample input.

Table: Prior systems and what this plan draws from each.

| System | What to draw from |
|---|---|
| 3bmd | The parser of the first version; its Lisp tree is the input of the translator |
| Pandoc | Readers that produce a document tree independent of any output format, with raw content kept as format-tagged blocks, as Lexis passthrough does |
| unified, remark and rehype | A Markdown syntax tree transformed into another tree by separate passes, and sanitisation as an explicit step |
| GitHub's Markdown pipeline | Raw HTML and URI sanitisation for user content; heading anchors |
| CommonMark | The specification a replacement parser should follow, and its examples as a measure of conformance |
| MediaWiki and Obsidian | Wiki links resolved against a set of pages, with broken links marked |


## Roadmap

Each step ends with all tests passing and is recorded in a Log.

1. **The `literal` tag.** Class, registration, `process-text` method,
   HTML rendering, tests, and the specification's entries.
2. **Tables and definition lists in core.** The five tags with HTML
   rendering and tests (LEXIS-DRAFT-rendermarkdown-D11).
3. **The `lexis.markdown` skeleton.** The systems, the package, the 3bmd
   call, `markdown->lexis` and `parse-markdown`; paragraphs and inline
   nodes; joining text, entities and literal wrapping; the test system.
4. **Blocks and links.** Lists, code blocks, block quotes, images, and
   explicit, reference and automatic links, with the URI filter.
5. **Sections.** The nesting pass and the `:document` option, settling
   LEXIS-DRAFT-rendermarkdown-O1 and LEXIS-DRAFT-rendermarkdown-O2.
6. **Extensions and policies.** Tables, definition lists, wiki links with
   the resolver, and the raw HTML policy.
7. **Documentation.** The README, the mapping reference
   (LEXIS-DRAFT-rendermarkdown-O5), and an end-to-end example.
8. **Classic.** Hand over to the classic.composer repository: replace
   `render-markdown-stub`, settling LEXIS-DRAFT-rendermarkdown-O3.
