#!/usr/bin/env bash
# update-flake.sh — check github.com/storytold/craft-launcher for a new
# release and update sources.nix (version, tag, hashes) accordingly, then
# verify, commit and push.
#
# Usage: ./update-flake.sh [version]
#   version   optional, e.g. 0.5.0 or v0.5.0 (default: latest GitHub release)

set -euo pipefail

REPO="storytold/craft-launcher"
NIX_REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCES="$NIX_REPO_DIR/sources.nix"
ARCHES=(x86_64 aarch64)

log()  { printf '\033[1;36m::\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; }
die()  { err "$*"; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || die "missing dependency: $1"; }
need curl
need nix
need git
need tar

# --- 1. Determine the target version -----------------------------------------
if [[ $# -ge 1 ]]; then
    NEW="${1#v}"
else
    log "querying GitHub for the latest release of $REPO ..."
    # no jq needed: pull tag_name out of the release JSON
    NEW=$(curl -sfL "https://api.github.com/repos/$REPO/releases/latest" \
        | sed -n 's/^[[:space:]]*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -1) \
        || die "could not query GitHub API (network? rate limit?)"
    NEW="${NEW#v}"
fi
[[ "$NEW" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "not a valid version: $NEW"
TAG="v$NEW"

# --- 2. Compare with the current version -------------------------------------
CURRENT=$(sed -n 's/^  version = "\([^"]*\)";$/\1/p' "$SOURCES")
[[ -n "$CURRENT" ]] || die "could not read current version from sources.nix"

if [[ "$NEW" == "$CURRENT" ]]; then
    log "already up to date (v$CURRENT) — nothing to do"
    exit 0
fi
log "updating: v$CURRENT -> v$NEW"

# --- 3. Verify the release exists and download+hash every arch tarball -------
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

declare -A HASHES
for arch in "${ARCHES[@]}"; do
    name="artcraft-launcher-$NEW-linux-$arch.tar.gz"
    url="https://github.com/$REPO/releases/download/$TAG/$name"
    log "downloading $name ..."
    curl -sfL -o "$tmpdir/$name" "$url" || die "download failed: $url"

    # sanity check: it must be a valid gzip archive
    tar -tzf "$tmpdir/$name" >/dev/null || die "$name is not a valid tar.gz"

    # nix hash file --sri prints the SRI hash (sha256-<base64>)
    HASHES[$arch]=$(nix hash file --sri "$tmpdir/$name")
    log "  ${arch}: ${HASHES[$arch]}"
done

# --- 4. Patch sources.nix ------------------------------------------------------
backup="$SOURCES.bak"
cp "$SOURCES" "$backup"

# version and tag lines
sed -i \
    -e "s|^  version = \"[^\"]*\";|  version = \"$NEW\";|" \
    -e "s|^  tag = \"v[^\"]*\";|  tag = \"$TAG\";|" \
    "$SOURCES"
grep -q "version = \"$NEW\"" "$SOURCES" || { mv "$backup" "$SOURCES"; die "failed to patch version"; }

# hash lines:    x86_64-linux.hash = "sha256-...";
for arch in "${ARCHES[@]}"; do
    sed -i "s|^\(    ${arch}-linux.hash = \"\)sha256-[^\"']*\(\"\;\)$|\1${HASHES[$arch]}\2|" "$SOURCES"
    grep -qF "${arch}-linux.hash = \"${HASHES[$arch]}\"" "$SOURCES" \
        || { mv "$backup" "$SOURCES"; die "failed to patch hash for $arch"; }
done
rm -f "$backup"
log "sources.nix updated"

# --- 5. Verify the flake still builds and checks -------------------------------
cd "$NIX_REPO_DIR"
log "building the flake ..."
nix build .#default --no-link >/dev/null || die "build failed — sources.nix left as-is"
log "running nix flake check ..."
nix flake check --all-systems --no-build >/dev/null || die "flake check failed — sources.nix left as-is"

# --- 6. Commit and push ---------------------------------------------------------
if [[ -n "$(git status --porcelain -- sources.nix)" ]]; then
    git add sources.nix
    git -c user.name="${GIT_AUTHOR_NAME:-atlas}" -c user.email="${GIT_AUTHOR_EMAIL:-a@b}" \
        commit -m "update to v$NEW"
    git push origin main || die "push failed (auth? remote branch moved?)"
    log "pushed update to v$NEW 🎉"
else
    log "no changes to commit (sources.nix unchanged after patching?)"
fi
