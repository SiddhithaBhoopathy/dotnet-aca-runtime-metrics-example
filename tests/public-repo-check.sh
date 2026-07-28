#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

required=(
  Dockerfile
  launch.sh
  Directory.Packages.props
  src/RuntimeMetricsExample.csproj
  src/Program.cs
  deploy.sh
  README.md
  .dockerignore
  .gitignore
  LICENSE
)

for file in "${required[@]}"; do
  test -f "$file" || {
    echo "missing required file: $file" >&2
    exit 1
  }
done

grep -Fq 'ARG SERVERLESS_INIT_VERSION=1.9.15' Dockerfile
grep -Fq 'FROM datadog/serverless-init:${SERVERLESS_INIT_VERSION} AS ddinit' Dockerfile
grep -Fq 'ENV DD_RUNTIME_METRICS_ENABLED=true' Dockerfile
grep -Fq 'exec /dd/datadog-init "$@"' launch.sh

grep -Fq 'dotnet-runtime-metrics-init196' deploy.sh
grep -Fq 'dotnet-runtime-metrics-init1915' deploy.sh
grep -Fq 'SERVERLESS_INIT_VERSION=1.9.6' deploy.sh
grep -Fq 'SERVERLESS_INIT_VERSION=1.9.15' deploy.sh
grep -Fq 'DD_SERVICE=dotnet-runtime-metrics-demo' deploy.sh
grep -Fq 'DD_API_KEY=secretref:dd-api-key' deploy.sh

if rg -n -i \
  'SLES-[0-9]+|unitservice|fnac|darty|768b21c7|ddruntimerepro|/Users/|collected-logs' \
  --glob '!tests/**' .; then
  echo "found investigation-specific content" >&2
  exit 1
fi

if rg -n 'DD_API_KEY=[A-Za-z0-9]{20,}' --glob '!tests/**' .; then
  echo "found a possible literal Datadog API key" >&2
  exit 1
fi

if rg --files | rg '(^|/)\.env$|\.log$'; then
  echo "found a secret environment file or log" >&2
  exit 1
fi

echo "public repository checks passed"
