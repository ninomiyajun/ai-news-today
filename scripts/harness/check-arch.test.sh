#!/usr/bin/env bash
# 依存の検査（check-arch.sh と .dependency-cruiser.cjs）のうち、モジュールのひな形（templates/）と src/ の間の依存を拒否する
# 2 つの規則（templates-not-to-src、src-not-to-templates）の試験。
# 手元と CI で同じコマンドを使う: npm run test:harness（lint-rules.test.mjs の後に動く）
#
# 一時ディレクトリに見本のリポジトリを作り、check-arch.sh、.dependency-cruiser.cjs、tsconfig.json の写しと、
# node_modules へのリンクを置いて、check-arch.sh の写しを動かす。見本のコードはこのファイルの中で作り、リポジトリには置かない
# （リポジトリのファイルを書き換えないため）。tsconfig.json は本物の写しなので、別名（@/...）の解決も本物と同じになる。
#
# この試験が守れない形（ARCHITECTURE.md の「層と責務」に、人が確かめる形として書いた）:
# - モジュールの名前を変数で組み立てた import() と require()（dependency-cruiser が依存として解決できない）。
# - vi.mock("@/...") や vi.importActual("@/...") のように、関数の引数の文字列で書いたパス（dependency-cruiser が依存として
#   数えない。三重スラッシュの reference path は依存として数えるので、検出する）。
# - ひな形を templates/ の外（別の名前のディレクトリ）に置く形。
# /bin/bash（macOS では 3.2）で動く書き方だけを使う。
set -euo pipefail
export LC_ALL=C
unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"

TMP_ROOT="$(mktemp -d)"
TMP_ROOT="$(cd "$TMP_ROOT" && pwd -P)"
trap 'rm -rf "$TMP_ROOT"' EXIT

passed=0
failed=0
case_no=0
SAMPLE=""
OUT=""
RC=0

BASIS="ARCHITECTURE.md の「層と責務」の templates/ の段落。この試験の由来は docs/harness-log.md。"

# 見本のリポジトリでは git init だけを行う（コミットしないので、フックは動かない）。check-arch.sh の git ls-files が、
# リポジトリの中で動く必要があるためである。
tgit() {
  git -c init.defaultBranch=main -c core.fsmonitor=false "$@"
}

# 新しい見本のリポジトリを作る。どの見本にも、規則に当たらない最小のファイル（src/domain/ の型と、ひな形の 1 ファイル）を置く。
new_sample() {
  case_no=$((case_no + 1))
  SAMPLE="$TMP_ROOT/sample-$case_no"
  mkdir -p "$SAMPLE/scripts/harness" "$SAMPLE/src/domain" "$SAMPLE/src/ui" "$SAMPLE/templates/module"
  cp "$ROOT/scripts/harness/check-arch.sh" "$SAMPLE/scripts/harness/check-arch.sh"
  cp "$ROOT/.dependency-cruiser.cjs" "$SAMPLE/.dependency-cruiser.cjs"
  cp "$ROOT/tsconfig.json" "$SAMPLE/tsconfig.json"
  ln -s "$ROOT/node_modules" "$SAMPLE/node_modules"
  printf '%s\n' 'export type News = { id: string };' 'export const SAMPLE_ID = "a";' > "$SAMPLE/src/domain/news.ts"
  printf '%s\n' 'export const label = "見本";' > "$SAMPLE/templates/module/Example.ts"
  tgit -C "$SAMPLE" init -q
}

# 見本のファイルを書く（引数: リポジトリの根からの相対のパス、中身の各行）
put() {
  local p="$1"
  shift
  mkdir -p "$(dirname "$SAMPLE/$p")"
  printf '%s\n' "$@" > "$SAMPLE/$p"
}

run_check() {
  RC=0
  OUT="$(bash "$SAMPLE/scripts/harness/check-arch.sh" 2>&1)" || RC=$?
}

ok() {
  passed=$((passed + 1))
  echo "ok: $1"
}

ng() {
  failed=$((failed + 1))
  printf 'NG: %s\n  何が違反か: %s\n  どう直すか: %s\n  根拠: %s\n  検査の出力:\n%s\n' "$1" "$2" "$3" "$BASIS" "$OUT" >&2
}

# 失敗する見本: 検査が失敗し、出力に、規則の名前と、規則の comment（違反、直し方、根拠の文書）があること。
# err-long の出力は空白の位置で折り返すので、「直し方:」の後ろの空白は照合しない。
expect_fail() {
  local name="$1" rule="$2"
  run_check
  if [ "$RC" -ne 0 ] && printf '%s' "$OUT" | grep -q "error $rule: " && printf '%s' "$OUT" | grep -q "直し方:" &&
    printf '%s' "$OUT" | grep -q "ARCHITECTURE.md"; then
    ok "$name"
  else
    ng "$name" "依存の検査が、規則 $rule の違反を見逃したか、出力に規則の名前、直し方、根拠の文書のどれかが無い（終了コード $RC）。" \
      ".dependency-cruiser.cjs の $rule の規則（from と to のパス、comment）と、check-arch.sh の最後の行の対象（src templates）を見直す。"
  fi
}

# 通る見本: 検査が通ること
expect_pass() {
  local name="$1"
  run_check
  if [ "$RC" -eq 0 ]; then
    ok "$name"
  else
    ng "$name" "規則に当たらないはずの依存を、検査が失敗にした（終了コード $RC）。" \
      ".dependency-cruiser.cjs の templates-not-to-src と src-not-to-templates の規則の from と to のパスが、広すぎないかを見直す。"
  fi
}

# --- 通る見本
new_sample
put src/ui/Uses.ts 'import type { News } from "@/domain/news";' 'export const f = (n: News) => n.id;'
put templates/module/Uses.ts 'import { label } from "./Example";' 'export const g = () => label;'
expect_pass "通る見本 1: src/ の中の別名（@/...）での import と、ひな形の中どうしの import は通る"

# --- 失敗する見本（templates/ から src/ への向き。元の指摘の形。技術的負債の TD-2）
# どれも、src/ の下から import されないひな形のファイルなので、check-arch.sh の対象に templates が無いと見逃す。
new_sample
put templates/module/Bad.ts 'import { SAMPLE_ID } from "@/domain/news";' 'export const h = () => SAMPLE_ID;'
expect_fail "失敗する見本 1: ひな形が、別名（@/...）で src/ を import する" "templates-not-to-src"

new_sample
put templates/module/Bad.ts 'import type { News } from "@/domain/news";' 'export const h = (n: News) => n.id;'
expect_fail "失敗する見本 2: ひな形が、型だけの import で、別名（@/...）で src/ を import する" "templates-not-to-src"

new_sample
put templates/module/Bad.ts 'import { SAMPLE_ID } from "../../src/domain/news";' 'export const h = () => SAMPLE_ID;'
expect_fail "失敗する見本 3: ひな形が、相対のパスで src/ を import する" "templates-not-to-src"

# --- 失敗する見本（src/ から templates/ への向き）
new_sample
put src/ui/Bad.ts 'import { label } from "../../templates/module/Example";' 'export const h = () => label;'
expect_fail "失敗する見本 4: src/ の下のコードが、相対のパスでひな形を import する" "src-not-to-templates"

new_sample
put src/ui/Bad.ts 'export const h = () => import("../../templates/module/Example");'
expect_fail "失敗する見本 5: src/ の下のコードが、import() でひな形を読み込む" "src-not-to-templates"

# --- 試験そのものの試験: 規則を入れる前の形（元の指摘の形）を見本の写しの中で再現すると、違反を見逃すこと。
# 上の失敗する見本が、足した規則と check-arch.sh の対象の templates によって失敗していることを確かめる。
# 書き換えるのは見本の写しだけで、リポジトリのファイルは書き換えない。

# 期待: 検査が通ってしまう（違反を見逃す）こと
expect_missed() {
  local name="$1"
  run_check
  if [ "$RC" -eq 0 ]; then
    ok "$name"
  else
    ng "$name" "規則を入れる前の形を再現したのに、検査が失敗した（終了コード $RC）。上の失敗する見本が、足した規則以外の理由で失敗している恐れがある。" \
      "この試験の見本のコード（put で書く中身）が、ほかの規則（層の向き、解決できない import など）に当たっていないかを見直す。"
  fi
}

new_sample
put templates/module/Bad.ts 'import { SAMPLE_ID } from "@/domain/news";' 'export const h = () => SAMPLE_ID;'
put .dependency-cruiser.cjs \
  'const base = require("./dependency-cruiser.base.cjs");' \
  'const drop = ["templates-not-to-src", "src-not-to-templates"];' \
  'module.exports = { ...base, forbidden: base.forbidden.filter((r) => !drop.includes(r.name)) };'
cp "$ROOT/.dependency-cruiser.cjs" "$SAMPLE/dependency-cruiser.base.cjs"
expect_missed "元の形の再現 1: 2 つの規則が無いと、失敗する見本 1 の形（ひな形から別名で src/ を import）を見逃す"

# 再現 2 は、check-arch.sh の depcruise の行を、対象から templates を除いた行に差し替える。差し替える行の形が変わったら、
# 再現ができないので、先に形を確かめる。
DEPCRUISE_LINE='npx --no-install depcruise --config .dependency-cruiser.cjs --output-type err-long src templates'
if [ "$(grep -c '^npx --no-install depcruise ' "$ROOT/scripts/harness/check-arch.sh")" = "1" ] &&
  grep -qxF "$DEPCRUISE_LINE" "$ROOT/scripts/harness/check-arch.sh"; then
  ok "check-arch.sh の depcruise の行が 1 行だけで、対象が src と templates である"
else
  OUT="$(grep -n 'depcruise' "$ROOT/scripts/harness/check-arch.sh" || true)"
  ng "check-arch.sh の depcruise の行が 1 行だけで、対象が src と templates である" \
    "check-arch.sh の depcruise の行が、この試験の見込み（$DEPCRUISE_LINE）と違う。" \
    "対象に templates を残す。行の形を変えたときは、この試験の DEPCRUISE_LINE と、元の形の再現 2 の差し替えを合わせて直す。"
fi

new_sample
put templates/module/Bad.ts 'import { SAMPLE_ID } from "@/domain/news";' 'export const h = () => SAMPLE_ID;'
grep -v '^npx --no-install depcruise ' "$ROOT/scripts/harness/check-arch.sh" > "$SAMPLE/scripts/harness/check-arch.sh"
printf '%s\n' 'npx --no-install depcruise --config .dependency-cruiser.cjs --output-type err-long src' >> "$SAMPLE/scripts/harness/check-arch.sh"
expect_missed "元の形の再現 2: check-arch.sh の対象に templates が無いと、src/ から import されないひな形の違反を見逃す"

total=$((passed + failed))
if [ "$failed" -gt 0 ]; then
  echo "check-arch.test: $total 件中 $failed 件が期待と違います" >&2
  exit 1
fi
echo "check-arch.test: $total 件中 $total 件が期待どおり"
