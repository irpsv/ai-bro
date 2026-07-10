# Структура memory bank

Корень банка по умолчанию: `memory-bank/` в корне репозитория.

Маркер инициализированного банка: наличие `memory-bank/index.md` и каталогов `project/`, `features/`, `playbooks/`, `plans/`.

## Дерево каталогов

```
memory-bank/
  index.md
  project/
    overview.md
    tech-stack.md
    architecture.md
    conventions.md
    glossary.md
    decisions.md
  features/
    index.md
    <feature-id>.md
  playbooks/
    index.md
    <slug>.md
  plans/
    <feature-id>/
      plan.md
      stage-*.md
      deviations-*.md
```

## index.md (корень)

Справочник по разделам банка.

**Правила ссылок в корневом `index.md`:**
- **ДОПУСТИМО** ссылаться на `project/*.md`, `features/index.md`, `playbooks/index.md`;
- **ЗАПРЕЩЕНО** ссылаться на отдельные файлы в `features/`, `playbooks/`, `plans/`;
- **ЗАПРЕЩЕНО** ссылаться из `features/` на `plans/` — `plans/` временный раздел для артефактов планирования.

## project/

Долгоживущий контекст проекта. Один файл — одна тема.

| Файл | Содержимое |
|---|---|
| `overview.md` | Что за продукт, для кого, основная ценность |
| `tech-stack.md` | Языки, фреймворки, версии, БД, очереди, хостинг |
| `architecture.md` | Модули, границы, потоки данных, внешние интеграции |
| `conventions.md` | Код-стайл, ветки, PR, тесты, именование — нормы, не процедуры |
| `glossary.md` | Доменные термины и сокращения |
| `decisions.md` | Сквозные архитектурные решения на уровне проекта (хронологические записи с датой) |

## features/

Описания фич. Один файл на одну фичу: `features/<feature-id>.md`.

`features/index.md` — реестр фич: идентификатор, краткое название, статус, ссылка на файл.

**ЗАПРЕЩЕНО** создавать подкаталоги внутри `features/`.

## playbooks/

Типовые пошаговые процедуры. Один файл на одну процедуру: `playbooks/<slug>.md`.

`playbooks/index.md` — реестр: название, когда применять, ссылка на файл.

## plans/

Временные артефакты планирования. Управляются скиллом планирования, не скиллом пополнения знаний.

Артефакты плана **ДОЛЖНЫ** располагаться в следующей иерархии:

- `plans/<feature-id>/plan.md`
- `plans/<feature-id>/stage-*.md`
- `plans/<feature-id>/deviations-*.md`

`feature-id` в `plans/` **ДОЛЖЕН** совпадать с идентификатором соответствующей фичи в `features/`, если фича уже описана.

## Идентификаторы

- `feature-id` и `slug` — kebab-case, латиница, цифры, дефис;
- один `feature-id` везде одинаковый: `features/auth.md` и `plans/auth/plan.md`.
