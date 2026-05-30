#!/usr/bin/env bash
#
# deploy.sh — one-click release.
#
# Bumps the version (patch by default), rebuilds + embeds the browser viewer,
# runs the test suite, opens a new CHANGELOG section, commits, tags, pushes,
# and publishes a GitHub release.
#
# The version source of truth is the latest git tag (SwiftPM resolves by tag).
#
# Usage:
#   ./deploy.sh                 # patch bump:  0.2.1 -> 0.2.2  (default)
#   ./deploy.sh minor           # minor bump:  0.2.1 -> 0.3.0
#   ./deploy.sh major           # major bump:  0.2.1 -> 1.0.0
#   ./deploy.sh 0.3.0           # explicit version
#   ./deploy.sh --dry-run       # print the plan + notes, change nothing
#   ./deploy.sh -y              # skip the confirmation prompt
#
# Env overrides:
#   SKIP_WEB=1      skip the viewer rebuild/embed (e.g. Node not installed)
#   ALLOW_BRANCH=1  allow releasing from a branch other than main
#
set -euo pipefail
cd "$(dirname "$0")"

info() { printf '\033[1;36m▸ %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

# ---- parse arguments ----------------------------------------------------------
BUMP="patch"; EXPLICIT=""; DRYRUN=0; YES=0
for arg in "$@"; do
  case "$arg" in
    patch|minor|major) BUMP="$arg" ;;
    --dry-run)         DRYRUN=1 ;;
    -y|--yes)          YES=1 ;;
    v[0-9]*|[0-9]*.[0-9]*) EXPLICIT="${arg#v}" ;;
    *) die "unknown argument: $arg (try: patch|minor|major | X.Y.Z | --dry-run | -y)" ;;
  esac
done

# ---- preconditions ------------------------------------------------------------
[ -f Package.swift ] || die "run from the repo root (Package.swift not found)"
command -v git >/dev/null || die "git not found"

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
[ "$BRANCH" = "main" ] || [ "${ALLOW_BRANCH:-0}" = "1" ] \
  || die "not on main (on '$BRANCH'); set ALLOW_BRANCH=1 to override"

[ "$DRYRUN" = "1" ] || [ -z "$(git status --porcelain)" ] \
  || die "working tree is dirty — commit or stash changes first"

git fetch --tags --quiet origin 2>/dev/null || true

# ---- compute the next version -------------------------------------------------
LATEST="$(git tag --list 'v*' | sort -V | tail -1)"
[ -n "$LATEST" ] || LATEST="v0.0.0"
CUR="${LATEST#v}"

if [ -n "$EXPLICIT" ]; then
  NEW="$EXPLICIT"
else
  IFS=. read -r MA MI PA <<<"$CUR"
  case "$BUMP" in
    patch) PA=$((PA + 1)) ;;
    minor) MI=$((MI + 1)); PA=0 ;;
    major) MA=$((MA + 1)); MI=0; PA=0 ;;
  esac
  NEW="$MA.$MI.$PA"
fi

echo "$NEW" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || die "invalid version: $NEW"
TAG="v$NEW"
git rev-parse "$TAG" >/dev/null 2>&1 && die "tag $TAG already exists"
[ "$(printf '%s\n%s\n' "$CUR" "$NEW" | sort -V | tail -1)" = "$NEW" ] \
  || info "warning: $NEW is not greater than current $CUR"

DATE="$(date +%Y-%m-%d)"
info "Release plan: $LATEST → $TAG  ($DATE)"

# ---- gather release notes from the Unreleased changelog section ---------------
NOTES="$(awk '/^## Unreleased/{f=1;next} /^## /{if(f)exit} f' CHANGELOG.md | sed '/^[[:space:]]*$/d')"
[ -n "$NOTES" ] || NOTES="- Maintenance release."
printf '\n--- release notes (from CHANGELOG ## Unreleased) ---\n%s\n----------------------------------------------------\n\n' "$NOTES"

if [ "$DRYRUN" = "1" ]; then info "dry run — nothing changed."; exit 0; fi

if [ "$YES" != "1" ]; then
  read -r -p "Publish $TAG? [y/N] " ans
  case "$ans" in y|Y) ;; *) die "aborted" ;; esac
fi

# ---- validate: rebuild the viewer, build, test --------------------------------
if [ "${SKIP_WEB:-0}" != "1" ] && [ -d Web ] && command -v npm >/dev/null; then
  info "Rebuilding + embedding the browser viewer…"
  ( cd Web && npm run release )
fi

info "Building the package…"
swift build >/dev/null

info "Running tests…"
LOG="$(mktemp -t treescope-deploy)"
if ! swift test >"$LOG" 2>&1; then
  tail -30 "$LOG"; rm -f "$LOG"; die "tests failed — aborting release"
fi
tail -1 "$LOG"; rm -f "$LOG"

# ---- open a new CHANGELOG section ---------------------------------------------
info "Updating CHANGELOG…"
awk -v v="$NEW" -v d="$DATE" '
  f==0 && /^## Unreleased[[:space:]]*$/ { print; print ""; print "## " v " — " d; f=1; next }
  { print }
' CHANGELOG.md > CHANGELOG.tmp && mv CHANGELOG.tmp CHANGELOG.md

# ---- commit, tag, push --------------------------------------------------------
info "Committing + tagging…"
git add -A
git commit -q -m "Release $NEW" -m "$NOTES"
git tag -a "$TAG" -m "Treescope $NEW" -m "$NOTES"

info "Pushing branch + tag…"
git push -q origin "$BRANCH"
git push -q origin "$TAG"

# ---- GitHub release -----------------------------------------------------------
if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  info "Creating GitHub release…"
  REPO_URL="$(git remote get-url origin | sed -E 's#git@github.com:#https://github.com/#; s#\.git$##')"
  REL_NOTES="$NOTES

**Install (SwiftPM):**
\`\`\`swift
.package(url: \"${REPO_URL}.git\", from: \"$NEW\")
\`\`\`

**Full changelog:** ${REPO_URL}/compare/$LATEST...$TAG"
  gh release create "$TAG" --title "$TAG" --verify-tag --notes "$REL_NOTES"
else
  info "gh not installed/authenticated — skipped the GitHub release (tag is pushed)."
fi

printf '\033[1;32m✓ Released %s\033[0m\n' "$TAG"
