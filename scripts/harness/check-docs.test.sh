#!/usr/bin/env bash
# check-docs.sh の試験（検査 7 の一部、検査 8、検査 9: 受け入れ確認の記録、検査 10: 製品の仕様、検査 11: 古い計画、
# 検査 12: 文書の検査の一覧、検査 13: 通信の名前の一覧、検査 14: 層の評価の上限）。手元と CI で同じコマンドを使う:
# npm run test:harness
#
# 検査 12 が受け持てない形（レビューで人が確かめる）:
# - check-docs.sh に検査の処理を足したのに、冒頭の「確かめること」にも CHECK_NAMES にも足さない形（検査 12 は、冒頭の一覧と
#   CHECK_NAMES の数を突き合わせるだけで、処理の数は数えない）
# - 名前が検査の中身を正しく言い表しているか、と、ほかの文書に書いた検査の一覧（いまは無い）
#
# 検査 13 の読み取りの前提と、受け持てない形:
# - 前提: ARCHITECTURE.md の不変条件 2 は「（`http`、…、`dgram` と、それぞれに `node:` を付けた名前、`undici`）」の形で、
#   「と、それぞれに `node:` を付けた名前、」の前の名前を node: 付きと無しに展開し、後の名前をそのまま足して読む。不変条件 1 は
#   「通信のための大域の名前（`fetch`、…、`EventSource`。」の形で読む。eslint.config.mjs は、NETWORK_MODULE_BASES と
#   NETWORK_GLOBALS が「const 名前 = [ "…", … ];」の 1 行、NETWORK_MODULES が flatMap で node: 付きと無しに展開して末尾に
#   名前を足す 1 行である形で読む。書き方を変えると、黙って通らずに失敗する（下の 2 つの場合で確かめる）。不変条件の
#   折り返しの位置が空白に来ても読める（下の通る場合で確かめる）が、語の途中で折り返すと前提の崩れとして失敗する
# - ほかの文書の通信の名前（docs/QUALITY_SCORE.md の「http、https、net など」の一部の列挙）は比べない
# - scripts/harness/lint-rules.test.mjs の注釈の「通信のためのモジュール 13 個」の数と見本の選び方は確かめない
#   （名前を増やしたときは、その注釈をレビューで人が直す）
# - 定数の名前の一覧が、規則（no-restricted-imports など）で実際に使われているかは確かめない（lint-rules.test.mjs の見本が一部を守る）
# - 宣言の後で定数の配列を書き換える形（NETWORK_MODULES.push("ws") など）は確かめない（宣言の行だけを読むため。書き換えで
#   足した名前は、ARCHITECTURE.md に無くても通る）
#
# 検査 14 が受け持てない形（レビューで人が確かめる）:
# - 人が確かめる決まりの数そのものが正しいか（docs/QUALITY_SCORE.md の決まり 1〜4 の対象と、層ごとの数が合っているか）は
#   確かめない。数を 0 と書けば A にできるので、数を直す変更はレビューで人が確かめる
# - 表 1（領域ごと）の評価と、評価と根拠の文章が合っているかは確かめない
# - セルの中に「\|」（表の区切りでない縦線）を書くと、列の数が見出しと合わず、前提の崩れとして失敗する（誤検知だが、
#   すり抜けではなく失敗する側に倒れる。scripts/harness/drift-scan.sh も同じく列の数の違いとして扱う）
#
# 場合ごとに、一時ディレクトリに小さなリポジトリ（git init だけ。コミットはしない）を作り、check-docs.sh の写しと
# 本物の docs/PLANS.md の写し（検査 10 の場合は本物の docs/product-specs/README.md の写しも）を置いて、計画・記録・仕様の
# 組を変えて動かす。終了コードと、失敗のときは理由の文言を確かめる。
# 計画・記録・仕様の見本はこのファイルの中で作り、リポジトリに Markdown の見本を置かない（検査 4、8、10 が見本を拾うため）。
# 仕様の見本の題材は、アプリの実際の機能と関係の無い架空の機能（一覧の文字の大きさの切り替え）にする。
#
# 検査は、どの場合でも、基準の日（check-docs.sh の HARNESS_TODAY）を決まった日にして呼ぶ（run_case の 1 か所）。検査 11 が
# 基準の日を見るので、渡さないと、試験を実行した日によって結果が変わるためである。基準の日を付けない呼び出しを足さない。
set -euo pipefail
export LC_ALL=C

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHECK="$ROOT/scripts/harness/check-docs.sh"
PLANS="$ROOT/docs/PLANS.md"
SPECS_README="$ROOT/docs/product-specs/README.md"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

# 新しい書式の適用開始の日付を、本物の docs/PLANS.md から読む（日付を試験に二重に持たないため）
START="$(sed -n 's/^新しい書式の適用開始: \([0-9-]*\)$/\1/p' "$PLANS" | head -n 1)"
if [ -z "$START" ]; then
  echo "check-docs.test: NG: $PLANS から「新しい書式の適用開始」の日付を読み取れません" >&2
  exit 1
fi
NEW="$START-score-filter"   # 新しい書式の計画の名前（適用開始の当日）
OLD="2000-01-01-old-plan"   # 旧い書式の計画の名前

# 検査に渡す基準の日の既定（適用開始の日）。環境変数 HARNESS_TEST_TODAY（YYYY-MM-DD）は、この既定を別の日に替える上書きで、
# 検査 11 の場合を除く結果が基準の日に左右されないことを確かめるときに使う（検査 11 の場合は、自分で基準の日を指定する）
BASE_TODAY="${HARNESS_TEST_TODAY:-$START}"
CASE_TODAY=""   # 場合ごとの基準の日（run_case_on が指定する。空なら BASE_TODAY）

passed=0
failed=0

# 検査 12 の対象の行。本物の AGENTS.md の check:docs の行と、本物の docs/QUALITY_SCORE.md の目標「文書が実物と合っている」の
# 行を写して使う（名前の一覧を試験に二重に持たないため）
AGENTS_DOCS_ROW="$(awk '/^## /{ on = ($0 == "## 検査のコマンド"); next } on && index($0, "| `npm run check:docs` |")' "$ROOT/AGENTS.md")"
QUALITY_DOCS_ROW="$(awk '/^## /{ on = ($0 == "## 目標"); next } on && index($0, "| 文書が実物と合っている |") == 1' "$ROOT/docs/QUALITY_SCORE.md")"
if [ -z "$AGENTS_DOCS_ROW" ] || [ -z "$QUALITY_DOCS_ROW" ]; then
  echo "check-docs.test: NG: 本物の AGENTS.md か docs/QUALITY_SCORE.md から、検査 12 の対象の行を読み取れません" >&2
  exit 1
fi

# 検査 13 を通る最小の不変条件と ESLint の設定（名前は 1 つずつ。読み取りの形は本物と同じ）
MIN_INVARIANTS='## 不変条件

1. 通信のための大域の名前（`fetch`。試験の見本）は、決まった層の外で使わない。
2. 通信のためのモジュール（`http` と、それぞれに `node:` を付けた名前、`undici`）は、決まった層の外で import しない。'
MIN_NET_CONSTS='const NETWORK_MODULE_BASES = ["http"];
const NETWORK_MODULES = [...NETWORK_MODULE_BASES.flatMap((m) => [`node:${m}`, m]), "undici"];
const NETWORK_GLOBALS = ["fetch"];'

# 検査 14 を通る最小の表 2（層は 1 つ。見出しの行は本物と同じ）
MIN_RATINGS='## 現在の評価

| 層 | 評価 | 検査の識別子 | 人が確かめる決まりの数 | 根拠 | 評価した日 | 評価したコミット |
|---|---|---|---|---|---|---|
| `src/app/` | B | `lint` | 1 | 試験の見本 | 2026-10-16 | c4b6083 |'

# AGENTS.md を書く。$1 = リポジトリ、$2 = 「## 検査のコマンド」の表の行。検査のコマンドの節は地図より前に置く
# （地図の節が最後にあれば、末尾に足した行が地図の表の行になるため）
write_agents() {
  printf '%s\n' "# 試験" "" "ハーネスの版: 1" "" "## 検査のコマンド" "" "| 何を確かめるか | コマンド |" "|---|---|" "$2" "" \
    "## 文書の地図" "" "| 種類 | パス |" "|---|---|" "| 計画の書式 | \`docs/PLANS.md\` |" > "$1/AGENTS.md"
}

# docs/QUALITY_SCORE.md を書く。$1 = リポジトリ、$2 = 「## 目標」の表の行、$3 = 「## 現在の評価」の節（省略時は MIN_RATINGS）
write_quality() {
  printf '%s\n' "# 品質目標" "" "## 目標" "" "| 目標 | 測る項目 | 確かめ方 | 検査の識別子 |" "|---|---|---|---|" "$2" "" \
    "${3-$MIN_RATINGS}" > "$1/docs/QUALITY_SCORE.md"
}

# 検査 1〜7、12〜14 を通る最小のリポジトリを作る
make_base() {
  local d="$1" p
  mkdir -p "$d/docs/adr" "$d/docs/exec-plans/active" "$d/docs/exec-plans/completed" \
    "$d/docs/quality-eval/tasks" "$d/docs/quality-eval/results" "$d/scripts/harness" "$d/.github/workflows"
  cp "$CHECK" "$d/scripts/harness/check-docs.sh"
  cp "$PLANS" "$d/docs/PLANS.md"
  write_agents "$d" "$AGENTS_DOCS_ROW"
  write_quality "$d" "$QUALITY_DOCS_ROW"
  printf '@AGENTS.md\n' > "$d/CLAUDE.md"
  printf '%s\n' "# ARCHITECTURE" "" "$MIN_INVARIANTS" > "$d/ARCHITECTURE.md"
  printf '%s\n' "$MIN_NET_CONSTS" > "$d/eslint.config.mjs"
  printf '# ADR\n' > "$d/docs/adr/README.md"
  for p in .gitignore docs/quality-eval/README.md scripts/harness/check-arch.sh \
    scripts/harness/check-secrets.sh scripts/harness/check-secrets.mjs .dependency-cruiser.cjs .secretlintrc.json \
    .github/workflows/harness.yml .github/dependabot.yml; do
    : > "$d/$p"
  done
  git -C "$d" init -q
}

# 書式の文書（$1）の「## 必須の節」から、必須の見出しを 1 行ずつ出す
required_headings() {
  awk '/^## 必須の節$/{on=1; next} /^## /{on=0} on' "$1" | sed -n 's/^[0-9][0-9]*\. `\(## [^`]*\)`.*$/\1/p'
}

# 計画を書く。$1 = パス、$2 = 検証の節の本文、$3 = 目的の節の本文（省略可）、$4 = 進捗の節の本文（省略時は、基準の日の
# 既定の日付の 1 行。検査 11 の対象でない場合の進行中の計画が、基準の日の既定を替えても古い計画にならないようにするため。
# 空の文字列を渡すと、進捗の節を空にする）。必須の節の見出しは本物の docs/PLANS.md から読む
write_plan() {
  local path="$1" verification="$2" purpose="${3:-}" progress="${4-- $BASE_TODAY: 試験の進捗。}" heading
  {
    printf '# 試験の計画\n\n'
    required_headings "$PLANS" | while IFS= read -r heading; do
      printf '%s\n\n' "$heading"
      if [ "$heading" = "## 検証（完了の条件）" ]; then
        printf '%s\n\n' "$verification"
      elif [ "$heading" = "## 目的" ] && [ -n "$purpose" ]; then
        printf '%s\n\n' "$purpose"
      elif [ "$heading" = "## 進捗" ] && [ -n "$progress" ]; then
        printf '%s\n\n' "$progress"
      fi
    done
  } > "$path"
}

# 受け入れ確認の基準 2 件（V1、V2）と、自動テストの基準 1 件（V3）を持つ、新しい書式の検証の節
VERIFY_NEW='### V1 決まった記事が点数の高い順に並ぶ

- 前提: 確認用のデータで起動している。
- 操作: 画面を開く。
- 期待する結果: 412、156、88、37 の順に並ぶ。
- 確かめ方: 受け入れ確認

### V2 各記事に点数が出る

- 前提: 同上。
- 操作: 画面を開く。
- 期待する結果: 各記事の後ろに点数が出る。
- 確かめ方: 受け入れ確認

### V3 選別の関数が古い記事を落とす

- 確かめ方: 自動テスト'

# 記録の 1 回分の実行（docs/PLANS.md の「受け入れ確認の記録」の必須の行をすべて持つ）。
# $1 = 番号、$2 = 確かめた者、$3 以降 = 「識別子=結果」。全体の値は、結果がすべて合格なら合格、そうでなければ不合格
run_block() {
  local n="$1" who="$2" pair overall="合格"
  shift 2
  printf '## 実行 %s\n\n- 日時: 2026-10-08 14:05（日本時間）\n- 確かめた者: %s\n- 元のコミット: 1111111\n- 分岐元: 0000000\n' "$n" "$who"
  printf -- '- 確かめた対象:\n  - `src/ui/NewsList.tsx` 2222222 変更なし\n'
  for pair in "$@"; do
    printf -- '- 基準 %s: %s\n  - 前提: 試験の前提\n  - 操作: 試験の操作\n  - 観察した結果: 試験の値\n  - 証拠: 試験の証拠\n' \
      "${pair%%=*}" "${pair#*=}"
    [ "${pair#*=}" = "合格" ] || overall="不合格"
  done
  printf -- '- 基準外の所見: なし\n- 未確認の範囲: なし\n- 全体: %s\n\n' "$overall"
}

# 正しい記録（実行 1 で V1 と V2 が合格）から、$2 で始まる行を 1 行だけ消したものを $1 に書く
record_without_line() {
  run_block 1 app-evaluator V1=合格 V2=合格 | awk -v prefix="$2" '!done && index($0, prefix) == 1 { done = 1; next } { print }' > "$1"
}

# 場合を 1 つ動かす。$1 = 名前、$2 = 期待（pass / fail）、$3 = 失敗のときに出力に含まれるべき文言、$4 = 準備の関数。
# 検査には、基準の日として CASE_TODAY（空なら BASE_TODAY）を渡す
run_case() {
  local name="$1" expect="$2" want="$3" setup="$4" d out rc
  d="$TMP_ROOT/case-$((passed + failed + 1))"
  make_base "$d"
  "$setup" "$d"
  set +e
  out="$(HARNESS_TODAY="${CASE_TODAY:-$BASE_TODAY}" bash "$d/scripts/harness/check-docs.sh" 2>&1)"
  rc=$?
  set -e
  if [ "$expect" = pass ] && [ "$rc" -eq 0 ]; then
    echo "ok: $name（通る）"
    passed=$((passed + 1))
  elif [ "$expect" = fail ] && [ "$rc" -eq 1 ] && grep -qF -- "$want" <<<"$out"; then
    echo "ok: $name（失敗する: $want）"
    passed=$((passed + 1))
  else
    echo "NG: $name（期待: $expect、終了コード: $rc）" >&2
    printf '%s\n' "$out" | sed 's/^/    /' >&2
    failed=$((failed + 1))
  fi
}

# 基準の日を指定して、場合を 1 つ動かす。$1 = 基準の日（YYYY-MM-DD）、$2 以降 = run_case の引数
run_case_on() {
  CASE_TODAY="$1"
  shift
  run_case "$@"
  CASE_TODAY=""
}

C="docs/exec-plans/completed"
A="docs/exec-plans/active"

# --- 通る場合 ---

setup_empty() { :; }

setup_correct() {
  write_plan "$1/$C/$NEW.md" "$VERIFY_NEW"
  run_block 1 app-evaluator V1=合格 V2=合格 > "$1/$C/$NEW.acceptance.md"
}

setup_partial_recheck() {
  write_plan "$1/$C/$NEW.md" "$VERIFY_NEW"
  { run_block 1 app-evaluator V1=不合格 V2=合格; run_block 2 app-evaluator V1=合格; } > "$1/$C/$NEW.acceptance.md"
}

setup_other_checker_later() {
  write_plan "$1/$C/$NEW.md" "$VERIFY_NEW"
  { run_block 1 app-evaluator V1=合格 V2=合格; run_block 2 implementer V1=不合格 V2=未確認; } > "$1/$C/$NEW.acceptance.md"
}

setup_active_pair() {
  write_plan "$1/$A/$NEW.md" "$VERIFY_NEW"
  # 進行中の計画の記録は合否を検査しない（不合格のままでも通る）。記録を計画とみなさないことも確かめる
  run_block 1 app-evaluator V1=不合格 V2=未確認 > "$1/$A/$NEW.acceptance.md"
}

setup_old_format() {
  write_plan "$1/$C/$OLD.md" "$VERIFY_NEW"
}

setup_criteria_in_code_block() {
  write_plan "$1/$C/$NEW.md" '### V3 自動テストだけの基準

- 確かめ方: 自動テスト

```markdown
### V1 例として書いた受け入れ確認の基準
- 確かめ方: 受け入れ確認
```'
}

# --- 失敗する場合 ---

setup_no_record() {
  write_plan "$1/$C/$NEW.md" "$VERIFY_NEW"
}

setup_latest_failed() {
  write_plan "$1/$C/$NEW.md" "$VERIFY_NEW"
  { run_block 1 app-evaluator V1=合格 V2=合格; run_block 2 app-evaluator V2=不合格; } > "$1/$C/$NEW.acceptance.md"
}

setup_latest_unverified() {
  write_plan "$1/$C/$NEW.md" "$VERIFY_NEW"
  { run_block 1 app-evaluator V1=合格 V2=合格; run_block 2 app-evaluator V1=未確認; } > "$1/$C/$NEW.acceptance.md"
}

setup_only_other_checker() {
  write_plan "$1/$C/$NEW.md" "$VERIFY_NEW"
  { run_block 1 app-evaluator V1=合格; run_block 2 implementer V2=合格; } > "$1/$C/$NEW.acceptance.md"
}

setup_record_only() {
  run_block 1 app-evaluator V1=合格 > "$1/$C/$NEW.acceptance.md"
}

setup_misplaced() {
  write_plan "$1/$C/$NEW.md" "$VERIFY_NEW"
  run_block 1 app-evaluator V1=合格 V2=合格 > "$1/$A/$NEW.acceptance.md"
}

setup_fake_pass_in_code_block() {
  write_plan "$1/$C/$NEW.md" "$VERIFY_NEW"
  {
    run_block 1 app-evaluator V1=合格 V2=不合格
    printf '## 実行 2\n\n```markdown\n- 確かめた者: app-evaluator\n- 基準 V2: 合格\n```\n'
  } > "$1/$C/$NEW.acceptance.md"
}

setup_outside_heading() {
  write_plan "$1/$C/$NEW.md" '- 確かめ方: 受け入れ確認

### V1 決まった記事が点数の高い順に並ぶ

- 確かめ方: 受け入れ確認'
  run_block 1 app-evaluator V1=合格 > "$1/$C/$NEW.acceptance.md"
}

setup_absolute_path() {
  write_plan "$1/$C/$NEW.md" "$VERIFY_NEW"
  {
    run_block 1 app-evaluator V1=合格 V2=合格
    printf -- '- 証拠: スクリーンショット /private/tmp/shot.png\n'
  } > "$1/$C/$NEW.acceptance.md"
}

VERIFY_V2_OK='### V2 各記事に点数が出る

- 確かめ方: 自動テスト'

setup_fullwidth_colon() {
  write_plan "$1/$C/$NEW.md" "### V1 題

- 確かめ方：受け入れ確認

$VERIFY_V2_OK"
}

setup_other_bullet() {
  write_plan "$1/$C/$NEW.md" "### V1 題

* 確かめ方: 受け入れ確認

$VERIFY_V2_OK"
}

setup_missing_method() {
  write_plan "$1/$C/$NEW.md" "### V1 題

- 期待する結果: 並ぶ。

$VERIFY_V2_OK"
}

setup_two_methods() {
  write_plan "$1/$C/$NEW.md" "### V1 題

- 確かめ方: 自動テスト
- 確かめ方: 人が確認"
}

setup_bad_method_value() {
  write_plan "$1/$C/$NEW.md" "### V1 題

- 確かめ方: 目で見る"
}

setup_duplicate_id() {
  write_plan "$1/$C/$NEW.md" "### V1 題

- 確かめ方: 自動テスト

### V1 別の題

- 確かめ方: 人が確認"
}

setup_unclosed_code_block_plan() {
  write_plan "$1/$C/$NEW.md" "$VERIFY_V2_OK

\`\`\`text
閉じていない"
}

setup_no_headings() {
  write_plan "$1/$C/$NEW.md" "基準はまだ書いていない。"
}

setup_table_row_acceptance() {
  write_plan "$1/$C/$NEW.md" "$VERIFY_V2_OK

| 基準 | 確かめる手段 |
|---|---|
| V1 | 受け入れ確認 |"
}

setup_method_without_colon() {
  write_plan "$1/$C/$NEW.md" "### V1 題

- 確かめ方 受け入れ確認

$VERIFY_V2_OK"
}

# 地の文と、ほかの項目の行で受け入れ確認に触れるだけなら通る
setup_prose_mentions_acceptance() {
  write_plan "$1/$C/$NEW.md" "受け入れ確認は、この計画では使わない。

### V1 題

- 期待する結果: 受け入れ確認の担当が見ても分かる表示になる。
- 確かめ方: 自動テスト"
}

setup_heading_without_id() {
  write_plan "$1/$C/$NEW.md" "###

- 確かめ方: 自動テスト"
}

setup_indented_method() {
  write_plan "$1/$C/$NEW.md" "### V1 題

  - 確かめ方: 自動テスト"
}

setup_skipped_run_number() {
  write_plan "$1/$C/$NEW.md" "$VERIFY_NEW"
  { run_block 1 app-evaluator V1=合格 V2=合格; run_block 3 app-evaluator V1=合格; } > "$1/$C/$NEW.acceptance.md"
}

setup_non_run_heading() {
  write_plan "$1/$C/$NEW.md" "$VERIFY_NEW"
  { run_block 1 app-evaluator V1=合格 V2=合格; printf '## メモ\n\n- 追記\n'; } > "$1/$C/$NEW.acceptance.md"
}

setup_bad_overall() {
  write_plan "$1/$C/$NEW.md" "$VERIFY_NEW"
  run_block 1 app-evaluator V1=合格 V2=合格 | sed 's/^- 全体: 合格$/- 全体: おおむね合格/' > "$1/$C/$NEW.acceptance.md"
}

setup_empty_required_value() {
  write_plan "$1/$C/$NEW.md" "$VERIFY_NEW"
  run_block 1 app-evaluator V1=合格 V2=合格 | sed 's/^- 日時: .*$/- 日時:/' > "$1/$C/$NEW.acceptance.md"
}

MISSING_PREFIX=""
setup_record_missing_line() {
  write_plan "$1/$C/$NEW.md" "$VERIFY_NEW"
  record_without_line "$1/$C/$NEW.acceptance.md" "$MISSING_PREFIX"
}

setup_duplicate_run_number() {
  write_plan "$1/$C/$NEW.md" "$VERIFY_NEW"
  { run_block 1 app-evaluator V1=合格 V2=合格; run_block 1 app-evaluator V1=合格; } > "$1/$C/$NEW.acceptance.md"
}

setup_reversed_run_number() {
  write_plan "$1/$C/$NEW.md" "$VERIFY_NEW"
  { run_block 2 app-evaluator V1=合格 V2=合格; run_block 1 app-evaluator V1=合格; } > "$1/$C/$NEW.acceptance.md"
}

setup_unclosed_code_block_record() {
  write_plan "$1/$C/$NEW.md" "$VERIFY_NEW"
  { run_block 1 app-evaluator V1=合格 V2=合格; printf '```text\n閉じていない\n'; } > "$1/$C/$NEW.acceptance.md"
}

setup_undated_completed_plan() {
  write_plan "$1/$C/score-filter.md" "$VERIFY_NEW"
}

setup_misplaced_reverse() {
  write_plan "$1/$A/$NEW.md" "$VERIFY_NEW"
  run_block 1 app-evaluator V1=合格 V2=合格 > "$1/$C/$NEW.acceptance.md"
}

setup_no_start_line() {
  grep -v '^新しい書式の適用開始: ' "$1/docs/PLANS.md" > "$1/docs/PLANS.md.tmp"
  mv "$1/docs/PLANS.md.tmp" "$1/docs/PLANS.md"
}

run_case "計画も記録も無い" pass "" setup_empty
run_case "正しい記録" pass "" setup_correct
run_case "部分の再確認（実行 2 で V1 だけを確かめ直して合格）" pass "" setup_partial_recheck
run_case "app-evaluator 以外の実行が後にあっても、判定に数える最新が合格" pass "" setup_other_checker_later
run_case "active/ に計画と記録がある（検査 9 の対象外。記録を計画とみなさない）" pass "" setup_active_pair
run_case "旧い書式の完了した計画（記録が無くてよい）" pass "" setup_old_format
run_case "計画のコードブロックの中の受け入れ確認の基準は数えない" pass "" setup_criteria_in_code_block

run_case "記録が無い" fail "受け入れ確認の記録 $C/$NEW.acceptance.md がありません" setup_no_record
run_case "最新が不合格" fail "基準 V2 の、最新の受け入れ確認の結果が「不合格」" setup_latest_failed
run_case "最新が未確認（前の実行は合格）" fail "基準 V1 の、最新の受け入れ確認の結果が「未確認」" setup_latest_unverified
run_case "app-evaluator 以外の実行しか無い基準" fail "基準 V2 に、判定に数える受け入れ確認の実行がありません" setup_only_other_checker
run_case "記録だけがある" fail "に対応する計画 $C/$NEW.md がありません" setup_record_only
run_case "置き場の取り違え（計画は completed/、記録は active/）" fail "と別のディレクトリにあります" setup_misplaced
run_case "コードブロックの中にだけ偽の合格の行がある記録" fail "基準 V2 の、最新の受け入れ確認の結果が「不合格」" setup_fake_pass_in_code_block
run_case "見出しの外に受け入れ確認の基準がある新しい計画" fail "どの「### <識別子>」の見出しの下にも無い" setup_outside_heading
run_case "記録に絶対パス" fail "に絶対パスの形があります" setup_absolute_path
run_case "確かめ方の行に全角のコロン" fail "形の崩れた確かめ方の行があります" setup_fullwidth_colon
run_case "確かめ方の行に別の箇条書きの記号" fail "形の崩れた確かめ方の行があります" setup_other_bullet
run_case "基準に確かめ方の行が無い" fail "基準 V1 に「- 確かめ方: <値>」の行がありません" setup_missing_method
run_case "基準に確かめ方の行が 2 行" fail "基準 V1 に「- 確かめ方: <値>」の行が 2 行あります" setup_two_methods
run_case "確かめ方の値が 3 つのどれでもない" fail "「自動テスト」「受け入れ確認」「人が確認」のどれでもありません" setup_bad_method_value
run_case "基準の識別子の重複" fail "基準の識別子 V1 が重複しています" setup_duplicate_id
run_case "地の文とほかの項目の行で受け入れ確認に触れるだけの計画" pass "" setup_prose_mentions_acceptance
run_case "検証の節に基準の見出しが 1 つも無い" fail "基準の見出し（### <識別子> <題>）が 1 つもありません" setup_no_headings
run_case "表の行に受け入れ確認" fail "表の行に受け入れ確認があります" setup_table_row_acceptance
run_case "コロンの無い確かめ方の行" fail "形の崩れた確かめ方の行があります" setup_method_without_colon
run_case "識別子の無い見出し" fail "識別子の無い基準の見出しがあります" setup_heading_without_id
run_case "字下げした確かめ方の行" fail "形の崩れた確かめ方の行があります" setup_indented_method
run_case "実行の番号の欠け（1 の次が 3）" fail "2 番目の実行の番号が 3 です" setup_skipped_run_number
run_case "「## 実行 <番号>」でない ## の見出し" fail "「## 実行 <番号>」でない見出しがあります" setup_non_run_heading
run_case "全体の値が 3 種のどれでもない" fail "全体の値「おおむね合格」は、合格・不合格・未確認のどれでもありません" setup_bad_overall
run_case "値の無い必須の行" fail "実行 1 の「- 日時:」に値がありません" setup_empty_required_value
run_case "計画に閉じていないコードブロック" fail "閉じていないコードブロック" setup_unclosed_code_block_plan
for field in 日時 確かめた者 元のコミット 分岐元 確かめた対象 基準外の所見 未確認の範囲 全体; do
  MISSING_PREFIX="- $field:"
  run_case "記録の実行に「- $field:」の行が無い" fail "実行 1 に「- $field:」の行がありません" setup_record_missing_line
done
MISSING_PREFIX="  - 証拠:"
run_case "記録の基準の下に証拠の行が無い" fail "実行 1 の基準 V1 の下に「  - 証拠: <値>」の行がありません" setup_record_missing_line
run_case "実行の番号の重複" fail "2 番目の実行の番号が 1 です" setup_duplicate_run_number
run_case "実行の番号の逆順" fail "1 番目の実行の番号が 2 です" setup_reversed_run_number
run_case "記録に閉じていないコードブロック" fail "閉じていないコードブロック" setup_unclosed_code_block_record
run_case "日付で始まらない名前の完了した計画（検査 9 の対象）" fail "受け入れ確認の記録 $C/score-filter.acceptance.md がありません" setup_undated_completed_plan
run_case "置き場の取り違えの逆向き（計画は active/、記録は completed/）" fail "と別のディレクトリにあります" setup_misplaced_reverse
run_case "docs/PLANS.md に適用開始の行が無い" fail "「新しい書式の適用開始: YYYY-MM-DD」の行がありません" setup_no_start_line

# --- 検査 10: 製品の仕様 ---

SP="docs/product-specs"

# 仕様の置き場を作り、本物の docs/product-specs/README.md の書式（目録の節より前）と、目録の表の見出しの 2 行を写す。
# 目録の表の本文の行（実際に登録された仕様）は取り除き、空の目録にする。残すと、実際に仕様が登録されたとき、
# 写した先にその仕様のファイルが無く、通るはずの試験が失敗するため。README.md がリンクする
# 製品の前提（docs/PRODUCT_SENSE.md）も写す（検査 4 のリンクの検査を通すため）
add_spec_dir() {
  mkdir -p "$1/$SP"
  awk '/^## 目録$/ { in_catalog = 1 } !(in_catalog && /^\| / && !/^\| 略号 /)' "$SPECS_README" > "$1/$SP/README.md"
  cp "$ROOT/docs/PRODUCT_SENSE.md" "$1/docs/PRODUCT_SENSE.md"
}

# 目録に 1 行を足す。$1 = リポジトリ、$2 = 略号、$3 = 仕様のファイル名、$4 = 状態。
# 目録の節はファイルの最後にある（書式の文書の決まり）ので、末尾に足せば表の行になる
add_catalog_row() {
  printf '| %s | [%s](%s) | 文字の大きさの切り替え | %s |\n' "$2" "$3" "$3" "$4" >> "$1/$SP/README.md"
}

# 受け入れ基準 1 件。$1 = 識別子
criterion() {
  printf '### %s 文字の大きさを「大」にすると、一覧の文字が大きくなる\n\n- 前提: 一覧が標準の文字の大きさで表示されている。\n- 操作: 文字の大きさの切り替えで「大」を選ぶ。\n- 期待する結果: 一覧の各項目の題が、標準より大きい文字で表示される。\n' "$1"
}

# 仕様を書く。$1 = パス、$2 = 受け入れ基準の節の本文、$3 = 未決の点の節の本文（省略時は「なし」）。
# 必須の節の見出しは本物の docs/product-specs/README.md から読む
write_spec() {
  local path="$1" criteria="$2" open="${3:-なし}" heading
  {
    printf '# 一覧の文字の大きさの切り替え\n\n'
    required_headings "$SPECS_README" | while IFS= read -r heading; do
      printf '%s\n\n' "$heading"
      case "$heading" in
        "## 受け入れ基準") printf '%s\n\n' "$criteria" ;;
        "## 未決の点") printf '%s\n\n' "$open" ;;
        *) printf '試験の本文。\n\n' ;;
      esac
    done
  } > "$path"
}

# 正しい仕様 1 件（略号 FONT、基準 FONT-1 と FONT-2）を、状態 $2 で置く
add_font_spec() {
  add_spec_dir "$1"
  write_spec "$1/$SP/list-font-size.md" "$(criterion FONT-1)

$(criterion FONT-2)"
  add_catalog_row "$1" FONT list-font-size.md "$2"
}

# 仕様の基準 FONT-1 と、計画の中で振る基準 V1 を引く検証の節（確かめ方は自動テストなので、受け入れ確認の記録は要らない）
VERIFY_SPEC='### FONT-1 文字の大きさを「大」にすると、一覧の文字が大きくなる

- 前提: 仕様のとおり。
- 操作: 仕様のとおり。
- 期待する結果: 仕様のとおり。
- 確かめ方: 自動テスト

### V1 切り替えの部品の試験が通る

- 確かめ方: 自動テスト'
PURPOSE_SPEC='一覧の文字の大きさを切り替えられるようにする。製品の仕様: `docs/product-specs/list-font-size.md`'
PURPOSE_NONE='一覧の文字の大きさを切り替えられるようにする。製品の仕様は無い。'
VERIFY_V_ONLY='### V1 切り替えの部品の試験が通る

- 確かめ方: 自動テスト'

# --- 検査 10: 通る場合 ---

setup_spec_correct() { add_font_spec "$1" draft; }
setup_spec_catalog_empty() { add_spec_dir "$1"; }
setup_spec_no_dir_v_only() {
  write_plan "$1/$A/$NEW.md" "$VERIFY_V_ONLY" "$PURPOSE_NONE"
  write_plan "$1/$C/$NEW-done.md" "$VERIFY_V_ONLY" "$PURPOSE_NONE"
}
setup_spec_active_approved() {
  add_font_spec "$1" approved
  write_plan "$1/$A/$NEW.md" "$VERIFY_SPEC" "$PURPOSE_SPEC"
}
setup_spec_completed_approved() {
  add_font_spec "$1" approved
  write_plan "$1/$C/$NEW.md" "$VERIFY_SPEC" "$PURPOSE_SPEC"
}
setup_spec_completed_archived() {
  add_font_spec "$1" archived
  write_plan "$1/$C/$NEW.md" "$VERIFY_SPEC" "$PURPOSE_SPEC"
}
setup_spec_draft_open_question() {
  add_spec_dir "$1"
  write_spec "$1/$SP/list-font-size.md" "$(criterion FONT-1)" '- [NEEDS CLARIFICATION: 文字の大きさの段階は 2 つか 3 つか]'
  add_catalog_row "$1" FONT list-font-size.md draft
}
# 旧い書式の計画は、仕様と照合しない
setup_spec_old_plan_ignored() {
  write_plan "$1/$C/$OLD.md" "$VERIFY_SPEC" "$PURPOSE_NONE"
}

# --- 検査 10: 失敗する場合 ---

setup_spec_not_in_catalog() {
  add_spec_dir "$1"
  write_spec "$1/$SP/list-font-size.md" "$(criterion FONT-1)"
}
setup_spec_missing_file() {
  add_spec_dir "$1"
  add_catalog_row "$1" FONT list-font-size.md draft
}
setup_spec_bad_status() { add_font_spec "$1" done; }
setup_spec_status_line() {
  add_font_spec "$1" draft
  printf '状態: draft\n' >> "$1/$SP/list-font-size.md"
}
setup_spec_approved_open_question() {
  add_spec_dir "$1"
  write_spec "$1/$SP/list-font-size.md" "$(criterion FONT-1)" '- [NEEDS CLARIFICATION: 文字の大きさの段階は 2 つか 3 つか]'
  add_catalog_row "$1" FONT list-font-size.md approved
}
setup_spec_missing_section() {
  add_font_spec "$1" draft
  grep -vxF '## 利用者の操作の流れ' "$1/$SP/list-font-size.md" > "$1/$SP/tmp" && mv "$1/$SP/tmp" "$1/$SP/list-font-size.md"
}
setup_spec_bad_abbr() {
  add_spec_dir "$1"
  write_spec "$1/$SP/list-font-size.md" "$(criterion Font-1)"
  add_catalog_row "$1" Font list-font-size.md draft
}
setup_spec_duplicate_abbr() {
  add_font_spec "$1" draft
  write_spec "$1/$SP/list-font-color.md" "$(criterion FONT-3)"
  add_catalog_row "$1" FONT list-font-color.md draft
}
setup_spec_duplicate_id() {
  add_spec_dir "$1"
  write_spec "$1/$SP/list-font-size.md" "$(criterion FONT-1)

$(criterion FONT-1)"
  add_catalog_row "$1" FONT list-font-size.md draft
}
setup_spec_id_abbr_mismatch() {
  add_spec_dir "$1"
  write_spec "$1/$SP/list-font-size.md" "$(criterion SIZE-1)"
  add_catalog_row "$1" FONT list-font-size.md draft
}
setup_spec_missing_item() {
  add_spec_dir "$1"
  write_spec "$1/$SP/list-font-size.md" "$(criterion FONT-1 | grep -v '^- 操作:')"
  add_catalog_row "$1" FONT list-font-size.md draft
}
setup_spec_no_criteria() {
  add_spec_dir "$1"
  write_spec "$1/$SP/list-font-size.md" "基準はまだ書いていない。"
  add_catalog_row "$1" FONT list-font-size.md draft
}
setup_spec_criteria_only_in_code_block() {
  add_spec_dir "$1"
  write_spec "$1/$SP/list-font-size.md" "\`\`\`markdown
$(criterion FONT-1)
\`\`\`"
  add_catalog_row "$1" FONT list-font-size.md draft
}
setup_plan_unknown_spec_id() {
  add_font_spec "$1" approved
  write_plan "$1/$A/$NEW.md" "### FONT-9 実在しない基準

- 確かめ方: 自動テスト" "$PURPOSE_SPEC"
}
setup_plan_spec_id_without_dir() {
  write_plan "$1/$A/$NEW.md" "$VERIFY_SPEC" "$PURPOSE_SPEC"
}
setup_plan_active_draft() {
  add_font_spec "$1" draft
  write_plan "$1/$A/$NEW.md" "$VERIFY_SPEC" "$PURPOSE_SPEC"
}
setup_plan_active_archived() {
  add_font_spec "$1" archived
  write_plan "$1/$A/$NEW.md" "$VERIFY_SPEC" "$PURPOSE_SPEC"
}
setup_plan_completed_draft() {
  add_font_spec "$1" draft
  write_plan "$1/$C/$NEW.md" "$VERIFY_SPEC" "$PURPOSE_SPEC"
}
setup_plan_no_purpose_path() {
  add_font_spec "$1" approved
  write_plan "$1/$A/$NEW.md" "$VERIFY_SPEC" "$PURPOSE_NONE"
}
setup_plan_purpose_not_in_catalog() {
  add_font_spec "$1" approved
  write_plan "$1/$A/$NEW.md" "$VERIFY_SPEC" "$PURPOSE_SPEC 関連: \`docs/product-specs/list-font-weight.md\`"
}
setup_plan_purpose_other_spec() {
  add_font_spec "$1" approved
  write_spec "$1/$SP/list-font-color.md" "$(criterion COLOR-1)"
  add_catalog_row "$1" COLOR list-font-color.md approved
  write_plan "$1/$A/$NEW.md" "$VERIFY_SPEC" '製品の仕様: `docs/product-specs/list-font-color.md`'
}

# --- 検査 10: レビューの後に足した場合 ---

# 2 つの approved の仕様（FONT と COLOR）を置く
add_two_specs() {
  add_font_spec "$1" approved
  write_spec "$1/$SP/list-font-color.md" "$(criterion COLOR-1)"
  add_catalog_row "$1" COLOR list-font-color.md "$2"
}
VERIFY_TWO="$VERIFY_SPEC

### COLOR-1 文字の色を切り替える

- 確かめ方: 自動テスト"

setup_plan_two_paths_joined() {
  add_two_specs "$1" approved
  write_plan "$1/$A/$NEW.md" "$VERIFY_TWO" '製品の仕様: docs/product-specs/list-font-size.md、docs/product-specs/list-font-color.md'
}
setup_plan_purpose_draft_spec() {
  add_two_specs "$1" draft
  write_plan "$1/$A/$NEW.md" "$VERIFY_SPEC" '製品の仕様: `docs/product-specs/list-font-size.md`、`docs/product-specs/list-font-color.md`'
}
setup_spec_heading_without_title() {
  add_spec_dir "$1"
  write_spec "$1/$SP/list-font-size.md" "$(criterion FONT-1 | sed '1s/^### FONT-1 .*$/### FONT-1/')"
  add_catalog_row "$1" FONT list-font-size.md draft
}
# archived の仕様は、書式（必須の節、基準の項目）を変えた後の形に合わなくても通る。完了した計画はその識別子を引ける
setup_spec_archived_old_format() {
  add_spec_dir "$1"
  write_spec "$1/$SP/list-font-size.md" "$(criterion FONT-1 | grep -v '^- 操作:')"
  grep -vxF '## 利用者の操作の流れ' "$1/$SP/list-font-size.md" > "$1/$SP/tmp" && mv "$1/$SP/tmp" "$1/$SP/list-font-size.md"
  add_catalog_row "$1" FONT list-font-size.md archived
  write_plan "$1/$C/$NEW.md" "$VERIFY_SPEC" "$PURPOSE_SPEC"
}
setup_spec_bad_catalog_header() {
  add_spec_dir "$1"
  sed 's/^| 略号 | 仕様 | 題 | 状態 |$/| 略号 | 題 | 仕様 | 状態 |/' "$1/$SP/README.md" > "$1/$SP/tmp" && mv "$1/$SP/tmp" "$1/$SP/README.md"
}
setup_spec_bad_column_count() {
  add_spec_dir "$1"
  write_spec "$1/$SP/list-font-size.md" "$(criterion FONT-1)"
  printf '| FONT | [list-font-size.md](list-font-size.md) | 文字の大きさ | 切り替え | draft |\n' >> "$1/$SP/README.md"
}
setup_spec_duplicate_catalog_row() {
  add_font_spec "$1" draft
  add_catalog_row "$1" SIZE list-font-size.md draft
}
setup_spec_link_not_direct() {
  add_spec_dir "$1"
  mkdir -p "$1/$SP/sub"
  write_spec "$1/$SP/sub/list-font-size.md" "$(criterion FONT-1)"
  add_catalog_row "$1" FONT sub/list-font-size.md draft
}
setup_spec_archived_open_question() {
  add_spec_dir "$1"
  write_spec "$1/$SP/list-font-size.md" "$(criterion FONT-1)" '- [NEEDS CLARIFICATION: 文字の大きさの段階は 2 つか 3 つか]'
  add_catalog_row "$1" FONT list-font-size.md archived
}
setup_spec_duplicate_item() {
  add_spec_dir "$1"
  write_spec "$1/$SP/list-font-size.md" "$(criterion FONT-1 | awk '{ print } /^- 前提: / { print "- 前提: 二つ目の前提。" }')"
  add_catalog_row "$1" FONT list-font-size.md draft
}

setup_spec_bad_file_name() {
  add_spec_dir "$1"
  write_spec "$1/$SP/List_Font.md" "$(criterion FONT-1)"
  add_catalog_row "$1" FONT List_Font.md draft
}

run_case "仕様: 英小文字・数字・ハイフンでない仕様のファイル名" fail "仕様 $SP/List_Font.md: 仕様のファイル名が英小文字・数字・ハイフンではありません" setup_spec_bad_file_name
run_case "仕様: 目的の節に読点でつないだ 2 つのパス" pass "" setup_plan_two_paths_joined
run_case "仕様: archived の仕様は書式の変更の後も通る" pass "" setup_spec_archived_old_format
run_case "仕様: 目的の節に書いた draft の仕様（識別子は引かない）" fail "進行中の計画 $A/$NEW.md が引く仕様 $SP/list-font-color.md の状態が「draft」です" setup_plan_purpose_draft_spec
run_case "仕様: 題の無い基準の見出し" fail "基準 FONT-1 の見出しに題がありません" setup_spec_heading_without_title
run_case "仕様: 目録の表の見出しの行の列の順序の誤り" fail "目録の表の見出しの行が「略号,題,仕様,状態」です（期待: 略号,仕様,題,状態）" setup_spec_bad_catalog_header
run_case "仕様: 目録の行の列の数の誤り" fail "目録の行（略号 FONT）の列の数が 5 です" setup_spec_bad_column_count
run_case "仕様: 同じ仕様を指す目録の行の重複" fail "目録に、仕様 $SP/list-font-size.md の行が 2 行以上あります" setup_spec_duplicate_catalog_row
run_case "仕様: 目録のリンク先が直下の *.md でない" fail "目録の略号 FONT のリンク先 sub/list-font-size.md が、$SP の直下の仕様のファイルではありません" setup_spec_link_not_direct
run_case "仕様: archived に未決の点が残る" fail "は archived なのに、未決の点" setup_spec_archived_open_question
run_case "仕様: 基準の項目の重複" fail "基準 FONT-1 に「- 前提:」の行が 2 行あります（1 行にする）" setup_spec_duplicate_item

run_case "仕様: 正しい仕様と目録" pass "" setup_spec_correct
run_case "仕様: 目録が空（仕様が 0 件）" pass "" setup_spec_catalog_empty
run_case "仕様: 置き場が無く、V<数字> だけの計画" pass "" setup_spec_no_dir_v_only
run_case "仕様: approved の仕様を引く進行中の計画" pass "" setup_spec_active_approved
run_case "仕様: approved の仕様を引く完了した計画" pass "" setup_spec_completed_approved
run_case "仕様: archived の仕様を引く完了した計画" pass "" setup_spec_completed_archived
run_case "仕様: draft に未決の点が残る" pass "" setup_spec_draft_open_question
run_case "仕様: 旧い書式の計画は仕様と照合しない" pass "" setup_spec_old_plan_ignored

run_case "仕様: 目録に無い仕様のファイル" fail "仕様 $SP/list-font-size.md が目録 $SP/README.md にありません" setup_spec_not_in_catalog
run_case "仕様: 実在しない仕様を指す目録の行" fail "目録の略号 FONT のリンク先 $SP/list-font-size.md がありません" setup_spec_missing_file
run_case "仕様: 状態の値の誤り" fail "状態「done」は、draft・approved・archived のどれでもありません" setup_spec_bad_status
run_case "仕様: 仕様の中の状態の行" fail "に状態の行があります" setup_spec_status_line
run_case "仕様: approved に未決の点が残る" fail "は approved なのに、未決の点" setup_spec_approved_open_question
run_case "仕様: 必須の節の欠け" fail "必須の節の見出し「## 利用者の操作の流れ」の行がありません" setup_spec_missing_section
run_case "仕様: 略号の形の誤り" fail "目録の略号 Font が、英大文字 2〜6 字ではありません" setup_spec_bad_abbr
run_case "仕様: 略号の重複" fail "目録の略号 FONT が重複しています" setup_spec_duplicate_abbr
run_case "仕様: 識別子の重複" fail "受け入れ基準の識別子 FONT-1 が重複しています（重複のある仕様: $SP/list-font-size.md）" setup_spec_duplicate_id
run_case "仕様: 略号と合わない識別子" fail "基準の識別子 SIZE-1 が、この仕様の略号の形（FONT-<数字>）ではありません" setup_spec_id_abbr_mismatch
run_case "仕様: 基準の項目の欠け" fail "基準 FONT-1 に「- 操作:」の行がありません" setup_spec_missing_item
run_case "仕様: 基準が 0 件" fail "受け入れ基準の見出し（「## 受け入れ基準」の下の ### <識別子> <題>）が 1 つもありません" setup_spec_no_criteria
run_case "仕様: コードブロックの中にだけある基準の見出し" fail "受け入れ基準の見出し（「## 受け入れ基準」の下の ### <識別子> <題>）が 1 つもありません" setup_spec_criteria_only_in_code_block
run_case "仕様: 計画が実在しない仕様の識別子を引く" fail "の基準 FONT-9 が、どの製品の仕様の受け入れ基準にもありません" setup_plan_unknown_spec_id
run_case "仕様: 置き場が無いのに V<数字> でない識別子を引く" fail "の基準 FONT-1 は V<数字> ではありませんが、製品の仕様の置き場 $SP がありません" setup_plan_spec_id_without_dir
run_case "仕様: 進行中の計画が draft の仕様を引く" fail "の状態が「draft」です" setup_plan_active_draft
run_case "仕様: 進行中の計画が archived の仕様を引く" fail "の状態が「archived」です" setup_plan_active_archived
run_case "仕様: 完了した計画が draft の仕様を引く" fail "完了した計画 $C/$NEW.md が引く仕様 $SP/list-font-size.md の状態が「draft」です" setup_plan_completed_draft
run_case "仕様: 目的の節に仕様のパスが無い" fail "目的の節に仕様のパスがありません" setup_plan_no_purpose_path
run_case "仕様: 目的の節の仕様のパスが目録に無い" fail "目的の節の仕様 $SP/list-font-weight.md が、目録 $SP/README.md にありません" setup_plan_purpose_not_in_catalog
run_case "仕様: 目的の節の仕様と識別子の所属先が違う" fail "の基準 FONT-1 は仕様 $SP/list-font-size.md の基準ですが、目的の節に書いた仕様にありません" setup_plan_purpose_other_spec

# --- 検査 11: 古い計画 ---

# 基準の日と、そこから数えた日付。日数の計算を試験の側に持たないように、決まった値で書く。
# check-docs.sh の STALE_PLAN_DAYS が 30 の前提。変えたらここも直す。
# HARNESS_TEST_TODAY で基準の日の既定を替えても、ここの場合は自分の基準の日を使う
T11="2026-12-31"   # 基準の日
D10="2026-12-21"   # 10 日前
D29="2026-12-02"   # 29 日前
D30="2026-12-01"   # 30 日前
D45="2026-11-16"   # 45 日前
D60="2026-11-01"   # 60 日前
NEXT1="2027-01-01"  # 1 日後
NEXT2="2027-01-02"  # 2 日後
LATER="2027-02-01"  # 1 日後より後

# 検査 11 の場合の計画を書く。$1 = パス、$2 = 進捗の節の本文（空なら、進捗の節に日付を書かない）、$3 = 目的の節の本文（省略可）
write_dated_plan() {
  write_plan "$1" "$VERIFY_V_ONLY" "${3:-$PURPOSE_NONE}" "$2"
}

# --- 検査 11: 通る場合 ---

setup_stale_name_29_days() { write_dated_plan "$1/$A/$D29-list-font.md" ""; }
setup_stale_progress_10_days() { write_dated_plan "$1/$A/$D60-list-font.md" "- $D10: 手順 1 を終えた。"; }
setup_stale_completed() { write_dated_plan "$1/$C/$D60-list-font.md" ""; }
# 記録の中の日付（run_block の日時）もファイル名の日付も古いが、計画の進捗の節の日付は新しい
setup_stale_record_only() {
  write_dated_plan "$1/$A/$D60-list-font.md" "- $D10: 手順 1 を終えた。"
  run_block 1 app-evaluator V1=合格 > "$1/$A/$D60-list-font.acceptance.md"
}
setup_stale_undated_name_fresh_progress() { write_dated_plan "$1/$A/list-font.md" "- $D10: 手順 1 を終えた。"; }
# 基準の日の 1 日後の日付は数える（手元と CI の時刻帯の差のため）
setup_stale_next_day_progress() { write_dated_plan "$1/$A/$D60-list-font.md" "- $NEXT1: 手順 1 を終えた。"; }
# うるう年の 2 月 29 日は、基準の日としても、暦にある日付である（基準の日 2028-02-29 の 29 日前の計画）
setup_stale_29_days_before_leap_day() { write_dated_plan "$1/$A/2028-01-31-list-font.md" ""; }
# 年をまたぐ日数（基準の日 2027-01-15 の 29 日前）
setup_stale_29_days_across_year() { write_dated_plan "$1/$A/2026-12-17-list-font.md" ""; }

# --- 検査 11: 失敗する場合 ---

setup_stale_both_old() { write_dated_plan "$1/$A/$D30-list-font.md" "- $D45: 計画を起票した。"; }
setup_stale_no_date() { write_dated_plan "$1/$A/list-font.md" "- 手順 1 を終えた。"; }
setup_stale_date_only_in_code_block() {
  write_dated_plan "$1/$A/$D60-list-font.md" "\`\`\`text
- $D10: 手順 1 を終えた。
\`\`\`"
}
# 進捗の節の外（目的の節）に書いた日付は数えない
setup_stale_date_outside_progress() {
  write_dated_plan "$1/$A/$D60-list-font.md" "" "一覧の文字の大きさを切り替えられるようにする。製品の仕様は無い。方針は $D10 に決めた。"
}
# 基準の日の 1 日後より後の日付（予定の日付）は数えない
setup_stale_only_later_date_is_new() { write_dated_plan "$1/$A/$D60-list-font.md" "- $LATER に再開する。"; }
setup_stale_only_later_dates() { write_dated_plan "$1/$A/list-font.md" "- $LATER に再開する。"; }
setup_stale_two_days_later_date() { write_dated_plan "$1/$A/$D60-list-font.md" "- $NEXT2 に再開する。"; }
# 進捗の節より後の節（発見）に書いた日付は数えない
setup_stale_date_in_later_section() {
  write_dated_plan "$1/$A/$D60-list-font.md" ""
  awk -v line="- $D10 に分かったこと。" '{ print } $0 == "## 発見" { print ""; print line }' "$1/$A/$D60-list-font.md" > "$1/$A/plan.tmp"
  mv "$1/$A/plan.tmp" "$1/$A/$D60-list-font.md"
}
# 前か後ろに数字が続く並びは、日付として数えない
setup_stale_digits_around_date() { write_dated_plan "$1/$A/$D60-list-font.md" "- 番号 1$D10 と ${D10}5 を控えた。"; }
# 暦に無い日付は数えない（基準の日 2027-05-01。ファイル名は 60 日前、進捗は 4 月 31 日）
setup_stale_april_31() { write_dated_plan "$1/$A/2027-03-02-list-font.md" "- 2027-04-31: 手順 1 を終えた。"; }
# 暦に無い日付しか無い（基準の日 2027-03-01。平年の 2 月 29 日）
setup_stale_feb_29_common_year() { write_dated_plan "$1/$A/list-font.md" "- 2027-02-29: 手順 1 を終えた。"; }
# うるう年の 2 月をまたぐ日数（基準の日 2028-03-01 のちょうど 30 日前）
setup_stale_30_days_across_leap_february() { write_dated_plan "$1/$A/2028-01-31-list-font.md" ""; }

run_case_on "$T11" "古い計画: 進行中の計画が 0 件" pass "" setup_empty
run_case_on "$T11" "古い計画: ファイル名の日付が 29 日前" pass "" setup_stale_name_29_days
run_case_on "$T11" "古い計画: ファイル名は 60 日前だが、進捗に 10 日前の日付がある" pass "" setup_stale_progress_10_days
run_case_on "$T11" "古い計画: completed/ の古い計画は対象にしない" pass "" setup_stale_completed
run_case_on "$T11" "古い計画: 受け入れ確認の記録だけが古い（記録を計画とみなさない）" pass "" setup_stale_record_only
run_case_on "$T11" "古い計画: 名前が日付で始まらないが、進捗に 10 日前の日付がある" pass "" setup_stale_undated_name_fresh_progress
run_case_on "$T11" "古い計画: 進捗に基準の日の 1 日後の日付がある（数える）" pass "" setup_stale_next_day_progress
run_case_on "2027-01-15" "古い計画: 年をまたいで 29 日前" pass "" setup_stale_29_days_across_year
run_case_on "2028-02-29" "古い計画: 基準の日がうるう年の 2 月 29 日（暦にある日付）" pass "" setup_stale_29_days_before_leap_day

run_case_on "$T11" "古い計画: ファイル名が 30 日前で、進捗の日付はそれより前" fail "進行中の計画 $A/$D30-list-font.md が古くなっています（最も新しい日付 $D30 から 30 日" setup_stale_both_old
run_case_on "$T11" "古い計画: 直し方に、進捗の節への追記と completed/ への移動が出る" fail "「## 進捗」の節に、進めた日付（YYYY-MM-DD）の行を足す。終えたなら、「## 結果と振り返り」を書いて docs/exec-plans/completed/ へ移す" setup_stale_both_old
run_case_on "$T11" "古い計画: 日付を 1 つも読めない計画" fail "進行中の計画 $A/list-font.md の古さを判定できません" setup_stale_no_date
run_case_on "$T11" "古い計画: 進捗の日付がコードブロックの中にだけある" fail "進行中の計画 $A/$D60-list-font.md が古くなっています（最も新しい日付 $D60 から 60 日" setup_stale_date_only_in_code_block
run_case_on "$T11" "古い計画: 進捗の節の外に書いた日付は数えない" fail "進行中の計画 $A/$D60-list-font.md が古くなっています（最も新しい日付 $D60 から 60 日" setup_stale_date_outside_progress
run_case_on "$T11" "古い計画: 進捗の、基準の日の 1 日後より後の日付は数えない" fail "進行中の計画 $A/$D60-list-font.md が古くなっています（最も新しい日付 $D60 から 60 日" setup_stale_only_later_date_is_new
run_case_on "$T11" "古い計画: 数えられる日付が、基準の日の 1 日後より後のものしか無い" fail "進行中の計画 $A/list-font.md の古さを判定できません" setup_stale_only_later_dates
run_case_on "2028-03-01" "古い計画: うるう年の 2 月をまたいで、ちょうど 30 日前" fail "進行中の計画 $A/2028-01-31-list-font.md が古くなっています（最も新しい日付 2028-01-31 から 30 日" setup_stale_30_days_across_leap_february
run_case_on "$T11" "古い計画: 進捗の、基準の日の 2 日後の日付は数えない" fail "進行中の計画 $A/$D60-list-font.md が古くなっています（最も新しい日付 $D60 から 60 日" setup_stale_two_days_later_date
run_case_on "$T11" "古い計画: 進捗の節より後の節に書いた日付は数えない" fail "進行中の計画 $A/$D60-list-font.md が古くなっています（最も新しい日付 $D60 から 60 日" setup_stale_date_in_later_section
run_case_on "$T11" "古い計画: 前後に数字が続く並びは日付として数えない" fail "進行中の計画 $A/$D60-list-font.md が古くなっています（最も新しい日付 $D60 から 60 日" setup_stale_digits_around_date
run_case_on "2027-05-01" "古い計画: 進捗の 4 月 31 日は数えない" fail "進行中の計画 $A/2027-03-02-list-font.md が古くなっています（最も新しい日付 2027-03-02 から 60 日" setup_stale_april_31
run_case_on "2027-03-01" "古い計画: 進捗の日付が平年の 2 月 29 日だけ" fail "進行中の計画 $A/list-font.md の古さを判定できません" setup_stale_feb_29_common_year
run_case_on "$T11" "古い計画: 日付が無いときの直し方に、進捗の行の形が出る" fail "「- YYYY-MM-DD: 終えた手順」の形で、作業を進めた日付の行を書く" setup_stale_no_date
run_case_on "2026-13-01" "古い計画: 基準の日が日付の形でない" fail "環境変数 HARNESS_TODAY の値「2026-13-01」が、YYYY-MM-DD の形の、暦にある日付ではありません" setup_empty
run_case_on "2027-02-29" "古い計画: 基準の日が平年の 2 月 29 日" fail "環境変数 HARNESS_TODAY の値「2027-02-29」が、YYYY-MM-DD の形の、暦にある日付ではありません" setup_empty

# --- 検査 7: ARCHITECTURE.md に書いた templates/ のパス ---

setup_arch_templates_path_exists() {
  mkdir -p "$1/templates/module"
  printf '%s\n' "" "ひな形の置き場は \`templates/module/\` である。" >> "$1/ARCHITECTURE.md"
}
setup_arch_templates_path_missing() {
  printf '%s\n' "" "ひな形の置き場は \`templates/module/\` である。" >> "$1/ARCHITECTURE.md"
}

run_case "設計の正本: 書いた templates/ のパスが実在する" pass "" setup_arch_templates_path_exists
run_case "設計の正本: 書いた templates/ のパスが無い" fail "ARCHITECTURE.md に書いたパス templates/module/ がありません" setup_arch_templates_path_missing

# --- 検査 12: 文書の検査の一覧 ---

# 2 つの文書の対象の行を書き換える（行は冒頭で本物から写したもの）。$1 = リポジトリ、$2 = AGENTS.md の行、$3 = docs/QUALITY_SCORE.md の行
add_check_list_docs() {
  write_agents "$1" "$2"
  write_quality "$1" "$3"
}

# 行 $1 から、項目 $2（文書での書き方のまま。バッククォートも含める）を、前の「、」とともに消す。
# 項目が見つからなければ行をそのまま出す（失敗を期待する場合が通り、試験が NG を出す）
drop_name() {
  awk -v s="、$2" '{ i = index($0, s); if (i) $0 = substr($0, 1, i - 1) substr($0, i + length(s)); print }' <<<"$1"
}

setup_list_correct() { add_check_list_docs "$1" "$AGENTS_DOCS_ROW" "$QUALITY_DOCS_ROW"; }
# 出どころ 1 の形（TD-4）: docs/QUALITY_SCORE.md の測る項目だけが狭い
setup_list_quality_narrow() {
  add_check_list_docs "$1" "$AGENTS_DOCS_ROW" "$(drop_name "$QUALITY_DOCS_ROW" "古い計画")"
}
# AGENTS.md の表の行だけが狭い
setup_list_agents_narrow() {
  add_check_list_docs "$1" "$(drop_name "$AGENTS_DOCS_ROW" "受け入れ確認の記録")" "$QUALITY_DOCS_ROW"
}
# 出どころ 2 の形（PR #38）: 2 つの文書がそろって検査 7 の名前を欠く（2 つを比べるだけでは見つからない）
setup_list_both_missing_check7() {
  add_check_list_docs "$1" "$(drop_name "$AGENTS_DOCS_ROW" "ARCHITECTURE.md に書いたパス")" \
    "$(drop_name "$QUALITY_DOCS_ROW" "\`ARCHITECTURE.md\` に書いたパス")"
}
# 名前はそろっているが順が違う
setup_list_order() {
  local row
  row="$(awk '{ i = index($0, "地図、リンク"); if (i) $0 = substr($0, 1, i - 1) "リンク、地図" substr($0, i + length("地図、リンク")); print }' <<<"$AGENTS_DOCS_ROW")"
  add_check_list_docs "$1" "$row" "$QUALITY_DOCS_ROW"
}
# 節はあるのに、check:docs の行が無い
setup_list_agents_row_missing() {
  add_check_list_docs "$1" "| 試験 | \`npm run test\` |" "$QUALITY_DOCS_ROW"
}
# CHECK_NAMES から名前を 1 つ消した（冒頭の一覧の検査の数と合わない）
setup_list_names_short() {
  add_check_list_docs "$1" "$AGENTS_DOCS_ROW" "$QUALITY_DOCS_ROW"
  awk '$0 != "  \"古い計画\""' "$1/scripts/harness/check-docs.sh" > "$1/scripts/harness/check-docs.tmp"
  mv "$1/scripts/harness/check-docs.tmp" "$1/scripts/harness/check-docs.sh"
}

run_case "文書の検査の一覧: 本物の 2 つの行（バッククォートの有無は問わない）" pass "" setup_list_correct
run_case "文書の検査の一覧: docs/QUALITY_SCORE.md の測る項目だけが狭い" fail "docs/QUALITY_SCORE.md の「## 目標」の表の、目標が「文書が実物と合っている」の行の測る項目の括弧書き" setup_list_quality_narrow
run_case "文書の検査の一覧: 欠けた名前を示す" fail "が、文書の検査の一覧と合いません（足りない名前: 古い計画）" setup_list_quality_narrow
run_case "文書の検査の一覧: AGENTS.md の表の行だけが狭い" fail "AGENTS.md の「## 検査のコマンド」の表の、コマンドが \`npm run check:docs\` の行の括弧書き" setup_list_agents_narrow
run_case "文書の検査の一覧: 2 つの文書がそろって検査 7 を欠く" fail "check-docs: 2 件の問題があります" setup_list_both_missing_check7
run_case "文書の検査の一覧: 2 つの文書がそろって欠けた名前を示す" fail "（足りない名前: ARCHITECTURE.md に書いたパス）" setup_list_both_missing_check7
run_case "文書の検査の一覧: 名前の順が違う" fail "（名前の順か区切りが違います）" setup_list_order
run_case "文書の検査の一覧: 節はあるのに check:docs の行が無い" fail "\`npm run check:docs\` の行が 0 行あります（1 行のはず）" setup_list_agents_row_missing
run_case "文書の検査の一覧: CHECK_NAMES の数が冒頭の一覧の検査の数と違う" fail "検査が 14 件なのに、CHECK_NAMES の名前が 13 件です" setup_list_names_short

# 見出しを変えると、黙って調べなくなるのではなく失敗する
setup_list_agents_heading_renamed() {
  awk '{ if ($0 == "## 検査のコマンド") print "## 検査の命令"; else print }' "$1/AGENTS.md" > "$1/AGENTS.tmp"
  mv "$1/AGENTS.tmp" "$1/AGENTS.md"
}
setup_list_quality_heading_renamed() {
  awk '{ if ($0 == "## 目標") print "## 品質の目標"; else print }' "$1/docs/QUALITY_SCORE.md" > "$1/docs/QUALITY_SCORE.tmp"
  mv "$1/docs/QUALITY_SCORE.tmp" "$1/docs/QUALITY_SCORE.md"
}
run_case "文書の検査の一覧: AGENTS.md の「## 検査のコマンド」の見出しを変えた" fail "AGENTS.md に「## 検査のコマンド」の見出しの行がありません" setup_list_agents_heading_renamed
run_case "文書の検査の一覧: docs/QUALITY_SCORE.md の「## 目標」の見出しを変えた" fail "docs/QUALITY_SCORE.md に「## 目標」の見出しの行がありません" setup_list_quality_heading_renamed

# --- 検査 13: 通信の名前の一覧 ---

# 本物の ARCHITECTURE.md の「## 不変条件」の 1 と 2（見出しから 3 の前まで）と、本物の eslint.config.mjs の 3 つの定数の行を
# 写して使う（読み取りの前提の書き方を、試験に二重に持たないため）。写した不変条件が書くパス（src/ports/ など）は、
# 検査 7 を通すために作る（make_base の最小の不変条件と設定を置き換える）
# 節の冒頭の注記（検査 13 が読み取ることの説明。同じ言い回しを含む）は写さず、見出しと 1・2 の項目だけを写す
REAL_INVARIANTS="$(awk '/^## /{ on = ($0 == "## 不変条件"); if (on) print; next } on && /^1\. /{ items = 1 } on && /^3\. /{ exit } on && items' "$ROOT/ARCHITECTURE.md")"
REAL_NET_CONSTS="$(grep -E '^const NETWORK_(MODULE_BASES|MODULES|GLOBALS) = ' "$ROOT/eslint.config.mjs" || true)"
if [ -z "$REAL_INVARIANTS" ] || [ "$(printf '%s\n' "$REAL_NET_CONSTS" | awk 'END { print NR }')" -ne 3 ]; then
  echo "check-docs.test: NG: 本物の ARCHITECTURE.md の不変条件か、eslint.config.mjs の 3 つの定数の行を読み取れません" >&2
  exit 1
fi

# 文字列 $1 の中の、最初の $2 を $3 に置き換える。$2 が無ければそのまま出す（失敗を期待する場合が通り、試験が NG を出す）
replace_once() {
  awk -v from="$2" -v to="$3" 'BEGIN { RS = "\001" } { i = index($0, from); if (i) $0 = substr($0, 1, i - 1) to substr($0, i + length(from)); printf "%s", $0 }' <<<"$1"
}

# $1 = リポジトリ、$2 = 不変条件の節、$3 = eslint.config.mjs の中身
add_net_files() {
  mkdir -p "$1/src/ports" "$1/templates"
  printf '%s\n' "# ARCHITECTURE" "" "$2" > "$1/ARCHITECTURE.md"
  printf '%s\n' "$3" > "$1/eslint.config.mjs"
}

setup_net_correct() { add_net_files "$1" "$REAL_INVARIANTS" "$REAL_NET_CONSTS"; }
setup_net_module_arch_only() {
  add_net_files "$1" "$(replace_once "$REAL_INVARIANTS" '`dgram` と、' '`dgram`、`quic` と、')" "$REAL_NET_CONSTS"
}
setup_net_module_eslint_only() {
  add_net_files "$1" "$REAL_INVARIANTS" "$(replace_once "$REAL_NET_CONSTS" '"undici"]' '"undici", "ws"]')"
}
setup_net_global_arch_only() {
  add_net_files "$1" "$(replace_once "$REAL_INVARIANTS" '`XMLHttpRequest`、' '`XMLHttpRequest`、`WebTransport`、')" "$REAL_NET_CONSTS"
}
setup_net_global_eslint_only() {
  add_net_files "$1" "$REAL_INVARIANTS" "$(replace_once "$REAL_NET_CONSTS" '"EventSource"]' '"EventSource", "WebTransport"]')"
}
# ARCHITECTURE.md の node: の書き方を変える（検査 13 の読み取りの前提が崩れる）
setup_net_arch_wording() {
  add_net_files "$1" "$(replace_once "$REAL_INVARIANTS" 'と、それぞれに `node:` を付けた名前、' 'と、その node: 付きの名前、')" "$REAL_NET_CONSTS"
}
# eslint.config.mjs の NETWORK_MODULES の組み立て方を変える（同上）
setup_net_eslint_form() {
  add_net_files "$1" "$REAL_INVARIANTS" "$(replace_once "$REAL_NET_CONSTS" '[...NETWORK_MODULE_BASES.flatMap(' '[...NETWORK_MODULE_BASES.map(')"
}

# 不変条件 2 を「それぞれに」と「`node:`」の間の空白で折り返す（続きの行は空白 1 つを挟んでつなぐので、読める）
setup_net_fold_at_space() {
  add_net_files "$1" "$(replace_once "$REAL_INVARIANTS" 'それぞれに `node:`' 'それぞれに\n   `node:`')" "$REAL_NET_CONSTS"
}
setup_net_no_eslint_config() { rm "$1/eslint.config.mjs"; }
# 古い 1 行の宣言をブロックコメントの中に残し、本物の宣言を複数行にして名前を足す（コメントの中の古い宣言だけを拾って
# 見逃さないこと）。$1 = リポジトリ、$2 = 定数の名前、$3 = 複数行にした本物の宣言（\n で改行）
add_net_commented_old() {
  local old
  old="$(grep "^const $2 = " <<<"$REAL_NET_CONSTS")"
  add_net_files "$1" "$REAL_INVARIANTS" "$(replace_once "$REAL_NET_CONSTS" "$old" "/*\n$old\n*/\n$3")"
}
setup_net_globals_commented_old() {
  add_net_commented_old "$1" NETWORK_GLOBALS 'const NETWORK_GLOBALS = [\n  "fetch", "WebSocket", "XMLHttpRequest", "EventSource", "WebTransport",\n];'
}
setup_net_bases_commented_old() {
  add_net_commented_old "$1" NETWORK_MODULE_BASES 'const NETWORK_MODULE_BASES = [\n  "http", "https", "http2", "net", "tls", "dgram", "quic",\n];'
}

run_case "通信の名前の一覧: 本物の不変条件と定数" pass "" setup_net_correct
run_case "通信の名前の一覧: 不変条件 2 を「それぞれに」の後の空白で折り返しても読める" pass "" setup_net_fold_at_space
run_case "通信の名前の一覧: eslint.config.mjs が無い" fail "eslint.config.mjs がありません（検査 13 が" setup_net_no_eslint_config
run_case "通信の名前の一覧: NETWORK_GLOBALS の古い宣言をコメントに残し、本物を複数行にして名前を足す" fail "NETWORK_GLOBALS に値を入れる書き方（「NETWORK_GLOBALS =」。コメントの中を含む）が 2 か所" setup_net_globals_commented_old
run_case "通信の名前の一覧: NETWORK_MODULE_BASES の古い宣言をコメントに残し、本物を複数行にして名前を足す" fail "NETWORK_MODULE_BASES に値を入れる書き方（「NETWORK_MODULE_BASES =」。コメントの中を含む）が 2 か所" setup_net_bases_commented_old
run_case "通信の名前の一覧: ARCHITECTURE.md だけにモジュールがある" fail "通信のためのモジュールが合いません（ARCHITECTURE.md だけにある: node:quic、quic。eslint.config.mjs だけにある: なし）" setup_net_module_arch_only
run_case "通信の名前の一覧: eslint.config.mjs だけにモジュールがある" fail "通信のためのモジュールが合いません（ARCHITECTURE.md だけにある: なし。eslint.config.mjs だけにある: ws）" setup_net_module_eslint_only
run_case "通信の名前の一覧: ARCHITECTURE.md だけに大域の名前がある" fail "通信のための大域の名前が合いません（ARCHITECTURE.md だけにある: WebTransport。" setup_net_global_arch_only
setup_net_base_eslint_only() {
  add_net_files "$1" "$REAL_INVARIANTS" "$(replace_once "$REAL_NET_CONSTS" '"dgram"]' '"dgram", "quic"]')"
}
run_case "通信の名前の一覧: eslint.config.mjs の NETWORK_MODULE_BASES だけに名前がある" fail "eslint.config.mjs だけにある: node:quic、quic）" setup_net_base_eslint_only
run_case "通信の名前の一覧: eslint.config.mjs だけに大域の名前がある" fail "eslint.config.mjs だけにある: WebTransport）" setup_net_global_eslint_only
run_case "通信の名前の一覧: ARCHITECTURE.md の node: の書き方を変えると、黙って通らず失敗する" fail "に「と、それぞれに \`node:\` を付けた名前、」がありません" setup_net_arch_wording
run_case "通信の名前の一覧: NETWORK_MODULES の組み立て方を変えると、黙って通らず失敗する" fail "eslint.config.mjs の NETWORK_MODULES の行が" setup_net_eslint_form

# --- 検査 14: 層の評価の上限 ---

# 本物の docs/QUALITY_SCORE.md の「## 現在の評価」の節（見出しから末尾まで）を写して使う（表 2 の書き方を試験に二重に持たないため）
REAL_RATINGS="$(awk '/^## /{ on = ($0 == "## 現在の評価") } on' "$ROOT/docs/QUALITY_SCORE.md")"
if ! grep -qF '| `src/domain/` | B |' <<<"$REAL_RATINGS"; then
  echo "check-docs.test: NG: 本物の docs/QUALITY_SCORE.md の「## 現在の評価」から、表 2 の層 src/domain/ の行を読み取れません" >&2
  exit 1
fi
T2_HEAD='| 層 | 評価 | 検査の識別子 | 人が確かめる決まりの数 | 根拠 | 評価した日 | 評価したコミット |'
T2_SEP='|---|---|---|---|---|---|---|'
T1_HEAD='| 領域 | 評価 | 検査の識別子 | 根拠 | 評価した日 | 評価したコミット |'

# 「## 現在の評価」の節を $2 にした docs/QUALITY_SCORE.md を書く。$1 = リポジトリ
set_ratings() { write_quality "$1" "$QUALITY_DOCS_ROW" "$2"; }
# 表 2 を、見出しの行 $2、区切りの行 $3、行 $4 以降で書く。$1 = リポジトリ
set_t2() {
  local d="$1" head="$2" sep="$3"
  shift 3
  set_ratings "$d" "$(printf '%s\n' "## 現在の評価" "" "$head" "$sep" "$@")"
}

setup_layer_real() { set_ratings "$1" "$REAL_RATINGS"; }
# 元の決まりに反する形: 本物の表 2 で、決まりの数が 4 の層を A にした
setup_layer_real_a() { set_ratings "$1" "$(replace_once "$REAL_RATINGS" '| `src/domain/` | B |' '| `src/domain/` | A |')"; }
setup_layer_zero_a() { set_t2 "$1" "$T2_HEAD" "$T2_SEP" '| `src/app/` | A | `lint` | 0 | 見本 | 2026-10-16 | c4b6083 |'; }
setup_layer_one_a() { set_t2 "$1" "$T2_HEAD" "$T2_SEP" '| `src/app/` | A | `lint` | 1 | 見本 | 2026-10-16 | c4b6083 |'; }
# 列の順を変えても、見出しの名前で列を探す
setup_layer_reordered() {
  set_t2 "$1" '| 層 | 人が確かめる決まりの数 | 検査の識別子 | 評価 |' '|---|---|---|---|' \
    '| `src/app/` | 0 | `lint` | A |' '| `src/ui/` | 2 | `lint` | A |'
}
# 表 1 の評価 A（決まりの数の列が無い表）は対象にしない
setup_layer_table1_a() {
  set_ratings "$1" "$(printf '%s\n' "## 現在の評価" "" "$T1_HEAD" '|---|---|---|---|---|---|' '| 見本 | A | `lint` | 見本 | 2026-10-16 | c4b6083 |' \
    "" "$T2_HEAD" "$T2_SEP" '| `src/app/` | B | `lint` | 1 | 見本 | 2026-10-16 | c4b6083 |')"
}
# 表 2 の途中に空行があり、続きの行（A の行）が別の表になる（黙って読み飛ばさないこと）
setup_layer_split_by_blank() {
  set_ratings "$1" "$(printf '%s\n' "## 現在の評価" "" "$T2_HEAD" "$T2_SEP" '| `src/app/` | B | `lint` | 4 | 見本 | 2026-10-16 | c4b6083 |' \
    "" '| `src/ui/` | A | `lint` | 4 | 見本 | 2026-10-16 | c4b6083 |')"
}
# 表 1 の見出しでも表 2 の見出しでもない表（列の少ない表 1 など）
setup_layer_other_table() {
  set_ratings "$1" "$(printf '%s\n' "## 現在の評価" "" '| 領域 | 評価 | 根拠 |' '|---|---|---|' '| 見本 | A | 見本 |' "" "$T2_HEAD" "$T2_SEP" \
    '| `src/app/` | B | `lint` | 1 | 見本 | 2026-10-16 | c4b6083 |')"
}
setup_layer_two_count_columns() {
  set_t2 "$1" '| 層 | 評価 | 人が確かめる決まりの数 | 人が確かめる決まりの数 |' '|---|---|---|---|' '| `src/app/` | A | 1 | 1 |'
}
# 正しい節の後に、末尾に空白 2 個を付けた同じ名前の見出しと、評価 A の表 2 を置く（後半を調べずに通さないこと）
setup_layer_second_section_trailing_space() {
  set_ratings "$1" "$(printf '%s\n' "## 現在の評価" "" "$T2_HEAD" "$T2_SEP" '| `src/app/` | B | `lint` | 1 | 見本 | 2026-10-16 | c4b6083 |' \
    "" "## 現在の評価  " "" "$T2_HEAD" "$T2_SEP" '| `src/ui/` | A | `lint` | 1 | 見本 | 2026-10-16 | c4b6083 |')"
}
# 末尾に空白を付けた見出しだけでも、同じ節として読む（評価 A を見逃さないこと）
setup_layer_trailing_space_only() {
  set_ratings "$1" "$(printf '%s\n' "## 現在の評価  " "" "$T2_HEAD" "$T2_SEP" '| `src/ui/` | A | `lint` | 1 | 見本 | 2026-10-16 | c4b6083 |')"
}
# ~~~ のコードブロックの中に ``` だけの行を入れ、その後に評価 A の本物の表 2 を置く
setup_layer_tilde_fence() {
  set_ratings "$1" "$(printf '%s\n' "## 現在の評価" "" '~~~markdown' '```' '~~~' "" "$T2_HEAD" "$T2_SEP" \
    '| `src/ui/` | A | `lint` | 1 | 見本 | 2026-10-16 | c4b6083 |')"
}
# 区切りの行の列の数が見出しより少ない
setup_layer_separator_short() {
  set_t2 "$1" "$T2_HEAD" '|---|---|---|' '| `src/app/` | B | `lint` | 1 | 見本 | 2026-10-16 | c4b6083 |'
}
# 区切りの行の途中のセルが区切りの書式でない
setup_layer_separator_bad_cell() {
  set_t2 "$1" "$T2_HEAD" '|---|X|---|---|---|---|---|' '| `src/app/` | B | `lint` | 1 | 見本 | 2026-10-16 | c4b6083 |'
}
# 表 2 は見出しと区切りの行だけで、空行の後に正しい表 1 がある
setup_layer_empty_t2_then_t1() {
  set_ratings "$1" "$(printf '%s\n' "## 現在の評価" "" "$T2_HEAD" "$T2_SEP" "" "$T1_HEAD" '|---|---|---|---|---|---|' \
    '| 見本 | A | `lint` | 見本 | 2026-10-16 | c4b6083 |')"
}
# 名前の違う節（全角空白を付けた見出し、別の名前の節）に、表 2 と同じ見出しの、評価 A の表を置く
setup_layer_fullwidth_decoy() {
  set_ratings "$1" "$(printf '%s\n' "## 現在の評価" "" "$T2_HEAD" "$T2_SEP" '| `src/app/` | B | `lint` | 4 | 見本 | 2026-10-16 | c4b6083 |' \
    "" "## 現在の評価　" "" "$T2_HEAD" "$T2_SEP" '| `src/ui/` | A | `lint` | 4 | 見本 | 2026-10-16 | c4b6083 |')"
}
setup_layer_other_section() {
  set_ratings "$1" "$(printf '%s\n' "## 現在の評価" "" "$T2_HEAD" "$T2_SEP" '| `src/app/` | B | `lint` | 4 | 見本 | 2026-10-16 | c4b6083 |' \
    "" "## 付録" "" "$T2_HEAD" "$T2_SEP" '| `src/ui/` | A | `lint` | 4 | 見本 | 2026-10-16 | c4b6083 |')"
}
# 節の外の囲みのコードブロックの中にある、表 2 と同じ見出しの見本の表と見出しは数えない
setup_layer_sample_in_fence_outside() {
  set_ratings "$1" "$(printf '%s\n' "## 書き方の見本" "" '~~~markdown' "## 現在の評価" "$T2_HEAD" "$T2_SEP" \
    '| `src/ui/` | A | `lint` | 4 | 見本 | 2026-10-16 | c4b6083 |' '```' '~~~' "" "$MIN_RATINGS")"
}
# 見出しの直後が区切りの行でない（評価 A の行が見出しの直後にある）
setup_layer_no_separator() {
  set_ratings "$1" "$(printf '%s\n' "## 現在の評価" "" "$T2_HEAD" '| `src/app/` | A | `lint` | 4 | 見本 | 2026-10-16 | c4b6083 |')"
}
setup_layer_count_renamed() {
  set_t2 "$1" '| 層 | 評価 | 検査の識別子 | 人が確かめる決まり | 根拠 | 評価した日 | 評価したコミット |' "$T2_SEP" \
    '| `src/app/` | A | `lint` | 1 | 見本 | 2026-10-16 | c4b6083 |'
}
setup_layer_rating_renamed() {
  set_t2 "$1" '| 層 | 評定 | 検査の識別子 | 人が確かめる決まりの数 | 根拠 | 評価した日 | 評価したコミット |' "$T2_SEP" \
    '| `src/app/` | A | `lint` | 1 | 見本 | 2026-10-16 | c4b6083 |'
}
setup_layer_count_not_integer() { set_t2 "$1" "$T2_HEAD" "$T2_SEP" '| `src/app/` | A | `lint` | 4 つ | 見本 | 2026-10-16 | c4b6083 |'; }
setup_layer_rating_bad() { set_t2 "$1" "$T2_HEAD" "$T2_SEP" '| `src/app/` | `A` | `lint` | 1 | 見本 | 2026-10-16 | c4b6083 |'; }
setup_layer_column_count() { set_t2 "$1" "$T2_HEAD" "$T2_SEP" '| `src/app/` | A | `lint` | 1 | 見本 | 2026-10-16 |'; }
setup_layer_no_rows() { set_t2 "$1" "$T2_HEAD" "$T2_SEP"; }
setup_layer_no_section() { set_ratings "$1" ""; }
setup_layer_two_tables() {
  set_ratings "$1" "$(printf '%s\n' "## 現在の評価" "" "$T2_HEAD" "$T2_SEP" '| `src/app/` | B | `lint` | 1 | 見本 | 2026-10-16 | c4b6083 |' \
    "" "$T2_HEAD" "$T2_SEP" '| `src/ui/` | A | `lint` | 1 | 見本 | 2026-10-16 | c4b6083 |')"
}
# コードブロックの中の表だけがある（数えないので、表 2 が無い）
setup_layer_in_code_block() {
  set_ratings "$1" "$(printf '%s\n' "## 現在の評価" "" '```' "$T2_HEAD" "$T2_SEP" '| `src/app/` | B | `lint` | 1 | 見本 | 2026-10-16 | c4b6083 |' '```')"
}
# 表 2 の直後に空行が無い形。GFM では、行頭の縦線を省いた行も、空行か別のブロックの始まりまでは表 2 の行として表示される
T2_TAIL_ERR="表 2 の直後に空行がありません（縦線で始まらない行も、表 2 の行として表示されることがあります）"
# 最後の 1 行の縦線を外して A にした
setup_layer_tail_one_no_pipe_a() {
  set_t2 "$1" "$T2_HEAD" "$T2_SEP" '| `src/app/` | B | `lint` | 4 | 見本 | 2026-10-16 | c4b6083 |' \
    '`src/ui/` | A | `lint` | 4 | 見本 | 2026-10-16 | c4b6083'
}
# 最後の 2 行の縦線を外して A にした
setup_layer_tail_two_no_pipe_a() {
  set_t2 "$1" "$T2_HEAD" "$T2_SEP" '| `src/app/` | B | `lint` | 4 | 見本 | 2026-10-16 | c4b6083 |' \
    '`src/ui/` | A | `lint` | 4 | 見本 | 2026-10-16 | c4b6083' '`src/ports/` | A | `lint` | 3 | 見本 | 2026-10-16 | c4b6083'
}
# 最後の 1 行の縦線を外したが、評価は B のまま（空行が無いことを理由に失敗する）
setup_layer_tail_one_no_pipe_b() {
  set_t2 "$1" "$T2_HEAD" "$T2_SEP" '| `src/app/` | B | `lint` | 4 | 見本 | 2026-10-16 | c4b6083 |' \
    '`src/ui/` | B | `lint` | 4 | 見本 | 2026-10-16 | c4b6083'
}
# 最後の行の後に改ページ（\f）だけの行を挟み、その次に縦線の無い A の行（\f だけの行を空行とみなさないこと）
setup_layer_tail_formfeed_then_a() {
  set_t2 "$1" "$T2_HEAD" "$T2_SEP" '| `src/app/` | B | `lint` | 4 | 見本 | 2026-10-16 | c4b6083 |' \
    "$(printf '\f')" '`src/ui/` | A | `lint` | 4 | 見本 | 2026-10-16 | c4b6083'
}
# 表 2 の直後に見出しが続く（表を終える行でも、空行を求めて失敗にする）
setup_layer_tail_heading() {
  set_t2 "$1" "$T2_HEAD" "$T2_SEP" '| `src/app/` | B | `lint` | 4 | 見本 | 2026-10-16 | c4b6083 |' '## 付録'
}
# 表 2 の後に空行を挟んで本文が続く
setup_layer_tail_blank_then_text() {
  set_t2 "$1" "$T2_HEAD" "$T2_SEP" '| `src/app/` | B | `lint` | 4 | 見本 | 2026-10-16 | c4b6083 |' '' '表の後の本文。'
}
# 表 1 の直後に空行の無い本文が続いても、検査 14 は表 1 を読まないので失敗にしない
setup_layer_t1_tail_text() {
  set_ratings "$1" "$(printf '%s\n' "## 現在の評価" "" "$T1_HEAD" '|---|---|---|---|---|---|' '| 見本 | A | `lint` | 見本 | 2026-10-16 | c4b6083 |' \
    '表 1 の後の本文。' "" "$T2_HEAD" "$T2_SEP" '| `src/app/` | B | `lint` | 1 | 見本 | 2026-10-16 | c4b6083 |')"
}

run_case "層の評価の上限: 本物の表 2" pass "" setup_layer_real
run_case "層の評価の上限: 決まりの数が 0 の層は A でよい" pass "" setup_layer_zero_a
run_case "層の評価の上限: 決まりの数の列の無い表の A は対象にしない" pass "" setup_layer_table1_a
run_case "層の評価の上限: 本物の表 2 で、決まりの数が 4 の層を A にした" fail "表 2（層ごと）の層 \`src/domain/\` の評価が A なのに、人が確かめる決まりの数が 4 です" setup_layer_real_a
run_case "層の評価の上限: 決まりの数が 1 の層を A にした" fail "の層 \`src/app/\` の評価が A なのに、人が確かめる決まりの数が 1 です" setup_layer_one_a
run_case "層の評価の上限: 列の順を変えても見出しの名前で探す" fail "の層 \`src/ui/\` の評価が A なのに、人が確かめる決まりの数が 2 です" setup_layer_reordered
run_case "層の評価の上限: 列の順を変えたとき、決まりの数が 0 の層は失敗にしない" fail "check-docs: 1 件の問題があります" setup_layer_reordered
run_case "層の評価の上限: 決まりの数の列の名前を変えると、黙って通らず失敗する" fail "見出しの行に「人が確かめる決まりの数」の列を持つ表 2 がありません" setup_layer_count_renamed
run_case "層の評価の上限: 評価の列の名前を変えると、黙って通らず失敗する" fail "表 2 の見出しの行に「評価」の列が 0 列あります（1 列のはず）" setup_layer_rating_renamed
run_case "層の評価の上限: 決まりの数が整数でない" fail "の人が確かめる決まりの数「4 つ」が 0 以上の整数ではありません" setup_layer_count_not_integer
run_case "層の評価の上限: 評価が A〜D の 1 字でない" fail "の評価「\`A\`」が A〜D の 1 字ではありません" setup_layer_rating_bad
run_case "層の評価の上限: 行の列の数が見出しと違う" fail "表 2 の行の列の数が 6 です（見出しの行は 7 列）" setup_layer_column_count
run_case "層の評価の上限: 表 2 に行が無い" fail "表 2 に層の行が 1 行もありません" setup_layer_no_rows
run_case "層の評価の上限: 「## 現在の評価」の見出しが無い" fail "「## 現在の評価」の見出しの行がありません" setup_layer_no_section
run_case "層の評価の上限: 表 2 が 2 つある" fail "列を持つ表が 2 個あります（表 2 の 1 個のはず）" setup_layer_two_tables
run_case "層の評価の上限: 節の中のコードブロックは前提の崩れ" fail "「## 現在の評価」の節に、囲みのコードブロックの行（\`\`\` か ~~~）があります" setup_layer_in_code_block
run_case "層の評価の上限: 表 2 の途中の空行で、A の行が別の表になる" fail "表 1 の見出しでも表 2 の見出しでもない表の行があります" setup_layer_split_by_blank
run_case "層の評価の上限: 表 1 の見出しでない、決まりの数の列の無い表" fail "表 1 の見出しでも表 2 の見出しでもない表の行があります" setup_layer_other_table
run_case "層の評価の上限: 決まりの数の列が 2 つある見出し" fail "表 2 の見出しの行に「人が確かめる決まりの数」の列が 2 列あります（1 列のはず）" setup_layer_two_count_columns
run_case "層の評価の上限: 見出しの直後が区切りの行でない" fail "表 2 の見出しの直後の行が、見出しと同じ 7 列の区切りの行（|---|…）ではありません" setup_layer_no_separator
run_case "層の評価の上限: 末尾に空白を付けた同じ名前の節が 2 つ目にある" fail "「## 現在の評価」の見出しの行が 2 行あります（1 行のはず）" setup_layer_second_section_trailing_space
run_case "層の評価の上限: 末尾に空白を付けた見出しの節も読む" fail "の層 \`src/ui/\` の評価が A なのに、人が確かめる決まりの数が 1 です" setup_layer_trailing_space_only
run_case "層の評価の上限: ~~~ のコードブロックの中の \`\`\` の行" fail "「## 現在の評価」の節に、囲みのコードブロックの行（\`\`\` か ~~~）があります: ~~~markdown" setup_layer_tilde_fence
run_case "層の評価の上限: 区切りの行の列の数が足りない" fail "表 2 の見出しの直後の行が、見出しと同じ 7 列の区切りの行（|---|…）ではありません: |---|---|---|" setup_layer_separator_short
run_case "層の評価の上限: 区切りの行の途中のセルが区切りの書式でない" fail "ではありません: |---|X|---|---|---|---|---|" setup_layer_separator_bad_cell
run_case "層の評価の上限: 行の無い表 2 の後に表 1 がある" fail "表 2 に層の行が 1 行もありません" setup_layer_empty_t2_then_t1
run_case "層の評価の上限: 全角空白を付けた見出しの節に表 2 と同じ見出しの表" fail "「## 現在の評価」の節の外に、見出しの行に「人が確かめる決まりの数」の列を持つ表があります" setup_layer_fullwidth_decoy
run_case "層の評価の上限: 別の名前の節に表 2 と同じ見出しの表" fail "「## 現在の評価」の節の外に、見出しの行に「人が確かめる決まりの数」の列を持つ表があります" setup_layer_other_section
run_case "層の評価の上限: 節の外のコードブロックの中の見本の表と見出しは数えない" pass "" setup_layer_sample_in_fence_outside
run_case "層の評価の上限: 最後の 1 行の縦線を外して A にした" fail "$T2_TAIL_ERR: \`src/ui/\` | A |" setup_layer_tail_one_no_pipe_a
run_case "層の評価の上限: 最後の 2 行の縦線を外して A にした" fail "$T2_TAIL_ERR: \`src/ui/\` | A |" setup_layer_tail_two_no_pipe_a
run_case "層の評価の上限: 最後の 1 行の縦線を外し、評価は B のまま" fail "$T2_TAIL_ERR: \`src/ui/\` | B |" setup_layer_tail_one_no_pipe_b
run_case "層の評価の上限: 最後の行の後に改ページだけの行を挟み、縦線の無い A の行" fail "$T2_TAIL_ERR" setup_layer_tail_formfeed_then_a
run_case "層の評価の上限: 表 2 の直後に見出しが続く" fail "$T2_TAIL_ERR: ## 付録" setup_layer_tail_heading
run_case "層の評価の上限: 表 2 の後に空行を挟んで本文が続く" pass "" setup_layer_tail_blank_then_text
run_case "層の評価の上限: 表 1 の直後に空行の無い本文が続いても対象にしない" pass "" setup_layer_t1_tail_text

# 写し T1: check-docs.sh の LAYER_T1_HEADER と、drift-scan.sh の T1_HEADER が同じ文字列である
# （drift-scan.test.sh の試験「写し 1」と同じ形。どちらかで 1 つだけ取り出せないときも失敗にする）
copy_name="写し T1: check-docs.sh の LAYER_T1_HEADER が、drift-scan.sh の T1_HEADER と同じ"
docs_t1="$(sed -n "s/^LAYER_T1_HEADER='\([^']*\)'\$/\1/p" "$CHECK" || true)"
scan_t1="$(sed -n "s/^T1_HEADER='\([^']*\)'\$/\1/p" "$ROOT/scripts/harness/drift-scan.sh" || true)"
if [ -z "$docs_t1" ] || [ "$(printf '%s\n' "$docs_t1" | wc -l | tr -d ' ')" -ne 1 ]; then
  echo "NG: $copy_name（check-docs.sh から LAYER_T1_HEADER を 1 つだけ取り出せない。LAYER_T1_HEADER='...' の 1 行の形を変えたら、この試験の取り出し方も直す）" >&2
  failed=$((failed + 1))
elif [ -z "$scan_t1" ] || [ "$(printf '%s\n' "$scan_t1" | wc -l | tr -d ' ')" -ne 1 ]; then
  echo "NG: $copy_name（drift-scan.sh から T1_HEADER を 1 つだけ取り出せない。T1_HEADER='...' の 1 行の形を変えたら、この試験の取り出し方も直す）" >&2
  failed=$((failed + 1))
elif [ "$docs_t1" != "$scan_t1" ]; then
  echo "NG: $copy_name（文字列が違う。check-docs.sh: $docs_t1／drift-scan.sh: $scan_t1。同じ変更で両方を同じにする）" >&2
  failed=$((failed + 1))
else
  echo "ok: $copy_name"
  passed=$((passed + 1))
fi

total=$((passed + failed))
if [ "$failed" -gt 0 ]; then
  echo "check-docs.test: $total 件中 $failed 件が期待と違います" >&2
  exit 1
fi
echo "check-docs.test: $total 件中 $total 件が期待どおり"
