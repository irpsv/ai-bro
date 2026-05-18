---
name: bro-do-it
description: Оркестрирует реализацию через субагентов в двух режимах — по текущему контексту (direct) или по готовому плану / `.plan.md` / `todos` (plan). Use when the user asks to implement, fix, refactor, or complete work, OR to execute steps of an existing plan artifact.
---

# bro-do-it

Единственный entrypoint-скилл для **реализации** с делегированием `developer` → `reviewer`. Он только оркестрирует; детали режимов — в соседних файлах (один уровень вложенности).

## 1. Определи режим

| Режим | Когда |
|--------|--------|
| **`plan`** | Есть исполнение **готового** плана: `.plan.md`, `todos` из плана, «взять план в работу», продолжение существующего плана реализации |
| **`direct`** | Обычная задача из контекста **без** опоры на готовый артефакт плана |

Если пользователь смешивает запросы, приоритет у явного указания исполнить **существующий** план / `todos` → режим **`plan`**.

## 2. Открой workflow по режиму

- **`plan`** → [workflow-plan.md](workflow-plan.md)
- **`direct`** → [workflow-direct.md](workflow-direct.md)

## 3. Общее для обоих режимов

- Контракт `developer` / `reviewer`, передача контекста, ревью-цикл после первого `reviewer`: [shared-subagents.md](shared-subagents.md)
