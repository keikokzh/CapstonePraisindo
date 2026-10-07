#!/bin/sh
set -eu
cd "$(dirname "$0")/../backend"
exec go run ./cmd/migrate_v2 "$@"
