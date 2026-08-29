#!/usr/bin/env bash
# tools/lint.sh — the repo's own checks: bash syntax + shellcheck.
# Run it by hand before committing:  ./tools/lint.sh
# (Deliberately no CI workflow — this repo is small enough to lint locally.)
set -Eeuo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

FILES=(install.sh lib/common.sh scripts/*.sh tools/*.sh)
status=0

echo "▸ bash -n (syntax)"
for f in "${FILES[@]}"; do
  if bash -n "$f"; then printf '  ok   %s\n' "$f"; else printf '  FAIL %s\n' "$f"; status=1; fi
done

echo "▸ shellcheck"
if command -v shellcheck >/dev/null 2>&1; then
  # SC1091: the sourced lib/common.sh is resolved at runtime, not statically.
  if shellcheck --severity=warning --exclude=SC1091 "${FILES[@]}"; then
    echo "  ok   no warnings"
  else
    status=1
  fi
else
  echo "  skipped — shellcheck not installed (brew install shellcheck)"
fi

echo "▸ Brewfile groups"
# Every group an installer step asks for must actually resolve to packages,
# otherwise a rename in the Brewfile would silently install nothing.
# shellcheck source=lib/common.sh
source lib/common.sh
for g in terminal shell cli devops; do
  # `|| true`: grep exits 1 on zero matches, which common.sh's ERR trap would
  # turn into a crash instead of the FAIL line below.
  n=$( { brewfile_items "$g" brew; brewfile_items "$g" cask; } | grep -c . || true )
  if [[ $n -gt 0 ]]; then printf '  ok   %-9s %d packages\n' "$g" "$n"
  else printf '  FAIL %-9s resolves to nothing\n' "$g"; status=1; fi
done

[[ $status -eq 0 ]] && echo "✓ lint passed" || echo "✗ lint failed"
exit $status
