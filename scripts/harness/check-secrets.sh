#!/usr/bin/env bash
# 秘匿値の検査の入口。本体は scripts/harness/check-secrets.mjs（調べる範囲と失敗にする条件はその冒頭）。
#   npm run check:secrets        作業ツリーの全ファイル（追跡済みと、.gitignore で除外していない未追跡）
#   npm run check:secrets:push   push する範囲の各コミットに記録された中身とメッセージ（git fetch --prune origin の後に実行する）
# CI は本体を node で直接呼ぶ（npm の pre と post のスクリプトを動かさないため）。道具の選択と限界は docs/adr/0002-secret-scan-scope.md。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
exec node "$ROOT/scripts/harness/check-secrets.mjs" "$@"
