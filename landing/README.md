# Лендинг ai-bro

Статический сайт для GitHub Pages.

## Стек

- HTML5 + CSS3 + небольшой vanilla JS (без сборки и фреймворков)
- Шрифты: Outfit, Source Serif 4 (Google Fonts)

GitHub Pages из ветки отдаёт только корень или `/docs`. Поэтому сайт лежит в `landing/`, а деплой идёт через Actions (`.github/workflows/pages.yml`).

## Локальный просмотр

```bash
# из корня репозитория
npx --yes serve landing
# или
python3 -m http.server 8080 --directory landing
```

## Публикация

1. В настройках репозитория: **Settings → Pages → Source → GitHub Actions**.
2. После мержа в `main` workflow задеплоит содержимое `landing/`.
