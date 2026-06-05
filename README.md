# notion-md — `sync --force` hard-errors on bound page with no sidecar

`notion-md sync <file.nmd> --force` throws `NmdFrontmatterError: Missing sidecar
sync state for page <id>` and exits non-zero when the frontmatter has a valid
bound `page_id` but no local sync-state sidecar
(`.notion-md/sync/<page_id>.json`) exists — instead of establishing the sync
state from the remote page and proceeding.

This is the normal state of a page that was created **outside** notion-md (via
the Notion API or another CLI) and then had its `page_id` written into the
`.nmd` frontmatter: a valid bound page, but no sidecar.

## Reproduction

```bash
NOTION_API_TOKEN=<token> PARENT_PAGE_ID=<page-id> ./repro.sh
```

The script:

1. Creates a page outside notion-md (Notion API).
2. Establishes a local `.nmd` + sidecar from that remote page
   (`notion-md sync <page_id> <file>`).
3. Shows `sync --force` correctly noops while the sidecar is present.
4. Deletes only the sidecar (`.notion-md/`), leaving a valid bound `page_id`.
5. Runs `sync --force` again — which hard-errors.

No live page is strictly required to understand the bug: any `.nmd` with a valid
`page_id` in frontmatter and no `.notion-md/sync/<page_id>.json` triggers it.

## Expected

`sync --force` treats "bound `page_id` + no sidecar" as "establish sync state
from the remote page, then push" (idempotent establish-then-push), exiting 0.

## Actual

```
NmdFrontmatterError: Missing sidecar sync state for page <page_id>. Run `notion-md sync <page_id> <file>` to rebuild it.
```

Exit code 1. Note the error tells you to run `notion-md sync <page_id> <file>` —
which is exactly what `sync --force` could do automatically.

## Versions

- notion-md: 0.1.0 (effect-utils rev `1b2fa506e5a31f0f7bebb87268988d4add55dd85`)
- OS: Linux

## Related Issue

<!-- filled in after filing -->
