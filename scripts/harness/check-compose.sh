#!/usr/bin/env bash
# harness-copy: source=home/agents/skills/project-harness-init/assets/parts/node-compose/assets/check-compose.sh
# harness-copy: version=rules-2026.11.13-1
# harness-copy: sha256=d0a9b559b9b422651f9ffc3152d5355892fb4780859f559bf99e1d40b2a607c1
# harness-copy: この 4 行と本体は手で変えない。正本を直して project-harness-init の「導入済みのプロジェクトの更新」で置き換える
# アプリの開発環境の定義（compose.yaml・compose.override.yaml・Dockerfile）の静的な検査の入口。
#
#   bash scripts/harness/check-compose.sh [--root <根>]
#
# 本体は同じ置き場の check-compose.mjs で、プロジェクトの Node（PATH の上の node）で動き、YAML をプロジェクトの
# devDependencies の yaml（根の node_modules/yaml。版 2.9.1）で読む。docker の CLI と Docker の daemon は使わない。
# --root を省くと、このファイルの 2 つ上（scripts/harness/ の上）をリポジトリの根とする。
# 終了コード: 0 = 合格 / 1 = 不合格（理由を標準エラーへ 1 行ずつ）/ 2 = 使い方の誤りや道具の不足
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
root="$(cd "$here/../.." && pwd -P)"
toolroot="$root"
while [ $# -gt 0 ]; do
  case "$1" in
    --root)
      [ $# -ge 2 ] || { echo "check-compose: --root の値がありません" >&2; exit 2; }
      [ -d "$2" ] || { echo "check-compose: --root がディレクトリではありません: $2" >&2; exit 2; }
      root="$(cd "$2" && pwd -P)"; shift 2 ;;
    *) echo "使い方: bash scripts/harness/check-compose.sh [--root <根>]（知らない引数: ${1}）" >&2; exit 2 ;;
  esac
done

command -v node > /dev/null 2>&1 || { echo "check-compose: node がありません（プロジェクトの .nvmrc の版の Node を入れてください）" >&2; exit 2; }
# yaml はこのファイルの 2 つ上（道具の根。--root によらない）の node_modules/yaml だけから読む（上のディレクトリの node_modules へは探しに行かない）。実体のパスと版
# （2.9.1）は本体が確かめ、合わなければ終了コード 2 で終える
if [ ! -f "$toolroot/node_modules/yaml/package.json" ]; then
  echo "check-compose: yaml のパッケージがありません（根の node_modules/yaml。npm ci で devDependencies を入れてください）" >&2
  exit 2
fi

rc=0
node "$here/check-compose.mjs" "$root" "$toolroot" || rc=$?
case "$rc" in
  0|1|2) exit "$rc" ;;
  *) echo "check-compose: 本体が終了コード ${rc} で終わりました" >&2; exit 2 ;;
esac
