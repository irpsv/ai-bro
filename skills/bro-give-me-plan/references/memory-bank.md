# Memory bank

Корень банка: `memory-bank/` в корне репозитория (если человек не указал иное).

Маркер инициализированного банка: `memory-bank/index.md`.

Перед размещением артефактов **ПРОВЕРЬ** наличие банка. Если `memory-bank/index.md` отсутствует — **СООБЩИ** человеку, что нужна инициализация через `/bro-init-memory-bank`, и **ДОЖДИСЬ** решения.

## plans/

Артефакты плана **ДОЛЖНЫ** располагаться в следующей иерархии внутри memory bank:

- `plans/<feature-id>/plan.md`
- `plans/<feature-id>/stage-*.md`
- `plans/<feature-id>/deviations-*.md`

`feature-id` — kebab-case, латиница, цифры, дефис. Если фича описана в `features/<feature-id>.md`, идентификатор **ДОЛЖЕН** совпадать.
