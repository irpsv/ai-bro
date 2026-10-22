#!/usr/bin/env bash
# Проверяет публикацию релиза без обращения к GitHub.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_SCRIPT="$SCRIPT_DIR/release-plugin.sh"
ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT

MOCK_BIN="$ROOT/bin"
GH_LOG="$ROOT/gh.log"
GH_RELEASES="$ROOT/releases.txt"
mkdir -p "$MOCK_BIN"
touch "$GH_LOG" "$GH_RELEASES"

cat >"$MOCK_BIN/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${GH_LOG:?}"
if [[ "$1" == "release" && "$2" == "view" ]]; then
  if grep -qx "$3" "${GH_RELEASES:?}"; then
    exit 0
  fi
  exit 1
fi
if [[ "$1" == "release" && "$2" == "create" ]]; then
  exit 0
fi
echo "unexpected gh: $*" >&2
exit 1
EOF
chmod +x "$MOCK_BIN/gh"

export GH_LOG GH_RELEASES
export PATH="$MOCK_BIN:$PATH"
unset RELEASE_BEFORE_SHA

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_exit() {
  local expected="$1"
  shift
  set +e
  output="$("$@" 2>&1)"
  status=$?
  set -e
  if [[ "$status" -ne "$expected" ]]; then
    echo "$output" >&2
    fail "ожидался код $expected, получен $status: $*"
  fi
  printf '%s' "$output"
}

write_manifests() {
  local dir="$1"
  local version="$2"
  local market_version="${3:-$version}"
  local cursor_version="${4:-$version}"
  mkdir -p "$dir/.cursor-plugin"
  cat >"$dir/plugin.json" <<EOF
{
  "name": "ai-bro",
  "version": "$version",
  "repository": "https://github.com/example/ai-bro"
}
EOF
  cat >"$dir/.cursor-plugin/plugin.json" <<EOF
{
  "name": "ai-bro",
  "version": "$cursor_version"
}
EOF
  cat >"$dir/.cursor-plugin/marketplace.json" <<EOF
{
  "metadata": { "version": "$market_version" }
}
EOF
}

init_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q -b main
  git -C "$dir" config user.email "test@example.com"
  git -C "$dir" config user.name "release test"
}

commit_all() {
  local dir="$1"
  local message="$2"
  git -C "$dir" add -A
  git -C "$dir" commit -q -m "$message"
}

sha_of() {
  git -C "$1" rev-parse HEAD
}

reset_gh() {
  : >"$GH_LOG"
  : >"$GH_RELEASES"
}

echo "1. без предыдущего коммита push релиз не создаётся"
repo="$ROOT/no-before"
init_repo "$repo"
write_manifests "$repo" "1.0.0"
commit_all "$repo" "Первый коммит"
reset_gh
unset RELEASE_BEFORE_SHA
output="$(cd "$repo" && assert_exit 0 bash "$RELEASE_SCRIPT")"
[[ "$output" == *"нет предыдущего коммита"* ]] || fail "нет пропуска без before: $output"
[[ ! -s "$GH_LOG" ]] || fail "gh вызван без before: $(cat "$GH_LOG")"

echo "2. та же версия в push не выпускает релиз"
repo="$ROOT/same"
init_repo "$repo"
write_manifests "$repo" "1.0.0"
commit_all "$repo" "Начальная версия"
before="$(sha_of "$repo")"
echo "ещё" >>"$repo/README.md"
commit_all "$repo" "Поправить README"
reset_gh
output="$(cd "$repo" && RELEASE_BEFORE_SHA="$before" assert_exit 0 bash "$RELEASE_SCRIPT")"
[[ "$output" == *"не менялась"* ]] || fail "та же версия не пропущена: $output"
[[ ! -s "$GH_LOG" ]] || fail "gh вызван без смены версии: $(cat "$GH_LOG")"

echo "3. расхождение манифестов останавливает публикацию"
repo="$ROOT/mismatch"
init_repo "$repo"
write_manifests "$repo" "1.0.0"
commit_all "$repo" "Начальная версия"
before="$(sha_of "$repo")"
write_manifests "$repo" "1.1.0" "1.0.0" "1.1.0"
commit_all "$repo" "Разошлись версии"
reset_gh
output="$(cd "$repo" && RELEASE_BEFORE_SHA="$before" assert_exit 1 bash "$RELEASE_SCRIPT")"
[[ "$output" == *"расходятся"* ]] || fail "нет сообщения о расхождении: $output"
[[ "$GH_LOG" != *"release create"* ]] || fail "релиз создан при расхождении"

echo "4. смена версии без тега берёт только коммиты этого push"
repo="$ROOT/no-tag"
init_repo "$repo"
write_manifests "$repo" "1.0.0"
mkdir -p "$repo/skills/bro-old"
echo old >"$repo/skills/bro-old/SKILL.md"
commit_all "$repo" "Старый коммит"
before="$(sha_of "$repo")"
mkdir -p "$repo/skills/bro-do-it"
echo changed >"$repo/skills/bro-do-it/SKILL.md"
write_manifests "$repo" "1.1.0"
commit_all "$repo" "Поправить bro-do-it"
reset_gh
output="$(cd "$repo" && RELEASE_BEFORE_SHA="$before" assert_exit 0 bash "$RELEASE_SCRIPT")"
notes="${output#*RELEASE_NOTES_BEGIN}"
notes="${notes%RELEASE_NOTES_END*}"
[[ "$notes" == *"Поправить bro-do-it"* ]] || fail "нет коммита push: $notes"
[[ "$notes" != *"Старый коммит"* ]] || fail "в заметку попал коммит до push: $notes"
[[ "$notes" == *"bro-do-it"* ]] || fail "нет изменённого скилла: $notes"
grep -q '^release create 1.1.0 --target .* --title 1.1.0 --notes-file ' "$GH_LOG" || fail "gh release create вызван не так: $(cat "$GH_LOG")"

echo "5. предыдущий semver-тег задаёт диапазон, даже если в том коммите другой номер манифеста"
repo="$ROOT/tagged"
init_repo "$repo"
write_manifests "$repo" "0.9.0"
mkdir -p "$repo/skills/bro-old"
echo old >"$repo/skills/bro-old/SKILL.md"
commit_all "$repo" "Коммит под старым тегом"
git -C "$repo" tag 1.0.0
before="$(sha_of "$repo")"
mkdir -p "$repo/skills/bro-finish-it"
echo skill >"$repo/skills/bro-finish-it/SKILL.md"
commit_all "$repo" "Поправить bro-finish-it"
rm -rf "$repo/skills/bro-old"
write_manifests "$repo" "1.2.0"
commit_all "$repo" "Поднять версию"
reset_gh
output="$(cd "$repo" && RELEASE_BEFORE_SHA="$before" assert_exit 0 bash "$RELEASE_SCRIPT")"
notes="${output#*RELEASE_NOTES_BEGIN}"
notes="${notes%RELEASE_NOTES_END*}"
[[ "$notes" == *"Поправить bro-finish-it"* ]] || fail "нет промежуточного коммита: $notes"
[[ "$notes" == *"Поднять версию"* ]] || fail "нет коммита бампа: $notes"
[[ "$notes" != *"Коммит под старым тегом"* ]] || fail "в заметку попал коммит тега: $notes"
[[ "$notes" == *"bro-finish-it"* ]] || fail "нет изменённого скилла: $notes"
[[ "$notes" == *"bro-old (удалён)"* ]] || fail "нет удалённого скилла: $notes"
[[ "$notes" == *"/compare/1.0.0...1.2.0"* ]] || fail "диапазон взят не от тега: $notes"
grep -q '^release create 1.2.0 --target .* --title 1.2.0 --notes-file ' "$GH_LOG" || fail "gh release create вызван не так: $(cat "$GH_LOG")"

echo "6. уже существующий релиз не создаётся повторно"
echo "1.2.0" >"$GH_RELEASES"
: >"$GH_LOG"
output="$(cd "$repo" && RELEASE_BEFORE_SHA="$before" assert_exit 0 bash "$RELEASE_SCRIPT")"
[[ "$output" == *"уже есть"* ]] || fail "повтор не пропущен: $output"
[[ "$GH_LOG" != *"release create"* ]] || fail "повтор создал релиз"

echo "OK"
