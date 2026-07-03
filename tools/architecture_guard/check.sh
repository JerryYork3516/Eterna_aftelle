#!/usr/bin/env bash
set -euo pipefail

failures=0

report() {
  printf 'architecture-guard: %s\n' "$1" >&2
  failures=1
}

if [ -d brain ]; then
  if git grep -nE '^[[:space:]]*import[[:space:]]+(AppKit|SwiftUI|Metal|Security|SQLite3)\b' -- 'brain/**/*.swift' 'brain/*.swift' >/tmp/aftelle_brain_imports.txt 2>/dev/null; then
    cat /tmp/aftelle_brain_imports.txt >&2
    report 'brain/ must not import Apple UI/rendering, Keychain, or SQLite modules directly; route platform access through HostEnv.'
  fi
fi

if git grep -nE 'CREATE[[:space:]]+TABLE' -- '*.swift' '*.sql' >/tmp/aftelle_create_tables.txt 2>/dev/null; then
  while IFS= read -r hit; do
    file=${hit%%:*}
    line=${hit#*:}
    line_no=${line%%:*}
    start=$((line_no > 3 ? line_no - 3 : 1))
    end=$((line_no + 20))
    if ! sed -n "${start},${end}p" "$file" | grep -q 'schema_version'; then
      printf '%s\n' "$hit" >&2
      report 'storage tables must include schema_version.'
    fi
  done </tmp/aftelle_create_tables.txt
fi

if git grep -nE '(OpenAI|Anthropic|Claude|ProviderRouter|ProviderAdapter|LLM|callLLM|apiKey|key_ref)' -- 'apps/**/*.swift' >/tmp/aftelle_platform_provider_refs.txt 2>/dev/null; then
  if grep -vE '(RuntimeCore|ProviderProfile|Settings|key_ref|configuration|Trace|redact|redacted)' /tmp/aftelle_platform_provider_refs.txt >/tmp/aftelle_suspicious_provider_refs.txt; then
    cat /tmp/aftelle_suspicious_provider_refs.txt >&2
    report 'platform UI code has suspicious provider/LLM references; verify UI is not bypassing RuntimeCore ExecutionEngine.'
  fi
fi

if git grep -nE '\.digital_resident|resident.*write|write.*resident|revision' -- 'apps/**/*.swift' 'brain/**/*.swift' >/tmp/aftelle_dr_refs.txt 2>/dev/null; then
  if grep -E '\.digital_resident|/digital_resident|digital_resident' /tmp/aftelle_dr_refs.txt >/tmp/aftelle_dr_path_hits.txt; then
    if grep -E 'write|save|overwrite|FileHandle|Data\(.*write|write\(to:' /tmp/aftelle_dr_path_hits.txt >/tmp/aftelle_suspicious_dr_writes.txt; then
      cat /tmp/aftelle_suspicious_dr_writes.txt >&2
      report 'DR files are read-only; do not write memory, state, keys, or runtime data back into .digital_resident.'
    fi
  fi
fi

if [ "$failures" -ne 0 ]; then
  exit 1
fi

printf 'architecture-guard: ok\n'
