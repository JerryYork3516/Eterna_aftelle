#!/usr/bin/env bash
set -euo pipefail

failures=0

report() {
  printf 'secret-guard: %s\n' "$1" >&2
  failures=1
}

if git ls-files | grep -E '\.digital_resident$' >/tmp/aftelle_tracked_dr_files.txt; then
  cat /tmp/aftelle_tracked_dr_files.txt >&2
  report 'real .digital_resident files must not be tracked in Git.'
fi

secret_pattern='(sk-[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9_]{30,}|xox[baprs]-[A-Za-z0-9-]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN (RSA|OPENSSH|EC|DSA|PRIVATE) KEY-----)'

if git grep -nIE "$secret_pattern" -- . ':(exclude)docs/**' ':(exclude)AGENTS.md' ':(exclude)CLAUDE.md' ':(exclude)README.md' >/tmp/aftelle_secret_hits.txt 2>/dev/null; then
  cat /tmp/aftelle_secret_hits.txt >&2
  report 'possible secret material found in tracked source.'
fi

config_secret_pattern='(api[_-]?key|secret|token)[[:space:]]*[:=][[:space:]]*["'\''][^"'\'']{16,}["'\'']'

if git grep -nIE "$config_secret_pattern" -- '*.swift' '*.json' '*.yml' '*.yaml' '*.toml' '*.env' >/tmp/aftelle_config_secret_hits.txt 2>/dev/null; then
  cat /tmp/aftelle_config_secret_hits.txt >&2
  report 'possible hard-coded key/token/secret assignment found.'
fi

if [ "$failures" -ne 0 ]; then
  exit 1
fi

printf 'secret-guard: ok\n'
