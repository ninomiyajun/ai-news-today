#!/usr/bin/env bash
# check-docs.sh の試験（検査 8、検査 9: 受け入れ確認の記録、検査 10: 製品の仕様）。手元と CI で同じコマンドを使う:
# npm run test:harness
#
# 場合ごとに、一時ディレクトリに小さなリポジトリ（git init だけ。コミットはしない）を作り、check-docs.sh の写しと
# 本物の docs/PLANS.md の写し（検査 10 の場合は本物の docs/product-specs/README.md の写しも）を置いて、計画・記録・仕様の
# 組を変えて動かす。終了コードと、失敗のときは理由の文言を確かめる。
# 計画・記録・仕様の見本はこのファイルの中で作り、リポジトリに Markdown の見本を置かない（検査 4、8、10 が見本を拾うため）。
# 仕様の見本の題材は、アプリの実際の機能と関係の無い架空の機能（一覧の文字の大きさの切り替え）にする。
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

# 書式の文書（$1）の「## 必須の節」から、必須の見出しを 1 行ずつ出す
required_headings() {
  awk '/^## 必須の節$/{on=1; next} /^## /{on=0} on' "$1" | sed -n 's/^[0-9][0-9]*\. `\(## [^`]*\)`.*$/\1/p'
}

# 計画を書く。$1 = パス、$2 = 検証の節の本文、$3 = 目的の節の本文（省略可）。必須の節の見出しは本物の docs/PLANS.md から読む
write_plan() {
  local path="$1" verification="$2" purpose="${3:-}" heading
  {
    printf '# 試験の計画\n\n'
    required_headings "$PLANS" | while IFS= read -r heading; do
      printf '%s\n\n' "$heading"
      if [ "$heading" = "## 検証（完了の条件）" ]; then
        printf '%s\n\n' "$verification"
      elif [ "$heading" = "## 目的" ] && [ -n "$purpose" ]; then
        printf '%s\n\n' "$purpose"
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

total=$((passed + failed))
if [ "$failed" -gt 0 ]; then
  echo "check-docs.test: $total 件中 $failed 件が期待と違います" >&2
  exit 1
fi
echo "check-docs.test: $total 件中 $total 件が期待どおり"
