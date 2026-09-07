---
name: okf
description: "Work with Open Knowledge Format (OKF) knowledge bundles: author OKF-compliant markdown concepts with YAML frontmatter, organize knowledge bundles with index.md, and consume bundles via progressive disclosure (okf_list/okf_read/okf_search) to keep context small. Use when representing catalogs, planning documents, engineering knowledge, or survey data as version-controlled knowledge; when an agent or model needs to read part of a knowledge base without loading it all into context; or when validating/authoring OKF bundles (.opencode/skills/okf, okf bundle, OKF concept, index.md)."
---

# OKF — Open Knowledge Format

OKF is a universal, vendor-neutral format for representing knowledge as plain markdown files with YAML frontmatter, organized in version-controllable **knowledge bundles**. It is not tied to any agent, framework, or model provider.

## Why use OKF

- **Progressive disclosure**: an agent loads bundle indexes (small) first, then reads only the concepts it needs; the `opencode-okf-context` plugin can auto-unload them later. A large knowledge base never permanently bloats context.
- **Version-controllable**: bundles are directories in git — review, diff, blame, PR workflows work normally.
- **Portable/lock-in free**: a bundle is a directory of markdown; anyone can read it with `cat`, any LLM can ingest it verbatim.
- **Mixes structured and unstructured**: YAML frontmatter carries the fields you query/index (`type`, `tags`, `status`, `generated`, `verified`, `sources`); the markdown body carries what humans and LLMs read.
- **Graph-shaped**: concepts link to each other via normal markdown links, richer than just the directory tree.

## When to use this skill

- Authoring or editing an OKF knowledge bundle (any directory with `index.md` + concepts).
- Reading from a knowledge base without loading everything into context (use `okf_list` → `okf_read`/`okf_search`, then unload).
- Turning existing Banneker artifacts (survey data, planning documents, catalogs) into OKF bundles so downstream tools/agents can consume them progressively.
- Validating a bundle against the OKF spec.

## File layout: your skill base

- `reference/okf-format.md` — OKF spec essentials: bundle structure, frontmatter schema, required keys, link conventions.
- `reference/okf-plugin.md` — the `opencode-okf-context` plugin tools (`okf_list`, `okf_read`, `okf_search`, `okf_write`, `okf_validate`, `okf_unload`, `okf_refs`) and the `okf` CLI.
- `scripts/okf-init.sh` — scaffold a new bundle (creates `index.md` + `log.md`).
- `scripts/okf-concept.sh` — create or update a single concept with valid frontmatter.

Read the reference files when you need specifics; the workflow below is the day-to-day pattern.

## Authoring workflow

### 1. Scaffold or locate a bundle

A bundle is a directory containing concepts and an `index.md`. Use the init script or check whether a bundle already exists:

```bash
# find existing bundles
find . -name index.md -not -path "*/node_modules/*" 2>/dev/null
```

If none exists and you are authoring new knowledge, scaffold one:

```bash
scripts/okf-init.sh docs/knowledge my-bundle "Project knowledge base"
```

This creates `docs/knowledge/` with `index.md` (frontmatter banner + auto index) and `log.md`.

### 2. Create concepts

One file per concept, path layout `<bundle>/<type>/<slug>.md` (e.g., `docs/knowledge/tables/customers.md`, `platform/routes/auth.md`). Minimum frontmatter:

```yaml
---
type: tables
title: Customers
description: Customer master table — id, status, signup_at; one row per registered customer.
tags: [customer, reference]
---
```

Required frontmatter keys for a valid concept: `type`, `title`, `description`. Recommended: `tags`. Optional but encouraged for trust/freshness: `generated`, `verified`, `status` (`stable`/`draft`/`deprecated`), `sources` (with credibility signals), `stale_after`.

Write body prose in the markdown body. Use internal links to other concepts as normal relative paths: `[Contract](/tables/contracts.md)`.

### 3. Update the index

The plugin and spec use `index.md` to expose the bundle at one level at a time. Use the concept script to add an entry with its `type`, `title`, and `description` (the pieces that fit in an index without loading bodies). Run the init script's re-index step (or update `index.md` by hand) whenever concepts change.

### 4. Validate

```bash
npx -p opencode-okf-context okf validate --all --root docs/knowledge
```

Fix any errors it reports (it prints ready-to-run fix commands). A concept is valid when frontmatter `type`/`title`/`description`/`tags` are present and the body is non-empty.

## Reading workflow (progressive disclosure)

When you (or a downstream agent) must consult a knowledge base without loading it all:

1. **List** — `okf_list` (or the CLI `okf list`) to see what exists: titles + descriptions only.
2. **Search** — `okf_search` when you want to find relevant concepts by term; metadata-first, never loads bodies.
3. **Read** — `okf_read <id>` to pull the full concept text for just what you need. Use batch read for a cohesive unit (e.g., all tables in a project).
4. **Unload** — `okf_unload <id>` when done, or rely on the plugin's auto-unload (default after 4 user turns). Unloading frees the context the concept was occupying while keeping a placeholder summary.
5. **References** — `okf_refs <id>` to see a concept's dependency graph (who links to it / it links to) without loading bodies.

> On a resource-constrained machine, prefer `okf_read` with `--max-chars`/`--section` (CLI) or read only the subsection you need, so you never load full bodies you won't use.

## Representing Banneker artifacts as OKF

- **Survey data** → one bundle with concepts per section: `actors`, `walkthroughs`, `backend`, `rubric` concepts; keep the raw numbered data references in each concept body.
- **Planning documents** → a `documents` bundle, one concept per document type, with `type: documents`, cross-links between dependent documents (e.g., TECHNICAL-DRAFT links to STACK).
- **Technology/reference knowledge** (catalogs, engineering standards, rubric definitions) → concept types like `catalog`, `standard`, `rubric`, each with tags for lookup.
- Keep `description` under ~200 chars — it is the deterministic summary used by indexes, search, and unload placeholders; the body holds the depth.

## Quality rules

- Every concept has non-empty `type`, `title`, `description`.
- Concepts are one-per-file, under a `<type>/` subdirectory.
- `description` is a faithful, concise summary of the body (used for search + placeholders).
- Internal links use relative paths and point to existing concepts — validate with `okf validate --all`.
- No placeholders (`TODO`, `TBD`, `{...}`) in bodies.
- The bundle has a top-level `index.md` and a `log.md`.

## Success indicators

- [ ] Bundle validates clean (`okf validate --all`, exit 0)
- [ ] Index entries match concept frontmatter (type/title/description)
- [ ] Cross-links resolve to existing concepts
- [ ] Reading workflow demonstrated: list → read only what's needed → unload
- [ ] No context bloat: a large knowledge base was consulted without loading all bodies