#!/usr/bin/env bash
#
# Minimal reproduction for notion-md: `sync <file> --force` hard-errors when a
# page is bound in frontmatter (valid page_id) but the local sync-state sidecar
# (.notion-md/sync/<page_id>.json) is absent — instead of establishing the
# sidecar from the remote page and proceeding.
#
# This is the exact state of a page created OUTSIDE notion-md (e.g. via the
# Notion API / a CLI) whose page_id was then written into .nmd frontmatter:
# a valid bound page, but no sidecar.
#
# Requirements:
#   - notion-md on PATH (or set NMD=/path/to/notion-md)
#   - NOTION_API_TOKEN set, for an integration with access to PARENT_PAGE_ID
#   - PARENT_PAGE_ID: a Notion page id the integration can create a child under
#   - a Notion API CLI on PATH as `ntn` (or adapt the create call to curl)
#
# Usage:
#   NOTION_API_TOKEN=... PARENT_PAGE_ID=<page-id> ./repro.sh
set -euo pipefail

NMD="${NMD:-notion-md}"
: "${NOTION_API_TOKEN:?set NOTION_API_TOKEN}"
: "${PARENT_PAGE_ID:?set PARENT_PAGE_ID to a page the integration can write under}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cd "$work"

echo "## 1. Create a page OUTSIDE notion-md (simulating any non-notion-md creator)"
page_json="$(ntn pages create --parent "page:${PARENT_PAGE_ID}" \
  --content "# repro placeholder" --json)"
page_id="$(printf '%s' "$page_json" | python3 -c 'import json,sys;print(json.load(sys.stdin)["id"])')"
echo "   created page_id=${page_id}"

echo "## 2. Establish a local .nmd + sidecar from the remote page"
echo "   (this is the only way to get a schema-complete frontmatter today)"
"$NMD" sync "$page_id" repro.nmd >/dev/null
echo "   tree:"; find . -type f | sort | sed 's/^/     /'

echo "## 3. With the sidecar present, 'sync --force' correctly NOOPs:"
"$NMD" sync repro.nmd --force >/dev/null && echo "   -> exit 0 (noop), as expected"

echo "## 4. Delete ONLY the sidecar — frontmatter still has a valid bound page_id."
echo "   This is exactly the 'created outside notion-md, bound, no sidecar' state."
rm -rf .notion-md
echo "   tree:"; find . -type f | sort | sed 's/^/     /'

echo "## 5. 'sync --force' now HARD-ERRORS instead of re-establishing from remote:"
set +e
"$NMD" sync repro.nmd --force
code=$?
set -e
echo "   -> exit ${code} (BUG: expected establish-from-remote + push, exit 0)"

# cleanup: trash the test page
ntn api "/v1/pages/${page_id}" -X PATCH -d '{"in_trash":true}' >/dev/null 2>&1 || true
