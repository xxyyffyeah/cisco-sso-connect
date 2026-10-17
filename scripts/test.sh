#!/bin/bash
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"
/bin/bash scripts/build.sh
xcrun clang -fobjc-arc -O2 -Wall -Wextra -Wno-unused-parameter -Isrc \
    -framework Foundation src/Core.m tests/CoreHarness.m -o build/core-tests
python3 -m unittest discover -s tests -v
