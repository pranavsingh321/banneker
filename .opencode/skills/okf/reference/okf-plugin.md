# opencode-okf-context plugin reference

The `opencode-okf-context` plugin (npm: `opencode-okf-context`) gives OKF bundles **progressive disclosure** and **use-and-unload** semantics inside opencode: an agent can read from a large knowledge base without permanently bloating its context window.

It is a *knowledge-access* plugin (reads author-curated bundles), not a memory plugin.

## Add the plugin

In `opencode.json`:

```json
{ "plugin": ["opencode-okf-context@latest"] }
```

Verify the tools are registered:

```bash
opencode debug agent build | grep okf
# -> okf_list/read/search/write/validate/unload/refs: true
```

## Config (`.opencode/okf.jsonc`)

Layered deep-merge: `~/.config/opencode/okf.jsonc` → `$OPENCODE_CONFIG_DIR/okf.jsonc` → `<project>/.opencode/okf.jsonc` → plugin options in `opencode.json`.

```jsonc
// .opencode/okf.jsonc
{
  "enabled": true,
  "scan":   { "enabled": true, "maxDepth": 4 },
  "bundles": [{ "path": "docs/knowledge", "name": "project-kb" }],
  "disclosure": { "injectManifest": true, "maxManifestChars": 2000 },
  "unload": {
    "afterTurns": 4,          // unload after 4 user turns
    "keepRecent": 2,          // never auto-unload the 2 most recent reads
    "placeholder": "description"
  },
  "nudge":   { "threshold": 25000, "frequency": 3, "force": "soft" },
  "write":   { "enabled": true, "updateIndex": true, "appendLog": true },
  "protectedConcepts": ["tables/*"],
  "debug": false
}
```

- Auto-scan skips build/VCS/hidden directories **except `.opencode`**, so bundles placed under `.opencode/` are discovered automatically.
- `protectedConcepts` globs and the `keepRecent` most-recent reads are never auto-unloaded; explicit `okf_unload` always wins.

## Tools

| Tool | Purpose | Typical args |
|------|---------|--------------|
| `okf_list` | bundle / sub-directory index (titles + descriptions only) | `path?`, `bundle?` |
| `okf_read` | full concept markdown (+ out/in links, unload reminder footer) | `id` or `ids:[...]`, `bundle?` |
| `okf_search` | metadata-first search (title/description/tags), body fallback; returns refs + snippet, never full bodies | `query`, `bundle?`, `maxResults?` |
| `okf_write` | create/update/delete a concept | `id`, `type?`, `title?`, `description?`, `tags?`, `body?`, `mode?` (`update`/`delete`) |
| `okf_validate` | read-only validation report with ready-to-run fix commands | `id?` or `all:true`, `bundle?` |
| `okf_unload` | mark concept(s) for immediate unload | `id?` or `all:true`, `bundle?` |
| `okf_refs` | reference graph (who links to it + it links to), metadata only | `id`, `bundle?` |

### Unload semantics

A loaded concept's `okf_read` output becomes a compact placeholder (title + type + description) after enough turns or on `okf_unload`; stale `okf_search` results age out the same way (most recent kept). The same concept read twice keeps only the latest full text. When retained OKF content exceeds a threshold the plugin softly nudges (anchored on the last user message). All rewriting is outbound-only — real history is never mutated.

## CLI: `okf`

The package ships a standalone `okf` binary for non-opencode agents, humans, and CI. Install separately:

```bash
npm install -g opencode-okf-context        # or: npx -p opencode-okf-context okf ...
```

```bash
okf list                                   # browse a bundle index
okf search customer churn                  # metadata-first search
okf read tables/customers                  # full text
okf read reference/api_schema --section Authentication --max-chars 2000
okf validate --all                         # CI gate: exit 1 on validation errors
okf manifest                               # rule-file snippet for non-opencode agents
```

- Read intake control: `--fields` (metadata only), `--section <heading>`, `--max-chars <n>` — load less instead of unload later.
- Read-only by default: writes require `--write` (or `write.enabled: true` in config).
- Config: `<project>/.okf.jsonc`; `--root <path>` targets a bundle directly, `--bundle <name>` picks one.
- Exit codes `0`/`1`/`2` (ok / error / usage).

## Resource-constrained usage tips

- Prefer `okf_search` over `okf_read`; prefer `--section`/`--max-chars` over full bodies.
- Batch related concepts in one `okf_read` (loaded as a unit) instead of several separate reads.
- Unload promptly; on constrained context, rely on auto-unload defaults and keep `afterTurns` low.