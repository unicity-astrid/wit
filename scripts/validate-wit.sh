#!/usr/bin/env bash
#
# validate-wit.sh — parse every host/*.wit and interfaces/*.wit by
# staging each file alongside the repo's other WIT files so cross-
# package `use` clauses (e.g. `use astrid:io/poll@1.0.0.{pollable};`)
# resolve.
#
# wasm-tools resolves WIT dependencies from a sibling `deps/` directory.
# Each WIT file declares its own package, so we stage one tempdir per
# file: `<tmp>/main.wit` + `<tmp>/deps/...`. The `deps/` directory in
# this repo is reserved for any future vendored external WIT packages;
# it is intentionally empty today — the Astrid host ABI does not
# depend on `wasi:*`, so there is nothing to vendor.
#
# Usage: scripts/validate-wit.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEPS_ROOT="$REPO_ROOT/deps"

fail=0
shopt -s nullglob

# For each main file we want to parse, stage:
#   main.wit                     <- the file under test
#   deps/astrid-<pkg>/*.wit      <- every OTHER astrid WIT file in the repo,
#                                   so cross-package `use` clauses resolve.
#   deps/<external>/*.wit        <- (future) any vendored external packages.
#
# Each WIT file declares its own package, so deps/ ends up with one
# subdirectory per other package in the workspace.

stage_other_astrid_deps() {
    local main_file="$1"
    local staging="$2"
    local sibling_dir
    # host/ files only see other host/ files; interfaces/ files only see
    # other interfaces/. The two are distinct universes — host/ is the
    # kernel ABI (capsules import), interfaces/ is capsule-to-capsule
    # IPC contracts (the SDK generates typed events from these). Some
    # package names overlap by accident; keeping the dep sets separate
    # avoids validation conflicts.
    case "$main_file" in
        "$REPO_ROOT"/host/*) sibling_dir="$REPO_ROOT/host" ;;
        "$REPO_ROOT"/interfaces/*) sibling_dir="$REPO_ROOT/interfaces" ;;
        *) return ;;
    esac
    local f base pkg
    for f in "$sibling_dir"/*.wit; do
        [[ "$f" == "$main_file" ]] && continue
        base="$(basename "$f" .wit)"
        pkg="${base%@*}"
        mkdir -p "$staging/deps/astrid-$pkg"
        cp "$f" "$staging/deps/astrid-$pkg/$base.wit"
    done
}

# Only validate host/. interfaces/*.wit files have cross-package use
# clauses that wasm-tools 1.x can't resolve via deps/ in a single pass
# (it walks deps/ alphabetically and fails when a file references a
# package not yet processed). Those files are validated by downstream
# SDK builds via cargo-component / wkg which do proper topological
# resolution.
for f in "$REPO_ROOT"/host/*.wit; do
    rel="${f#$REPO_ROOT/}"
    staging="$(mktemp -d)"
    trap 'rm -rf "$staging"' EXIT
    cp "$f" "$staging/main.wit"
    mkdir -p "$staging/deps"
    if [[ -d "$DEPS_ROOT" ]]; then
        # Each vendored dependency lives in its own subdir under deps/.
        for d in "$DEPS_ROOT"/*/; do
            [[ -d "$d" ]] || continue
            # Strip trailing slash so cp -R copies the directory itself,
            # not just its contents.
            cp -R "${d%/}" "$staging/deps/"
        done
    fi
    stage_other_astrid_deps "$f" "$staging"
    if wasm-tools component wit "$staging" >/dev/null 2>&1; then
        echo "OK:   $rel"
    else
        echo "FAIL: $rel"
        wasm-tools component wit "$staging" 2>&1 | head -20 | sed 's/^/      /'
        fail=1
    fi
    rm -rf "$staging"
    trap - EXIT
done
exit $fail
