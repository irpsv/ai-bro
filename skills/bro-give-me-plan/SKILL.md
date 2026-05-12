---
name: bro-give-me-plan
description: Строит детальный план реализации с фиксированной структурой и без домыслов. Use when the user asks to составить план, сделать implementation plan, расписать шаги реализации, продумать план работ, или хочет единообразный план с секциями "Проблема и контекст", "Целевой результат", "Рамки задачи", шагами реализации и критериями приемки.
---

# Bro Give Me Plan

Use this skill when the user wants a consistent implementation plan, not immediate coding.

Read [plan-template.md](plan-template.md) before producing the final plan.
When the target output is a Cursor `.plan.md` file, include both the markdown body and the frontmatter metadata expected by plan files.
Frontmatter must appear exactly once at the very top of the file and must not be repeated inside the markdown body.

## Core Rules

1. Do not invent requirements, constraints, touched areas, or acceptance criteria.
2. If critical input is missing, ask the user concise clarifying questions and stop.
3. Ask exactly one question at a time.
   - This applies both to normal conversational questions and to `AskQuestion`.
   - Never send multiple independent questions in one turn.
4. Do not produce a draft plan with placeholders or assumptions unless the user explicitly overrides this rule.
5. Keep the plan detailed, but only from confirmed or directly verified information.
6. Prefer concrete modules, files, layers, APIs, or scenarios over abstract wording.
7. If the codebase was inspected, include only findings you can support.
8. If you emit a `.plan.md`, never leave `todos` empty when the plan has implementation steps.

## Planning Gate

Before writing the plan, verify that all of these are known with enough clarity:

- `Проблема и контекст`
- `Целевой результат`
- `Рамки задачи`
- enough information to describe `где и что меняем`
- enough information to explain `зачем это делаем`
- `Критерии приемки`

If any point is missing or ambiguous, do not write the plan yet.

## What To Ask When Blocked

Ask only for the missing essentials. Prefer a short grouped list over a broad interview.

Typical gaps:

- what exact problem is being solved
- what observable result is expected
- what is in scope and out of scope
- which module, layer, file group, or surface should change
- why a specific change is needed
- how the user wants to accept or verify the result

Bad questions:

- questions whose answer can be established from the current context or code
- speculative architecture debates with no evidence of a real trade-off
- broad discovery questions not tied to a missing section

## AskQuestion Usage

Use `AskQuestion` tool by default whenever the missing input can be expressed as a bounded choice with a small explicit set of options.
For bounded clarifications, `AskQuestion` is the required path, not an optional preference.

Good uses:

- confirm or correct an inferred scope boundary
- confirm or correct an inferred touched module, file group, or layer
- yes/no gates such as `Ready to plan`
- choose from a short list of explicit alternatives that are already known

Do not use `AskQuestion` for open-ended discovery that needs explanation, nuance, examples, business context, or detailed constraints.
For those cases, ask a normal conversational question.

If there are multiple blockers, ask the next highest-leverage question only.
Once that answer is resolved, ask the next one if still needed.

## Output Process

1. Check whether the planning gate is satisfied.
2. If not satisfied, ask the next blocking question.
   - If the missing input is bounded, use `AskQuestion`.
   - Only use a normal conversational question when the missing input is genuinely open-ended.
3. If satisfied, produce the final plan using [plan-template.md](plan-template.md).
4. Keep the final plan implementation-oriented and concrete.

## Plan File Metadata

When writing a Cursor `.plan.md` file, include frontmatter in this shape:

```yaml
---
name: short-kebab-case-name
overview: One concise sentence summarizing the plan.
todos:
  - id: stable-kebab-case-id
    content: Short actionable task description
    status: pending
---
```

Rules:

- `todos` must be populated from `Шаги реализации`, not left as `[]`.
- Create at least one todo for each implementation step.
- Use short stable `id` values in kebab-case.
- Write `content` as an actionable task, not as an essay.
- Default todo `status` to `pending` for a new plan unless the user explicitly asks for another state.
- Keep `overview` concise and aligned with `Целевой результат`.
- Do not add `isProject`; Cursor decides it.
- Preserve existing frontmatter fields if the plan file already contains them and they do not conflict with the user's request.
- Emit this frontmatter only once as the file header.
- After the closing `---`, start the markdown body immediately with the title or the first section.
- Never duplicate `name`, `overview`, or `todos` inside the markdown body.

## Section Rules

### Проблема и контекст

- State what is wrong or what needs to appear.
- Include only relevant background for understanding the task.
- Do not drift into solution details here.

### Целевой результат

- Describe the end state in observable terms.
- Prefer user-visible, API-visible, or system-visible outcomes.

### Рамки задачи

- Explicitly separate what is included from what is not.
- If the boundary is unclear, ask before planning.

### Шаги реализации

For each step, always include:

- `Где меняем`
- `Что меняем`
- `Зачем это делаем`

Rules for steps:

- Order steps in a practical execution sequence.
- Split large changes into separate steps.
- Do not mention areas you cannot justify.
- Do not collapse unrelated changes into one bullet.
- Mirror each implementation step into at least one frontmatter todo.
- Keep todo wording shorter than the corresponding step details.

### Критерии приемки

- Make them verifiable.
- Tie them to behavior, data, API responses, UI states, tests, or explicit checks.
- If verification method is unknown, ask before planning.

## Output Style

- Use the exact section order from the template.
- Keep wording concise, specific, and operational.
- Avoid filler, motivational text, and repeated caveats.
- Do not add extra sections unless the user explicitly asks for them.
