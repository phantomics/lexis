---
id:            LEXIS-DRAFT-passthrough
title:         "Medium-Dependent Passthrough: Development Log"
genre:         Log
scope:         component
project:       Lexis
component:     lexis
language:      en
status:        Implemented
authors:
  - Andrew Sengul
approved-by:   Andrew Sengul
reviewed:      2026-11-16
provenance:
  assistant:     claude-opus-5-5
  session:       ses_1adfe7ad9ffeXhdMKb49yDBuUQ
  migrated-from: doc/DevLog.Passthrough.md@9ebd54f
decisions:
  - LEXIS-DRAFT-passthrough-D1
  - LEXIS-DRAFT-passthrough-D2
  - LEXIS-DRAFT-passthrough-D3
  - LEXIS-DRAFT-passthrough-D4
  - LEXIS-DRAFT-passthrough-D5
  - LEXIS-DRAFT-passthrough-D6
  - LEXIS-DRAFT-passthrough-D7
  - LEXIS-DRAFT-passthrough-D8
  - LEXIS-DRAFT-passthrough-D9
  - LEXIS-DRAFT-passthrough-D10
---

# Medium-Dependent Passthrough: Development Log

This document chronicles the design discussion and implementation of
the passthrough mechanism in Lexis. Prior to this work, Lexis had no
way to carry rendering-target-specific content — stylesheets, scripts,
LaTeX preamble lines, terminal escape sequences, or any other
verbatim material whose meaning is confined to a single output medium.


## Problem

The triggering question was how Lexis should render HTML `<style>`,
`<link rel="stylesheet">`, and `<script>` elements when those are
genuinely needed in a document (a chart widget, an embedded
interactive component, an article shipping its own scoped typography).

The obvious first move was to add `lexis-html-stylesheet` and
`lexis-html-script` classes to the core vocabulary. These would be
HTML-specific tags with structured attribute slots (`:href`, `:media`,
`:defer`, `:async`, etc.), registered alongside `lexis-paragraph` and
`lexis-section`.

But this approach has structural problems that compound over time:

**Vocabulary erosion.** Lexis's central commitment is that its tags
represent document concepts, not rendering instructions (spec §1.1).
HTML `<style>` and `<script>` are not document concepts; they are
rendering directives for one specific target. Putting them in core
violates the design principle for that target's benefit.

**Combinatorial growth.** Every output medium has its own escape
hatches. LaTeX has `\usepackage`, `\newcommand`, and raw `\if`
conditionals. Terminal renderers need raw ANSI sequences for
features that don't map to semantic tags. ePub requires OPF metadata.
PDF wants per-document font registration. JSON-LD blocks belong in
HTML output for SEO. If each target gets its own tag family, the
core vocabulary acquires a permanent dependence on every renderer
the project ever supports.

**Cross-target nonsense.** A `lexis-html-script` node is meaningless
to a markdown renderer or a terminal renderer. Either each non-HTML
renderer needs an explicit "skip HTML-specific tags" method for every
HTML-specific class, or unknown-tag pass-through emits a stray `<div
class="lexis-html-script">` into output it doesn't belong in.

**Loss of structural metadata.** Even when dedicated tags are added,
the structured-metadata advantage is shallower than it looks. A
`stylesheet` class with named slots for `:media` and `:disabled` can
validate those slots at parse time — but Lexis can't validate the
*content* of the CSS or the *URL* of an external sheet. The slot
discipline catches typos in attribute names; it doesn't catch
anything more meaningful than that.

The developer's framing of this — "a nagging feeling that this is outside
what should be Lexis's purview" — was precisely right. The dedicated-tag
approach treats Lexis as an HTML production tool with a thin semantic
veneer. The framing should be inverted: Lexis is a semantic document
format, and the medium-specific concerns belong in a clearly bounded
extension mechanism.


## Design Decisions

Five questions were settled during discussion before implementation
began.

Quotations attributed to the development session come from the
transcript of the session named in `provenance.session`.

### LEXIS-DRAFT-passthrough-D1 — Generality over specificity

**Status:** Implemented
**Context:** See [Problem](#problem).
**Decision:** Rather than adding HTML-specific tags, Lexis adopts a single general
**passthrough** mechanism for all medium-specific verbatim content.
A passthrough node names its target medium via an attribute and
carries opaque content; renderers for matching media emit the
content as-is, renderers for non-matching media skip it silently.

This pattern has strong prior art. Pandoc's raw blocks
(```` ```{=html} ... ``` ````), Org-mode's `#+BEGIN_EXPORT`,
AsciiDoc's `passthrough` blocks, Sphinx's `.. only::` directives,
Texinfo's `@ifhtml`/`@iftex` conditionals, and DocBook's
`<programlisting language="...">` all express the same idea. Lexis
joins this lineage rather than reinventing alongside it.

**Alternatives:** See [Problem](#problem).

### LEXIS-DRAFT-passthrough-D2 — Attribute name: `:medium`

**Status:** Implemented
**Context:** The developer's first sketch of the idea in the development
session was `(passthrough (:for :html) (:script ...))`, and the
assistant then asked: "Attribute name: `:for`, `:medium`, or
`:target`?"
**Decision:** The final choice was
`:medium`, for consistency with the spec's existing vocabulary —
sections §1.1 and §8 already talk about Lexis as a
"medium-independent" format with "multi-target rendering". Using the
same word for the target identifier ties the mechanism back to the
established design language.
**Alternatives:** The attribute identifying the target was initially proposed as `:for`
(reading naturally: "this is for HTML"). The development session also
weighed `:target`: "`:target` is technically accurate".

### LEXIS-DRAFT-passthrough-D3 — Children not parsed as Lexis

**Status:** Implemented
**Context:** The passthrough children are opaque target-native data.
**Decision:** They must
**not** be recursively walked by the Lexis parser.

The implementation captures passthrough children verbatim into a
dedicated `raw-content` slot at parse time, leaving the standard
`children` slot empty. The standard tree-walking traversals (text
processing, depth computation, child rendering) operate on `children`
and so naturally ignore passthrough content.

**Alternatives:** Without this, a
Spinneret form like `(:script :src "app.js")` would parse as an
unknown Lexis element with tag `:SCRIPT` (a keyword), polluting the
node tree with spurious `lexis-unknown-element` instances and
emitting warnings for content that was never meant to be Lexis in
the first place.

### LEXIS-DRAFT-passthrough-D4 — No special handling for inline vs block position

**Status:** Implemented
**Context:** In the development session, the developer said of
promoting assets to the document head: "The idea of auto-promotion to
the head is interesting but it feels like this is not rightly a Lexis
concern." The assistant then asked: "Inline vs. block context — should
passthrough behave differently when used inline within a paragraph vs.
as a block-level child? My instinct: no special handling; the renderer
splices content at its position regardless."
**Decision:** A passthrough may appear anywhere a child node is valid — at document
top level, between blocks within a section, inline within a paragraph.
The renderer emits its content at the position where the node appears.
If a passthrough
needs to be in `<head>`, the document author places it where the
host page template expects it, or the surrounding composer arranges
the document accordingly. Lexis does not pretend to know HTML's
placement rules.
**Alternatives:** No automatic head-promotion, no positional rewriting.
Before passthrough was proposed, the development session set out three
options for placing HTML assets: "Option A (position-preserving), B
(auto-promote to head), or C (document-level attributes for the head
case + nodes for the body case)".

### LEXIS-DRAFT-passthrough-D5 — Belongs in core, not in an HTML-extension section

**Status:** Implemented
**Context:** The passthrough mechanism is target-agnostic — it serves HTML
scripts, LaTeX preamble, terminal escape codes, RSS metadata, and
any future medium equally. It is the canonical extension point for
target-specific concerns.
**Decision:** That makes it a core feature of Lexis as a
multi-target format, not an HTML extension.

The new spec section was placed as §5.4, within the existing
"Extension Mechanism" chapter alongside custom tags, custom tag
registration, and the namespace convention for extension attributes.

**Alternatives:** For the HTML-specific tags that preceded passthrough,
the development session suggested that "it might belong in a new
"§11 HTML-Specific Extensions" section rather than the core
vocabulary." For passthrough itself it weighed "`§7.5 Medium-Dependent
Passthrough` (under Processing Model) or `§5.4 Passthrough` (under
Extension Mechanism). The latter feels right because passthrough is
fundamentally an extensibility mechanism."

### LEXIS-DRAFT-passthrough-D6 — Multi-target values

**Status:** Implemented
**Context:** The development session's design proposal gave the case of
one stylesheet for two media: `(passthrough (@ :for (:html :epub))
(:link :rel "stylesheet" :href "style.css"))`.
**Decision:** The `:medium` attribute accepts a single
keyword (`:medium :html`) or a list (`:medium (:html :epub)`) for
content valid in more than one target.
**Alternatives:** Not recorded in the original or its session.

### LEXIS-DRAFT-passthrough-D7 — Aliases

**Status:** Implemented
**Context:** The development session asked: "Naming: `passthrough` vs.
`raw` vs. `verbatim` vs. `emit`?", and recommended: "I prefer
`passthrough` for clarity, with maybe a short alias if you want."
**Decision:** `pthru` is accepted as a nickname for `passthrough`.
Both parse to the same node class.
**Alternatives:** The other names, as the development session assessed
them: "`raw` is shorter but ambiguous (raw what?)"; "`verbatim` echoes
TeX/Markdown convention"; "`emit` suggests imperative action".

### LEXIS-DRAFT-passthrough-D8 — Metadata attributes

**Status:** Implemented
**Context:** Not recorded in the original or its session.
**Decision:** Beyond `:medium`, passthrough nodes may
carry arbitrary additional attributes (`:kind`, `:placement`,
`:priority`, etc.) that renderers may use as hints. The spec does
not assign meaning to these, but documents the convention so that
different renderers can converge on shared vocabulary over time.
**Alternatives:** Not recorded in the original or its session.

### LEXIS-DRAFT-passthrough-D9 — `:except` deferred

**Status:** Accepted
**Context:** There is no current use
case, and adding it later is a non-breaking change.
**Decision:** A complementary "render everywhere except X"
attribute was considered and deferred.
**Alternatives:** Not recorded in the original or its session.

### LEXIS-DRAFT-passthrough-D10 — Content types

**Status:** Implemented
**Context:** The development session identified the question: "The main
challenge is deciding what format the content takes—raw strings for
direct emission or structured forms that each renderer interprets in
its own way". Its design proposal allowed "A mix — strings and forms,
all passed through in sequence."
**Decision:** A passthrough child may be a string (emitted
raw, unescaped) or an s-expression (interpreted by the renderer
in its native convention — Spinneret forms for HTML). Both are
supported in the same node.
**Alternatives:** Not recorded in the original or its session.


## Implementation

### Node Class

`src/tags.lisp` gained the `lexis-passthrough` class
(`src/tags.lisp:lexis-passthrough@9ebd54f`) with a
`raw-content` slot dedicated to the verbatim child list. Two helper
methods are defined on the class:

- `src/tags.lisp:passthrough-targets@9ebd54f` — normalizes the `:medium` attribute into a
  list of keywords regardless of whether the source value was a single
  keyword or a list
- `src/tags.lisp:passthrough-applies-p@9ebd54f` — predicate testing whether a specific
  medium is named in the target list

The class is exported from `#:lexis` along with both accessors.

### Parser Specialization

The standard `parse-node ((form cons))` method
(`src/parse.lisp:parse-node@9ebd54f`) recurses into children
via `(mapcar #'parse-node children)`. For passthrough tags this
recursion must be skipped. A new helper,
`src/parse.lisp:raw-children-tag-p@9ebd54f`, returns
T for the `passthrough` and `pthru` tag names; when the helper
returns T, children are passed straight into the `:raw-content`
initarg with no recursive parsing.

The tag registry (`src/parse.lisp:*tag-registry*@9ebd54f`) was extended to map both `passthrough` and `pthru`
to the `lexis-passthrough` class. Because the registry uses string
keys (one of the design choices for package-independent parsing —
see the registry's docstring), this mapping works regardless
of which package the source s-expressions were read in.

### Text Processing

The text processing pass (`src/text-processing.lisp:process-text@9ebd54f`) traverses the
node tree expanding inline markup patterns (`*emphasis*`, `**strong**`,
`` `code` ``, `[[link|uri]]`, etc.) inside text-node children of each
element. A specialization on `lexis-passthrough` returns the node
unchanged, preventing the pass from descending into raw content.

In practice this is belt-and-suspenders: the pass operates on
`node-children`, and passthrough's children list is empty after
parsing (the content lives in `raw-content`). But the explicit method
documents the contract and ensures the behavior survives any future
restructuring of the traversal.

### HTML Renderer

`src/html/render.lisp` gained the `render-html-tree` method for
`lexis-passthrough` (`src/html/render.lisp:render-html-tree@9ebd54f`). The method:

1. Calls `passthrough-targets` to get the list of target media.
2. Tests membership in `src/html/render.lisp:*html-medium-keywords*@9ebd54f` (currently `(:html
   :html5)`). If no overlap, returns NIL — the parent's
   `render-children` filters NIL results, so the node contributes
   nothing to the output.
3. For matching media, converts each content item: strings become
   `(:raw ...)` for unescaped emission via Spinneret; s-expressions
   pass through unchanged.
4. For single-item content, returns the converted item directly. For
   multi-item content, returns a `(:lexis-splice ...)` sentinel that
   `render-children` recognizes and unrolls at the parent level —
   keeping the splice transparent (no wrapper element introduced).

`render-children` (`src/html/render.lisp:render-children@9ebd54f`) itself was extended with the `:lexis-splice`
handling. The pattern is simple: if a child's rendered result is a
cons whose CAR is `:lexis-splice`, NCONC its tail into the result
list; otherwise collect the rendered result as before.

### Spec

A new §5.4 "Medium-Dependent Passthrough" was added to
`doc/spec.md@9ebd54f`. The section covers:

- Syntax (the tag, the `:medium` attribute, content forms)
- Semantics (verbatim emission for matching media, silent skip
  otherwise)
- Examples spanning HTML stylesheets, scripts, raw HTML strings,
  multi-target content, inline-position usage, and a LaTeX example
- The convention for additional metadata attributes
- Text-processing exemption
- The `pthru` alias
- Security guidance (passthrough content from untrusted sources
  must be sanitized by the host)
- Conformance requirements for processors and renderers

Appendix A (Core Tag Summary) gained a passthrough row.


## Verification

A new block of tests was added across the three existing test files,
50 checks in total:

**`test/test-parse.lisp`** (8 tests, ~28 checks):
- Single string content preserved verbatim in `raw-content`
- Spinneret form children preserved as lists (not parsed as Lexis)
- Multiple children preserved as a list
- Multi-target `:medium` value normalized correctly
- `pthru` nickname parses to the same class
- Additional metadata attributes (`:kind`, `:placement`) accessible
- Missing `:medium` yields empty target list and no medium matches
- Tokens inside passthrough that look like Lexis tags do NOT trigger
  `unknown-tag-warning`

**`test/test-text-processing.lisp`** (1 test, 4 checks):
- Inline-markup characters (`*`, `[[`, `` ` ``) inside passthrough
  content survive the text processing pass unchanged

**`test/test-html.lisp`** (10 tests, ~18 checks):
- Spinneret form content renders verbatim into output
- String content emitted as raw HTML
- Non-matching medium yields no output
- Multi-target `:medium` including `:html` renders
- Passthrough inside a full document renders at correct position
- Non-HTML passthrough silently omitted from HTML output
- Multi-item passthrough splices at parent level (no wrapper, no
  `:lexis-splice` leakage)
- Inline-position passthrough renders inline at its position
- Script body with markup-like characters preserved verbatim
- `pthru` nickname renders identically to `passthrough`

Test count for the suite went from 136 to 186 (all passing). No
existing tests were modified; no regressions.

**Test command:**

```sh
sbcl --non-interactive \
  --eval '(ql:quickload "lexis/tests" :silent t)' \
  --eval '(unless (lexis/tests:run-tests) (uiop:quit 1))'
```

The counts were confirmed on 2026-11-16 by running the suite at
`9ebd54f` (186 checks, all passing) and at its parent, `dc33325` (136
checks, all passing).


## Files

Table: Files added or changed in commit `9ebd54f`.

| File | Action | Description |
|------|--------|-------------|
| `src/tags.lisp` | Modified | Added `lexis-passthrough` class with `raw-content` slot; `passthrough-targets` and `passthrough-applies-p` methods |
| `src/packages.lisp` | Modified | Exported `lexis-passthrough`, `passthrough-content`, `passthrough-targets`, `passthrough-applies-p` |
| `src/parse.lisp` | Modified | Added `raw-children-tag-p` helper; specialized `parse-node` to preserve raw content for passthrough tags; registered `passthrough` and `pthru` in tag registry |
| `src/text-processing.lisp` | Modified | Added `process-text` method on `lexis-passthrough` (no-op) |
| `src/html/render.lisp` | Modified | Added `*html-medium-keywords*`, `html-medium-match-p`, `passthrough-item-to-tree`, `render-html-tree` on `lexis-passthrough`; extended `render-children` with `:lexis-splice` sentinel handling |
| `doc/spec.md` | Modified | Now `doc/Spec.Lexis.md`. Renamed from `doc/lexis-spec.md`; added §5.4 "Medium-Dependent Passthrough"; added passthrough row to Appendix A |
| `test/test-parse.lisp` | Modified | Added 8 passthrough parsing tests |
| `test/test-text-processing.lisp` | Modified | Added 1 passthrough literal-preservation test |
| `test/test-html.lisp` | Modified | Added 10 passthrough rendering tests |
| `doc/Log.Passthrough.md` | **New** | This document, committed as `doc/DevLog.Passthrough.md` |


## The Principle That Emerged

The passthrough mechanism is a small piece of code but a meaningful
architectural choice. It resolves a tension that would otherwise grow:
Lexis must be useful for producing real HTML output (including assets,
scripts, structured data) but cannot afford to become an HTML library
wearing a semantic mask. By giving target-specific content a single,
well-bounded exit ramp, the core vocabulary stays semantic and every
future renderer gets the same escape hatch on the same terms.

The pattern composes naturally with the other extensibility mechanisms
already in the spec. Custom tags (§5.1) handle domain-specific semantic
vocabulary. The `prefix:attribute` namespace convention (§5.3) handles
extension metadata on existing tags. The Classic integration (§6)
handles ontological enrichment. Passthrough (§5.4) handles
medium-specific verbatim content. Each mechanism stays focused on its
own concern, and the boundaries between them are clear.

The same mechanism that handles HTML stylesheets today will, without
modification, handle LaTeX preambles for a future PDF renderer,
ANSI escape sequences for a terminal renderer, and OPF metadata for
an ePub renderer. Adding a new output target requires defining
methods on existing classes — not introducing new tags that every
other renderer must learn to ignore.


## Metrics

- Test checks added: 50 (136 → 186)
- Regressions: 0
- New source classes: 1 (`lexis-passthrough`)
- New source helpers: 5 (`raw-children-tag-p`, `passthrough-targets`,
  `passthrough-applies-p`, `html-medium-match-p`, `passthrough-item-to-tree`)
- Spec sections added: 1 (§5.4, ~110 lines)


## Outstanding Work

- **`:except`.** Deferred; see LEXIS-DRAFT-passthrough-D9.
