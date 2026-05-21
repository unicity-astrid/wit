#!/usr/bin/env bash
#
# lint-wit-immutability.sh — enforces the frozen-WIT-file rule.
#
# Once a WIT file is named with an embedded version (`<name>@X.Y.Z.wit`),
# that file is published — its shape is committed to forever. Shape changes
# ship as a new file at a new version path.
#
# This script fails if any *@X.Y.Z.wit file present on the base ref was
# modified or deleted between the base ref and HEAD. New files matching the
# pattern are allowed (that is the legitimate evolution path).
#
# Usage:
#   scripts/lint-wit-immutability.sh [BASE_REF]
#
# BASE_REF defaults to origin/main.

set -euo pipefail

BASE_REF="${1:-origin/main}"

if ! git rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
    echo "error: base ref '$BASE_REF' not resolvable. Run 'git fetch' or pass a valid ref." >&2
    exit 2
fi

PATTERN='@[0-9]+\.[0-9]+\.[0-9]+\.wit$'

violations=$(git diff --name-status "$BASE_REF"...HEAD \
    | awk -F'\t' -v pat="$PATTERN" '
        ($1 == "M" || $1 == "D") && $2 ~ pat { print $1 "\t" $2 }
        $1 ~ /^R/ && $2 ~ pat { print "R\t" $2 " -> " $3 }
      ')

if [[ -z "$violations" ]]; then
    echo "wit immutability lint: ok"
    exit 0
fi

cat >&2 <<EOF
wit immutability lint: FAIL

The following published WIT files were modified, deleted, or renamed.
Published files (matching *@X.Y.Z.wit) are frozen — once shipped, their
shape is committed to forever. Shape changes ship as a new file at a
new version path.

$violations

If you need to evolve one of these interfaces:
  1. Copy the latest frozen file to a new version path
     (e.g. cp host/ipc@1.0.0.wit host/ipc@1.1.0.wit)
  2. Bump the package declaration inside the new file
     (package astrid:ipc@1.1.0;)
  3. Make your shape changes in the NEW file
  4. Leave the existing frozen file untouched

See README for the full evolution discipline.
EOF
exit 1
