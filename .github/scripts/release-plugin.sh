#!/usr/bin/env bash
# Публикует GitHub Release, когда version в манифестах новее базового релиза.
# Релиз 2.0.0 создаётся вручную и служит нижней границей диапазона коммитов.
set -euo pipefail

BASELINE="${RELEASE_BASELINE:-2.0.0}"
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

SEMVER_RE='^[0-9]+\.[0-9]+\.[0-9]+$'

die() {
  echo "release-plugin: $*" >&2
  exit 1
}

version_lt() {
  [[ "$1" != "$2" ]] && [[ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" == "$1" ]]
}

version_le() {
  [[ "$1" == "$2" ]] || version_lt "$1" "$2"
}

require_semver() {
  local label="$1"
  local value="$2"
  [[ "$value" =~ $SEMVER_RE ]] || die "$label: версия «$value» не в формате X.Y.Z"
}

read_version() {
  local file="$1"
  local expr="$2"
  jq -er "$expr" "$file"
}

plugin_version="$(read_version plugin.json '.version')"
cursor_version="$(read_version .cursor-plugin/plugin.json '.version')"
market_version="$(read_version .cursor-plugin/marketplace.json '.metadata.version')"

require_semver "plugin.json" "$plugin_version"
require_semver ".cursor-plugin/plugin.json" "$cursor_version"
require_semver ".cursor-plugin/marketplace.json" "$market_version"

if [[ "$plugin_version" != "$cursor_version" || "$plugin_version" != "$market_version" ]]; then
  die "версии манифестов расходятся: plugin.json=$plugin_version, .cursor-plugin/plugin.json=$cursor_version, .cursor-plugin/marketplace.json=$market_version. Релиз не создан."
fi

version="$plugin_version"

if version_le "$version" "$BASELINE"; then
  echo "release-plugin: версия $version не новее $BASELINE. Релиз не создаётся: $BASELINE публикуется вручную."
  exit 0
fi

if gh release view "$version" >/dev/null 2>&1; then
  echo "release-plugin: релиз $version уже есть."
  exit 0
fi

if ! gh release view "$BASELINE" >/dev/null 2>&1; then
  die "нет релиза $BASELINE. Сначала опубликуй его вручную, автоматика начинается со следующей версии."
fi

if ! git rev-parse -q --verify "refs/tags/$BASELINE" >/dev/null; then
  die "нет тега $BASELINE в локальной истории. Нельзя собрать заметку релиза."
fi

if ! git merge-base --is-ancestor "$BASELINE" HEAD; then
  die "тег $BASELINE не входит в историю текущего коммита. Релиз не создан."
fi

tagged_baseline="$(git show "$BASELINE:plugin.json" | jq -er '.version')"
if [[ "$tagged_baseline" != "$BASELINE" ]]; then
  die "тег $BASELINE указывает на коммит с version=$tagged_baseline. Ожидался коммит, где манифест уже равен $BASELINE."
fi

previous=""
while IFS= read -r tag; do
  [[ "$tag" =~ $SEMVER_RE ]] || continue
  version_lt "$tag" "$version" || continue
  version_le "$BASELINE" "$tag" || continue
  git merge-base --is-ancestor "$tag" HEAD || continue
  if [[ -z "$previous" ]] || version_lt "$previous" "$tag"; then
    previous="$tag"
  fi
done < <(git tag -l)

[[ -n "$previous" ]] || die "не найден предыдущий тег в диапазоне $BASELINE..$version"

tagged_previous="$(git show "$previous:plugin.json" | jq -er '.version')"
if [[ "$tagged_previous" != "$previous" ]]; then
  die "тег $previous указывает на коммит с version=$tagged_previous."
fi

sha="$(git rev-parse HEAD)"
repo_url="$(jq -er '.repository' plugin.json)"
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
