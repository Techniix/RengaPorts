#!/bin/bash
# Adds packages to the RengaPorts package repository and publishes it.
#
#   tools/update-repo.sh [--no-push] <package.hpkg>...
#
# The repository lives on the "packages" branch (served by GitHub Pages at
# https://techniix.github.io/RengaPorts/x86_64/current). Each package
# replaces older versions of the same package; the index is rebuilt with
# package_repo; the branch is then pushed as one parentless commit, so its
# history does not grow with every package version. The recipes on "main"
# are not touched.
#
# package_repo: on Renga it is in the PATH; on a build host, point
# PACKAGE_REPO at the one from a Haiku/Renga build tree
# (generated.x86_64/objects/linux/x86_64/release/tools/package_repo/).
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

top="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
push=1
if [ "${1:-}" = --no-push ]; then push=0; shift; fi
[ $# -gt 0 ] || die "usage: $0 [--no-push] <package.hpkg>..."
package_repo="${PACKAGE_REPO:-package_repo}"
command -v "$package_repo" >/dev/null || die "package_repo not found (set PACKAGE_REPO)."

# Work in a separate checkout of the packages branch.
work="$(mktemp -d)"
trap 'git -C "$top" worktree remove --force "$work" 2>/dev/null || true' EXIT
if git -C "$top" fetch -q origin packages 2>/dev/null; then
  git -C "$top" worktree add -q --force -B packages "$work" FETCH_HEAD
else
  git -C "$top" worktree add -q --force --detach "$work"
  git -C "$work" checkout -q --orphan packages
  git -C "$work" rm -rq --cached . 2>/dev/null || true
  find "$work" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
fi

repo_dir="$work/x86_64/current"
mkdir -p "$repo_dir/packages"
cp "$top/repository/x86_64/repo.info" "$repo_dir/repo.info"

added=()
for pkg in "$@"; do
  [ -f "$pkg" ] || die "no such file: $pkg"
  file="$(basename "$pkg")"
  case "$file" in
    *-x86_64.hpkg|*-any.hpkg) ;;
    *) die "$file: only x86_64 (or 'any') packages belong in this repository." ;;
  esac
  name="${file%%-*}"   # package names use underscores, never hyphens
  find "$repo_dir/packages" -name "$name-*.hpkg" ! -name "$file" -print -delete \
    | sed 's|.*/|Removed old version: |'
  cp "$pkg" "$repo_dir/packages/$file"
  echo "Added: $file"
  added+=("$name")
done

shopt -s nullglob
packages=("$repo_dir"/packages/*.hpkg)
[ ${#packages[@]} -gt 0 ] || die "the repository has no packages."
rm -f "$repo_dir/repo" "$repo_dir/repo.sha256"
"$package_repo" create -q "$repo_dir/repo.info" "${packages[@]}"
[ -f "$repo_dir/repo" ] || die "package_repo didn't write $repo_dir/repo."
sha256sum "$repo_dir/repo" | cut -d' ' -f1 > "$repo_dir/repo.sha256"

# Plain package list for browsers (GitHub Pages has no directory listings).
{
  echo "<!DOCTYPE html><meta charset=utf-8><title>RengaPorts packages (x86_64)</title>"
  echo "<h1>RengaPorts packages (x86_64)</h1>"
  echo "<p>For Renga. Add this repository with:<br><code>pkgman add-repo https://techniix.github.io/RengaPorts/x86_64/current</code></p><ul>"
  for p in "${packages[@]}"; do
    f="$(basename "$p")"
    echo "<li><a href=\"packages/$f\">$f</a></li>"
  done
  echo "</ul>"
} > "$repo_dir/index.html"
touch "$work/.nojekyll"

[ "$push" = 1 ] || { echo "Repository updated in $work (not pushed)."; trap - EXIT; exit 0; }

git -C "$work" add -A
tree="$(git -C "$work" write-tree)"
commit="$(git -C "$work" commit-tree "$tree" -m "Update ${added[*]}")"
git -C "$top" push -qf origin "$commit:refs/heads/packages"
echo "Published. Renga picks it up on the next 'pkgman refresh' or update."
