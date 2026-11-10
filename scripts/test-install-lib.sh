#!/bin/sh
# Run the actual installer's isolated end-to-end regression suite.
set -eu
cd "$(dirname "$0")/.."
exec python3 -m unittest discover -s scripts -p 'test_*.py' -v
