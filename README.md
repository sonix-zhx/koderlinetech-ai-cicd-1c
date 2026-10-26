# ИИ-агент в CI/CD 1С

Демо к докладу «Как встроить ИИ в CI/CD в 1С» (Koderline Tech). ИИ-агент ([OpenCode](https://opencode.ai) CLI) работает в GitHub Actions поверх обычного CI/CD 1С: смотрит изменения в PR, разбирает отчёт BSL Language Server, пишет release notes и правит код по команде. На Jenkins и GitLab CI то же самое, меняется только обвязка: триггеры, права, публикация результата.

В `src/` лежит небольшая конфигурация 1С в формате выгрузки EDT: продажи, контрагенты, интеграция с сайтом, документ «Реализация товаров».

## Четыре сценария

| Сценарий | Триггер | Что делает агент | Результат | Права агента |
|---|---|---|---|---|
| ИИ-ревью ([`ai-review.yml`](.github/workflows/ai-review.yml)) | `pull_request` с изменением `.bsl` | Получает diff по `.bsl` и правила из [`review.md`](.github/prompts/review.md), оценивает код | Комментарий в PR и вердикт `PASS` или `FAIL`; при `FAIL` проверка красная. Примеры: [PR #1](https://github.com/sonix-zhx/koderlinetech-ai-cicd-1c/pull/1) (FAIL), [PR #2](https://github.com/sonix-zhx/koderlinetech-ai-cicd-1c/pull/2) (PASS) | Только текст: чтение файлов, правка, shell и веб запрещены |
| Разбор BSL LS ([`ai-sonar.yml`](.github/workflows/ai-sonar.yml)) | `pull_request` с изменением `.bsl` | BSL Language Server строит отчёт, `jq` оставляет замечания по изменённым файлам, агент группирует их и предлагает исправления | Комментарий в PR без статуса. Пример: [PR #3](https://github.com/sonix-zhx/koderlinetech-ai-cicd-1c/pull/3) | Только текст, всё нужное уже в сообщении |
| Release notes ([`ai-release-notes.yml`](.github/workflows/ai-release-notes.yml)) | Push тега `v*` | Сам читает коммиты между тегами (`git log`, `git show` для неинформативных сообщений «правки», «fix») | GitHub Release и коммит в `CHANGELOG.md`. Пример: [v1.1.0](https://github.com/sonix-zhx/koderlinetech-ai-cicd-1c/releases/tag/v1.1.0) | Только git на чтение; `contents: write` у job для релиза и коммита |
| Команда `/opencode` ([`ai-command.yml`](.github/workflows/ai-command.yml)) | Комментарий `/opencode ...` или `/oc ...` в PR от автора PR или из списка `OPENCODE_OWNERS` | Готовая интеграция OpenCode правит код по просьбе в комментарии | Коммит в ветку PR от `opencode-agent[bot]`, ревью запускается повторно. Пример: [PR #4](https://github.com/sonix-zhx/koderlinetech-ai-cicd-1c/pull/4) | Правка кода и коммит в ветку PR через GitHub App |

В `ai-sonar.yml` отчёт строится на лету. С живым SonarQube его берут через API (`/api/issues/search?pullRequest=<номер>`), остальные шаги те же.

## Структура репозитория

```
.github/
  workflows/     четыре сценария (ai-review, ai-sonar, ai-release-notes, ai-command)
  prompts/       промпты агента: review.md, sonar.md, release-notes.md
  scripts/       clean-output.sh (чистка вывода агента), post-comment.sh (комментарий в PR)
  actions/
    setup-opencode/   установка Node.js, OpenCode CLI и чтение модели из opencode.json
src/             конфигурация 1С в формате EDT
AGENTS.md        правила для агента: BSL и 1С
opencode.json    модель агента
.bsl-language-server.json   настройки BSL Language Server
CHANGELOG.md     журнал изменений, дописывается workflow релиза
```

## Как повторить у себя

1. Скопируйте в свой репозиторий `.github/`, `opencode.json` и `AGENTS.md`. Правила в `AGENTS.md` и промпты в `.github/prompts/` подправьте под свои стандарты.
2. Модель задаётся в одном месте: поле `model` в `opencode.json` (сейчас `opencode/deepseek-v4.1-flash-free`).
3. Бесплатные модели [OpenCode Zen](https://opencode.ai/docs/zen) работают без ключа. Для своей модели добавьте секрет `OPENCODE_API_KEY` (Settings, Secrets and variables, Actions) и укажите модель в `opencode.json`.
4. Для `/opencode` установите GitHub App [OpenCode](https://github.com/apps/opencode-agent) на репозиторий. Рядом включите Settings, Actions, General, Workflow permissions: Read and write.
5. Список тех, кто кроме автора PR может давать команды: `OPENCODE_OWNERS` в `ai-command.yml`.

## Грабли

- `opencode run` выходит с кодом 0 даже при ошибке: проверяйте сам ответ (в ревью ищется строка `## Итог`).
- Бесплатная модель иногда отвечает пусто или долго: тайм-аут и одна повторная попытка, параллельные запросы не гонять (в workflow для этого `concurrency` на PR).
- Агент без явного входа и прав начинает рыться в `.git` и в вебе: передавайте всё нужное в сообщении и запрещайте лишнее через `OPENCODE_PERMISSION`.
- Push через `GITHUB_TOKEN` не перезапускает workflow, а коммит от App OpenCode перезапускает: поэтому после правок агента ревью идёт заново.
- `.gitignore` без `/` в начале может съесть файл промпта: `review.md` в корне и `.github/prompts/review.md` для него одно и то же. Для временных файлов пишите `/review.md`.

## Данные

Бесплатные модели Zen доступны «на ограниченное время», а условия хранения данных у разных моделей разные. Для рабочего кода выбирайте модель с понятными условиями и не отправляйте в бесплатную то, что нельзя выносить за периметр компании.
