# LE Graph View — Specification

(with help from Claude Opus 4.7)

## Purpose
A web-based, interactive graph rendering of a Logical English (LE) program that exposes its knowledge structure at a glance and supports navigation back to source text. Built on Cytoscape.js, fed by the existing LE server web API.

## Node Types
Distinct visual styling per type (shape + color):

- **Knowledge Base** (compound) — contains all rules/facts/templates from `le_kb(Name)`.
- **Template / Predicate** — one per `le_dict` entry; label shows the NL pattern.
- **Rule** — one per clause with a body; label shows rule head or designator.
- **Fact** — one per ground clause.
- **Type** — from the ontology and template variable types.
- **Scenario** — compound node containing its facts.
- **Query** — with attached expected-answers metadata.

## Edge Types
- **uses** (Rule/Fact → Template) — rule body or head invokes a predicate.
- **defines** (Template → Type) — variable typing.
- **is-a** (Type → Type) — taxonomy from `is_a/2`.
- **depends-on** (Rule → Rule/Fact) — derived: head predicate of source matches body goal of target.
- **negates** (Rule → Template) — `not the case that` / `unless`.
- **expects** (Scenario → Query) — from `le_expected/3`.
- **scopes** (compound containment) — KB ⊇ rules; Scenario ⊇ facts.

## Server API Contract
The frontend consumes JSON from existing or thin-wrapper endpoints (check first if existing endpoints in classic_web_api.pl address these needs):

- `GET /le/kb/:name/graph` → `{ nodes: [...], edges: [...] }` where each node carries `{ id, type, label, ruleId, source: { start, end } }` populated from `le_source_info/4` and `le_source_element/3`.
- `GET /le/kb/:name/source` → raw LE text for the editor pane.
- `GET /le/kb/:name/issues` → `le_issue/6` records, attached to nodes by source range.
- `GET /le/kb/:name/scenario/:s` and `/query/:q` → on-demand expansion data.

The server is responsible for resolving designators, dependency edges, and type closures; the client only renders.

## Cytoscape Configuration
- **Layout**: `fcose` for the main view (handles compounds + clusters); `dagre` toggle for dependency-only views.
- **Style**: selector-based per node `type`; severity overlay (red/amber border) when `le_issue` matches a node's source range.
- **Compound nodes** for KB and Scenario containment.
- **Classes**: `.focused`, `.dimmed`, `.error`, `.warning`, `.path` for highlighting.

## Opening
The graph opens in its own browser tab from **Misc → View Source Graph** (or the editor's context menu). It talks to the editor over a BroadcastChannel for state, theme, and caret/selection sync.

## Interaction
- **Click node** → editor reveals and highlights `[start, end]` range; node gets `.focused`.
- **Editor caret move** → graph focuses node whose source range contains the offset.
- **Hover edge** → tooltip with edge type and source rule designator.
- **Filter panel** — toggle node/edge types to display; collapse compounds; show/hide negation edges. The layout algorithm, direction, and selected layers persist in LocalStorage, and toggling a layer re-runs the layout (newly shown nodes need positions).
- **Search** — by template pattern, rule designator, or type name; results highlight and pan.
- **Neighborhood query** — right-click node → "show dependents" / "show dependencies" / "show full chain".
- **Copy Node** — right-click node → copies the node's text (LE sentence / template / name) to the clipboard.
- **Copy URL** - from any visible element, allowing another user to display the same graph with that element focused

## Exclusions
Bookkeeping clauses never appear as nodes: `le_kb/1` and the expected-answer test records (`le_expected/N`, from "expects answers" scenario items).

## Out of Scope (of this v1)
Proof-tree visualization, runtime query evaluation traces, multi-KB cross-references, editing from the graph.

## Dev Requirements
Stable source ranges for every node; deterministic node IDs (so layout persists across reloads); a shared selection store between graph and editor (CodeMirror 6); URL-encoded view state (filters, focus, zoom) for shareable links.