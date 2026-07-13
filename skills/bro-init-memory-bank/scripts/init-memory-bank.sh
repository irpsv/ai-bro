#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-memory-bank}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="${SCRIPT_DIR}/../templates"

if [[ -e "${TARGET}/index.md" ]]; then
  echo "Ошибка: memory bank уже существует (${TARGET}/index.md найден)." >&2
  exit 1
fi

if [[ ! -d "${TEMPLATES_DIR}" ]]; then
  echo "Ошибка: каталог шаблонов не найден: ${TEMPLATES_DIR}" >&2
  exit 1
fi

mkdir -p "${TARGET}/project" "${TARGET}/features" "${TARGET}/playbooks" "${TARGET}/plans"

cp "${TEMPLATES_DIR}/index.md" "${TARGET}/index.md"
cp "${TEMPLATES_DIR}/project/"*.md "${TARGET}/project/"
cp "${TEMPLATES_DIR}/features/index.md" "${TARGET}/features/index.md"
cp "${TEMPLATES_DIR}/playbooks/index.md" "${TARGET}/playbooks/index.md"

echo "Memory bank создан: ${TARGET}/"
