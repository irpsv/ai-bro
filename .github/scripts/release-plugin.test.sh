#!/usr/bin/env bash
# Проверяет границы автоматического релиза без обращения к GitHub.
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

reset_gh() {
  : >"$GH_LOG"
  : >"$GH_RELEASES"
}

echo "1. версии 1.11.0 не выпускают релиз"
repo="$ROOT/current"
init_repo "$repo"
write_manifests "$repo" "1.11.0"
mkdir -p "$repo/skills/bro-think-with-me"
echo skill >"$repo/skills/bro-think-with-me/SKILL.md"
commit_all "$repo" "Текущее состояние"
reset_gh
output="$(cd "$repo" && assert_exit 0 bash "$RELEASE_SCRIPT")"
[[ "$output" == *"не новее 2.0.0"* ]] || fail "нет сообщения о пропуске: $output"
[[ ! -s "$GH_LOG" ]] || fail "gh вызван для 1.11.0: $(cat "$GH_LOG")"

echo "2. расхождение манифестов останавливает публикацию"
repo="$ROOT/mismatch"
init_repo "$repo"
write_manifests "$repo" "2.1.0" "2.1.0" "2.0.0"
commit_all "$repo" "Разошлись версии"
reset_gh
output="$(cd "$repo" && assert_exit 1 bash "$RELEASE_SCRIPT")"
[[ "$output" == *"расходятся"* ]] || fail "нет сообщения о расхождении: $output"
[[ ! -s "$GH_LOG" ]] || fail "gh вызван при расхождении"

echo "3. ровно 2.0.0 остаётся ручным релизом"
repo="$ROOT/baseline"
init_repo "$repo"
write_manifests "$repo" "2.0.0"
commit_all "$repo" "Поднять версию до 2.0.0"
reset_gh
output="$(cd "$repo" && assert_exit 0 bash "$RELEASE_SCRIPT")"
[[ "$output" == *"публикуется вручную"* ]] || fail "2.0.0 не оставлен ручным: $output"
[[ ! -s "$GH_LOG" ]] || fail "gh вызван для 2.0.0"

echo "4. версия новее 2.0.0 без ручного релиза не публикуется"
repo="$ROOT/missing-baseline"
init_repo "$repo"
write_manifests "$repo" "2.0.0"
commit_all "$repo" "База"
git -C "$repo" tag 2.0.0
write_manifests "$repo" "2.1.0"
commit_all "$repo" "Поднять версию до 2.1.0"
reset_gh
output="$(cd "$repo" && assert_exit 1 bash "$RELEASE_SCRIPT")"
[[ "$output" == *"нет релиза 2.0.0"* ]] || fail "нет требования ручного релиза: $output"
[[ "$GH_LOG" != *"release create"* ]] || fail "релиз создан без базы 2.0.0"

echo "5. тег 2.0.0 не на коммите этой версии останавливает публикацию"
repo="$ROOT/wrong-tag"
init_repo "$repo"
write_manifests "$repo" "1.11.0"
commit_all "$repo" "Старая версия"
git -C "$repo" tag 2.0.0
write_manifests "$repo" "2.1.0"
mkdir -p "$repo/skills/bro-do-it"
echo skill >"$repo/skills/bro-do-it/SKILL.md"
commit_all "$repo" "Поднять версию до 2.1.0"
reset_gh
echo "2.0.0" >"$GH_RELEASES"
output="$(cd "$repo" && assert_exit 1 bash "$RELEASE_SCRIPT")"
[[ "$output" == *"указывает на коммит"* ]] || fail "плохой тег не пойман: $output"
[[ "$GH_LOG" != *"release create"* ]] || fail "релиз создан от плохого тега"

echo "6. после 2.0.0 релиз собирается только из новых коммитов и скиллов"
repo="$ROOT/auto"
init_repo "$repo"
write_manifests "$repo" "2.0.0"
mkdir -p "$repo/skills/bro-old"
echo old >"$repo/skills/bro-old/SKILL.md"
commit_all "$repo" "Базовая версия"
git -C "$repo" tag 2.0.0
mkdir -p "$repo/skills/bro-do-it"
echo changed >"$repo/skills/bro-do-it/SKILL.md"
commit_all "$repo" "Поправить bro-do-it"
rm -rf "$repo/skills/bro-old"
write_manifests "$repo" "2.1.0"
commit_all "$repo" "Поднять версию до 2.1.0"
reset_gh
echo "2.0.0" >"$GH_RELEASES"
output="$(cd "$repo" && assert_exit 0 bash "$RELEASE_SCRIPT")"
notes="${output#*RELEASE_NOTES_BEGIN}"
notes="${notes%RELEASE_NOTES_END*}"
[[ "$notes" == *"Поправить bro-do-it"* ]] || fail "нет промежуточного коммита: $notes"
[[ "$notes" == *"Поднять версию до 2.1.0"* ]] || fail "нет коммита бампа: $notes"
[[ "$notes" != *"Базовая версия"* ]] || fail "в заметку попал коммит базового релиза: $notes"
[[ "$notes" == *"bro-do-it"* ]] || fail "нет изменённого скилла: $notes"
[[ "$notes" == *"bro-old (удалён)"* ]] || fail "нет удалённого скилла: $notes"
[[ "$notes" == *"/compare/2.0.0...2.1.0"* ]] || fail "нет ссылки на диапазон: $notes"
[[ "$notes" == *"/tree/2.1.0/skills/bro-do-it"* ]] || fail "ссылка скилла не на тег релиза: $notes"
grep -q '^release create 2.1.0 --target .* --title 2.1.0 --notes-file ' "$GH_LOG" || fail "gh release create вызван не так: $(cat "$GH_LOG")"

echo "7. повторный запуск не создаёт второй релиз"
echo "2.1.0" >>"$GH_RELEASES"
: >"$GH_LOG"
output="$(cd "$repo" && assert_exit 0 bash "$RELEASE_SCRIPT")"
[[ "$output" == *"уже есть"* ]] || fail "повтор не пропущен: $output"
[[ "$GH_LOG" != *"release create"* ]] || fail "повтор создал релиз"

echo "OK"
