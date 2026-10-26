#!/usr/bin/env bash
# Создаёт или обновляет комментарий в PR (по скрытому маркеру), чтобы не плодить копии.
# Использование: post-comment.sh <маркер> <файл-с-текстом>
# Окружение: GH_TOKEN, PR_NUMBER, GITHUB_REPOSITORY
set -euo pipefail

marker="<!-- $1 -->"
body=$(mktemp)
{ echo "$marker"; cat "$2"; } > "$body"

api="repos/$GITHUB_REPOSITORY/issues"
id=$(gh api --paginate "$api/$PR_NUMBER/comments" \
  --jq ".[] | select(.body | startswith(\"$marker\")) | .id" | sed -n 1p)

if [ -n "$id" ]; then
  gh api -X PATCH "$api/comments/$id" -F body=@"$body" > /dev/null
else
  gh api "$api/$PR_NUMBER/comments" -F body=@"$body" > /dev/null
fi
