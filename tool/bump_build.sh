#!/usr/bin/env bash
# Adds one to the local build number (the 4th part of 1.0.0.N) in pubspec.yaml.
# Run before every build that goes out; the Play Store part (1.0.0) is changed
# by hand only when asked.
set -euo pipefail
cd "$(dirname "$0")/.."
current=$(grep -E '^version: ' pubspec.yaml | sed -E 's/^version: ([0-9.]+)\+([0-9]+)$/\1 \2/')
name=${current% *}
build=${current#* }
next=$((build + 1))
sed -i -E "s/^version: .*/version: ${name}+${next}/" pubspec.yaml
echo "${name}.${next}"
