# OKF Format Reference

Open Knowledge Format (OKF) v0.2 essentials for authoring and consuming bundles.

Specification: https://github.com/GoogleCloudPlatform/open-knowledge-format

## Bundle structure

A **knowledge bundle** is a directory. It is version-controllable, portable, and contains:

```
<bundle>/
  index.md          # bundle banner (frontmatter) + one-level index of concepts
  log.md            # bundle-level changelog (validated by okf validate --all)
  <type>/           # concept type directory (e.g., tables/, references/)
    <slug>.md       # one markdown concept per file
  <other-type>/
    <slug>.md
```

- `index.md` enables progressive disclosure: navigate one level at a time instead of loading the whole bundle.
- Concept paths are `<type>/<slug>`, so the concept id is like `tables/customers` or `platform/routes/auth`.
- Bundles may nest (a sub-directory can have its own `index.md`).

## Concept frontmatter

Required keys (a concept missing these fails validation):

| Key | Type | Notes |
|-----|------|-------|
| `type` | string | Concept category, e.g., `tables`, `references`, `documents`, `actors`, `standards`. Often mirrors the directory name. |
| `title` | string | Human-readable name: "Customers" not "customers". |
| `description` | string | Concise faithful summary (< ~200 chars preferred). Used by indexes, search, and unload placeholders. |

Recommended / optional keys:

| Key | Type | Notes |
|-----|------|-------|
| `tags` | array[string] | Lookup/filter tags. |
| `generated` | date | When produced. |
| `verified` | date | When confirmed by a human/authority. |
| `status` | string | `stable` / `draft` / `deprecated`. |
| `sources` | array | Provenance entries; may carry credibility signals. |
| `stale_after` | date | Freshness expiry hint. |

Any extra keys are allowed — the format is extensible; consumers ignore what they don't know.

### Example concept

```markdown
---
type: tables
title: Customers
description: Customer master table — like_id, status, signup_at; one row per registered customer.
tags: [customer, reference]
status: stable
verified: 2026-01-15
---

# Customers

Customer master. One row per registered customer.

## Fields

| Field | Type | Notes |
|-------|------|-------|
| like_id | STRING | Unique customer id |
| status | STRING | `active`, `dormant`, `churned` |

## Related

See [Contracts](/tables/contracts.md) for contract rows per customer.
```

## Link conventions

- Internal links are normal relative markdown links: `[Contracts](/tables/contracts.md)`.
- Link targets must exist; `okf validate --all` reports broken cross-links.
- Cross-links express the graph (dependency, enrichment, ownership) richer than the directory tree alone.
- `okf_refs` inverts the link graph to answer "who depends on this concept?".

## Validation rules (okf validate)

Concept-level (per concept):
- `type`, `title`, `description`, `tags` present and non-empty.
- Body is non-empty.
- Malformed YAML in frontmatter loads as empty and surfaces as a `yaml-error`.

Bundle-level (`--all`):
- `index.md` present.
- `log.md` present.
- `okf_version` banner present (if your bundle declares it).
- No broken cross-links.
- Log entries reference added/updated/removed concept ids.

## Consuming OKF

Any reader can `cat` a concept and ingest it verbatim. For context-efficient consumption:

1. Read `index.md` (titles + descriptions).
2. `okf search` metadata-first (title/description/tags); body search only as fallback.
3. `okf read <id>` full text only for what you need; prefer `--section`/`--max-chars` for large concepts.
4. Unload after use (plugin auto-unloads after N turns, or explicitly).