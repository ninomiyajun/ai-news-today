#!/usr/bin/env bash
# check-docs.sh の試験（検査 8 と検査 9: 受け入れ確認の記録）。手元と CI で同じコマンドを使う: npm run test:harness
#
# 場合ごとに、一時ディレクトリに小さなリポジトリ（git init だけ。コミットはしない）を作り、check-docs.sh の写しと
# 本物の docs/PLANS.md の写しを置いて、計画と記録の組を変えて動かす。終了コードと、失敗のときは理由の文言を確かめる。
# 計画と記録の見本はこのファイルの中で作り、リポジトリに Markdown の見本を置かない（検査 4 と検査 8 が見本を拾うため）。
set -euo pipefail
export LC_ALL=C

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHECK="$ROOT/scripts/harness/check-docs.sh"
PLANS="$ROOT/docs/PLANS.md"

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

passed=0
failed=0

# 検査 1〜7 を通る最小のリポジトリを作る
make_base() {
  local d="$1" p
  mkdir -p "$d/docs/adr" "$d/docs/exec-plans/active" "$d/docs/exec-plans/completed" \
    "$d/docs/quality-eval/tasks" "$d/docs/quality-eval/results" "$d/scripts/harness" "$d/.github/workflows"
  cp "$CHECK" "$d/scripts/harness/check-docs.sh"
  cp "$PLANS" "$d/docs/PLANS.md"
  printf '%s\n' "# 試験" "" "ハーネスの版: 1" "" "## 文書の地図" "" "| 種類 | パス |" "|---|---|" "| 計画の書式 | \`docs/PLANS.md\` |" > "$d/AGENTS.md"
  printf '@AGENTS.md\n' > "$d/CLAUDE.md"
  printf '# ARCHITECTURE\n' > "$d/ARCHITECTURE.md"
  printf '# ADR\n' > "$d/docs/adr/README.md"
  for p in .gitignore docs/QUALITY_SCORE.md docs/quality-eval/README.md scripts/harness/check-arch.sh \
    scripts/harness/check-secrets.sh scripts/harness/check-secrets.mjs .dependency-cruiser.cjs .secretlintrc.json \
    .github/workflows/harness.yml .github/dependabot.yml; do
    : > "$d/$p"
  done
  git -C "$d" init -q
}

# 計画を書く。$1 = パス、$2 = 検証の節の本文。必須の節の見出しは本物の docs/PLANS.md から読む
write_plan() {
  local path="$1" verification="$2" heading
  {
    printf '# 試験の計画\n\n'
    awk '/^## 必須の節$/{on=1; next} /^## /{on=0} on' "$PLANS" | sed -n 's/^[0-9][0-9]*\. `\(## [^`]*\)`.*$/\1/p' \
      | while IFS= read -r heading; do
          printf '%s\n\n' "$heading"
          if [ "$heading" = "## 検証（完了の条件）" ]; then
            printf '%s\n\n' "$verification"
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

# 場合を 1 つ動かす。$1 = 名前、$2 = 期待（pass / fail）、$3 = 失敗のときに出力に含まれるべき文言、$4 = 準備の関数
run_case() {
  local name="$1" expect="$2" want="$3" setup="$4" d out rc
  d="$TMP_ROOT/case-$((passed + failed + 1))"
  make_base "$d"
  "$setup" "$d"
  set +e
  out="$(bash "$d/scripts/harness/check-docs.sh" 2>&1)"
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

total=$((passed + failed))
if [ "$failed" -gt 0 ]; then
  echo "check-docs.test: $total 件中 $failed 件が期待と違います" >&2
  exit 1
fi
echo "check-docs.test: $total 件中 $total 件が期待どおり"
