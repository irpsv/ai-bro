#!/usr/bin/env bash
# Публикует GitHub Release, если push в main сменил version в манифестах.
# Диапазон заметки — от предыдущего semver-тега, а если тега нет, от коммита до push.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

SEMVER_RE='^[0-9]+\.[0-9]+\.[0-9]+$'
ZERO_SHA_RE='^0+$'

die() {
  echo "release-plugin: $*" >&2
  exit 1
}

version_lt() {
  [[ "$1" != "$2" ]] && [[ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" == "$1" ]]
}

require_semver() {
  local label="$1"
  local value="$2"
  [[ "$value" =~ $SEMVER_RE ]] || die "$label: версия «$value» не в формате X.Y.Z"
}

version_at() {
  local sha="$1"
  local file="$2"
  local expr="$3"
  local value=""
  if git cat-file -e "${sha}:${file}" 2>/dev/null; then
    value="$(git show "${sha}:${file}" | jq -r "$expr" 2>/dev/null || true)"
  fi
  if [[ "$value" == "null" ]]; then
    value=""
  fi
  printf '%s' "$value"
}

before="${RELEASE_BEFORE_SHA:-}"
if [[ -z "$before" || "$before" =~ $ZERO_SHA_RE ]]; then
  echo "release-plugin: нет предыдущего коммита push. Релиз не создаётся."
  exit 0
fi

if ! git cat-file -e "${before}^{commit}" 2>/dev/null; then
  die "коммит до push не найден: $before"
fi

sha="$(git rev-parse HEAD)"
plugin_version="$(version_at "$sha" plugin.json '.version')"
cursor_version="$(version_at "$sha" .cursor-plugin/plugin.json '.version')"
market_version="$(version_at "$sha" .cursor-plugin/marketplace.json '.metadata.version')"
previous_version="$(version_at "$before" plugin.json '.version')"

if [[ -n "$previous_version" && "$previous_version" == "$plugin_version" && "$plugin_version" == "$cursor_version" && "$plugin_version" == "$market_version" ]]; then
  echo "release-plugin: версия $plugin_version не менялась. Релиз не создаётся."
  exit 0
fi

require_semver "plugin.json" "$plugin_version"
require_semver ".cursor-plugin/plugin.json" "$cursor_version"
require_semver ".cursor-plugin/marketplace.json" "$market_version"

if [[ "$plugin_version" != "$cursor_version" || "$plugin_version" != "$market_version" ]]; then
  die "версии манифестов расходятся: plugin.json=$plugin_version, .cursor-plugin/plugin.json=$cursor_version, .cursor-plugin/marketplace.json=$market_version. Релиз не создан."
fi

version="$plugin_version"

if gh release view "$version" >/dev/null 2>&1; then
  echo "release-plugin: релиз $version уже есть."
  exit 0
fi

previous=""
while IFS= read -r tag; do
  [[ "$tag" =~ $SEMVER_RE ]] || continue
  version_lt "$tag" "$version" || continue
  git merge-base --is-ancestor "$tag" HEAD || continue
  if [[ -z "$previous" ]] || version_lt "$previous" "$tag"; then
    previous="$tag"
  fi
done < <(git tag -l)

if [[ -z "$previous" ]]; then
  previous="$before"
fi

repo_url="$(git show "${sha}:plugin.json" | jq -er '.repository')"
repo_url="${repo_url%/}"

notes="$(mktemp)"
trap 'rm -f "$notes"' EXIT

{
  echo "## Что изменилось"
  echo
  commit_count=0
  while IFS= read -r subject; do
    [[ -z "$subject" ]] && continue
    echo "* $subject"
    commit_count=$((commit_count + 1))
  done < <(git log --no-merges --format='%s' "$previous..HEAD")
  [[ "$commit_count" -gt 0 ]] || die "между $previous и $sha нет коммитов для заметки"

  echo
  echo "Скиллы:"
  echo
  skill_count=0
  while IFS= read -r skill; do
    [[ -z "$skill" ]] && continue
    if [[ -d "skills/$skill" ]]; then
      echo "* [$skill]($repo_url/tree/$version/skills/$skill)"
    else
      echo "* $skill (удалён)"
    fi
    skill_count=$((skill_count + 1))
  done < <(git diff --name-only "$previous..HEAD" -- skills/ | awk -F/ '$1 == "skills" && $2 != "" { print $2 }' | sort -u)
  if [[ "$skill_count" -eq 0 ]]; then
    echo "* В этом диапазоне скиллы не менялись."
  fi

  echo
  echo "**Full Changelog**: $repo_url/compare/$previous...$version"
} >"$notes"

echo "release-plugin: публикую $version от $previous ($sha)"
echo "RELEASE_NOTES_BEGIN"
cat "$notes"
echo "RELEASE_NOTES_END"

gh release create "$version" \
  --target "$sha" \
  --title "$version" \
  --notes-file "$notes"
