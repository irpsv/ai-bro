# План реализации

Use this exact output shape for the markdown body of the final plan.
For Cursor `.plan.md` files, frontmatter is written once in the file header before this body and must not be repeated below.

```markdown
## Проблема и контекст
- ...

## Целевой результат
- ...

## Рамки задачи
### Входит в задачу
- ...

### Не входит в задачу
- ...

## Шаги реализации
### Шаг 1
- Где меняем:
- Что меняем:
- Зачем это делаем:

### Шаг 2
- Где меняем:
- Что меняем:
- Зачем это делаем:

## Критерии приемки
- ...
```

## Notes

- Do not emit this template if critical data is missing. Ask questions instead.
- For `.plan.md`, frontmatter belongs only in the file header, never in the body template below.
- Keep the exact section order.
- Add as many implementation steps as needed.
- Keep `todos` in sync with `Шаги реализации`.
- Do not leave `todos: []` if the plan contains implementation steps.
- Default new todo items to `status: pending`.
- Do not add `isProject`; Cursor decides it.
- Remove example placeholders in the final answer.
