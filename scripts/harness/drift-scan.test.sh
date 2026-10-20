#!/usr/bin/env bash
# 定期の走査（scripts/harness/drift-scan.sh）の試験。
# 手元と CI で同じコマンドを使う: npm run test:harness（check-arch.test.sh の後に動く）
#
# 一時ディレクトリに見本のリポジトリ（git の履歴と、origin にあたる裸のリポジトリを持つ）を作り、drift-scan.sh と
# 本物の .github/workflows/drift-scan.yml と .secretlintrc.json の写しと、node_modules へのリンクを置いて、走査の写しを動かす。
# 見本のファイルはこのファイルの中で作り、リポジトリには置かない（リポジトリのファイルを書き換えないため）。
#
# 走査は、どの場合でも run_scan の 1 か所から呼び、基準の日（DRIFT_SCAN_TEST_TODAY）を必ず付ける。段の差し替え
# （DRIFT_SCAN_TEST_STAGES）も、「段を実際に実行する」場合（run_scan の 1 つめの引数が --real）を除いて必ず付ける。
# 本物の段を実行すると、npm run check の中で npm run check を入れ子に動かすことになるためである。見本の package.json の段は、
# 差し替えが効かずに実行されたら終了コード 97 になるように書いてある。--real の場合だけは、見本の段を exit 0 と exit 1 に
# 書き換えて、走査が段を npm run で実行して終了コードを数えることを確かめる。
# CI の環境変数（GITHUB_ACTIONS など）は外して呼ぶ（この試験は CI の harness の中でも動くため）。
#
# 判定は、報告の中の、印が「要対応」の行の識別子の集合で行う。差し替えを付けると 5/試験の差し替え が必ず要対応に
# なるので、期待する集合には、場合ごとの集合に 5/試験の差し替え を足したものを書く。
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
OUT_DIR=""
OUT=""
RC=0

# 基準の日と、見本の日付（基準の日から数えた日付を、ここに固定で書く）
TODAY="2026-06-15"
D_5="2026-06-10"     # 5 日前
D_10="2026-06-05"    # 10 日前
D_40="2026-05-06"    # 40 日前
D_50="2026-04-26"    # 50 日前
D_100="2026-03-07"   # 100 日前
OVERRIDE_ID="5/試験の差し替え"

tgit() {
  git -c init.defaultBranch=main -c core.fsmonitor=false -c user.name=test -c user.email=test@example.invalid \
    -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"
}

# 見本のファイルを書く（引数: リポジトリの根からの相対のパス、中身の各行）
put() {
  local p="$1"
  shift
  mkdir -p "$(dirname "$SAMPLE/$p")"
  printf '%s\n' "$@" >"$SAMPLE/$p"
}

# 見本の品質目標の文書。引数で、表 1 の「文書が実物と合っている」の行の評価した日と、表 2 の見出しの行を変えられる
QS_T2_HEADER='| 層 | 評価 | 検査の識別子 | 人が確かめる決まりの数 | 根拠 | 評価した日 | 評価したコミット |'
put_quality() {
  local docs_date="$1" extra_row="${2:-}" t2_header="${3:-$QS_T2_HEADER}"
  put docs/QUALITY_SCORE.md \
    '# 品質目標' \
    '' \
    '## 目標' \
    '' \
    '| 目標 | 測る項目 | 確かめ方 | 検査の識別子 |' \
    '|---|---|---|---|' \
    '| 文書が実物と合っている | 不整合の件数 | `npm run check:docs` | `check:docs`, `test:harness` |' \
    '| 秘匿値がリポジトリに無い | 検出の件数 | `npm run check:secrets` | `check:secrets`, `check:secrets:push` |' \
    '| 外部と時刻を差し替えて試験できる | 使用の件数 | `npm run lint` | `lint` |' \
    '' \
    '## 現在の評価' \
    '' \
    '見直しの目安: 90 日' \
    '' \
    '### 表 1 領域ごと' \
    '' \
    '| 領域 | 評価 | 検査の識別子 | 根拠 | 評価した日 | 評価したコミット |' \
    '|---|---|---|---|---|---|' \
    "| 文書が実物と合っている | B | \`check:docs\`, \`test:harness\` | 見本 | $docs_date | 0000000 |" \
    "| 秘匿値がリポジトリに無い | A | \`check:secrets\`, \`check:secrets:push\` | 見本 | $D_10 | 0000000 |" \
    "| 外部と時刻を差し替えて試験できる | C | \`lint\` | 見本 | $D_10 | 0000000 |" \
    ${extra_row:+"$extra_row"} \
    '' \
    '### 表 2 層ごと' \
    '' \
    "$t2_header" \
    '|---|---|---|---|---|---|---|' \
    "| \`src/app/\` | B | \`lint\`, \`test\` | 1 | 見本 | $D_10 | 0000000 |"
}

put_tracker() { # 引数: 一覧の表の行（無ければ表だけ）
  put docs/exec-plans/tech-debt-tracker.md \
    '# 技術的負債の一覧' \
    '' \
    '## 一覧' \
    '' \
    '| 識別子 | 見つけた日 | 場所 | 内容 | 見つけた作業 |' \
    '|---|---|---|---|---|' \
    "$@"
}

# 新しい見本のリポジトリを作る。すべてのファイルを、基準の日の 5 日前のコミットにし、origin（裸のリポジトリ）の main に置く
new_sample() {
  case_no=$((case_no + 1))
  SAMPLE="$TMP_ROOT/sample-$case_no"
  OUT_DIR="$TMP_ROOT/out-$case_no"
  mkdir -p "$SAMPLE/scripts/harness" "$SAMPLE/.github/workflows" "$SAMPLE/src/app" "$SAMPLE/docs/exec-plans/active"
  cp "$ROOT/scripts/harness/drift-scan.sh" "$SAMPLE/scripts/harness/drift-scan.sh"
  cp "$ROOT/.github/workflows/drift-scan.yml" "$SAMPLE/.github/workflows/drift-scan.yml"
  cp "$ROOT/.secretlintrc.json" "$SAMPLE/.secretlintrc.json"
  ln -s "$ROOT/node_modules" "$SAMPLE/node_modules"
  put .gitignore '/node_modules'
  put package.json \
    '{' \
    '  "name": "drift-scan-sample",' \
    '  "private": true,' \
    '  "scripts": {' \
    '    "lint": "exit 97",' \
    '    "test": "exit 97",' \
    '    "check:docs": "exit 97",' \
    '    "test:harness": "exit 97",' \
    '    "check:secrets": "exit 97",' \
    '    "check:secrets:push": "exit 97",' \
    '    "check": "npm run check:secrets && npm run lint && npm run test && npm run check:docs && npm run test:harness"' \
    '  }' \
    '}'
  put AGENTS.md \
    '# 見本' \
    '' \
    '## 文書の地図' \
    '' \
    '| 種類 | パス | 読む条件 |' \
    '|---|---|---|' \
    '| 品質目標 | `docs/QUALITY_SCORE.md` | 見本 |' \
    '| 技術的負債の一覧 | `docs/exec-plans/tech-debt-tracker.md` | 見本 |' \
    '| 定期の走査 | `.github/workflows/drift-scan.yml` | 見本 |' \
    '| 進行中の計画 | `docs/exec-plans/active/` | 見本 |' \
    '' \
    '## 落とし穴'
  put src/app/page.ts 'export const page = 1;'
  put_quality "$D_10"
  put_tracker "| TD-1 | $D_10 | \`src/app/page.ts\` | 見本 | 見本 |"
  : >"$SAMPLE/docs/exec-plans/active/.gitkeep"
}

# 見本をコミットし、origin へ置く。コミットの日付は引数（無ければ 5 日前）
commit_sample() {
  local when="${1:-$D_5}T12:00:00Z"
  tgit -C "$SAMPLE" init -q
  tgit -C "$SAMPLE" add -A
  GIT_AUTHOR_DATE="$when" GIT_COMMITTER_DATE="$when" tgit -C "$SAMPLE" commit -q -m "見本"
  tgit init -q --bare "$SAMPLE.origin.git"
  tgit -C "$SAMPLE" remote add origin "$SAMPLE.origin.git"
  tgit -C "$SAMPLE" push -q origin main
}

# 走査を呼ぶ唯一の場所。引数: 段の差し替え（--real なら差し替えを付けずに段を実行する）、追加の環境変数（「名前=値」を
# 空白で区切る。無ければ空）、走査の引数（無ければ --out <この場合の置き場>。--no-args なら引数なし）
run_scan() {
  local stages="$1" extra="${2:-}"
  local -a envs=()
  shift 2 || shift $#
  if [ "$#" -eq 0 ]; then
    set -- --out "$OUT_DIR"
  elif [ "$1" = "--no-args" ]; then
    set --
  fi
  # ワイルドカードを展開しないよう、read -a で分ける
  [ -z "$extra" ] || read -r -a envs <<<"$extra"
  if [ "$stages" != "--real" ]; then envs=(${envs[@]+"${envs[@]}"} "DRIFT_SCAN_TEST_STAGES=$stages"); fi
  RC=0
  OUT="$(env -u GITHUB_ACTIONS -u GITHUB_EVENT_NAME -u GITHUB_WORKSPACE -u RUNNER_TEMP -u DRIFT_SCAN_RETENTION_DAYS \
    -u HARNESS_TODAY -u DRIFT_SCAN_TEST_STAGES DRIFT_SCAN_TEST_TODAY="$TODAY" ${envs[@]+"${envs[@]}"} \
    bash "$SAMPLE/scripts/harness/drift-scan.sh" "$@" 2>&1)" || RC=$?
}

# 報告の中の、印が「要対応」の行の識別子（並べ替えて 1 行に 1 つ）
attention_ids() {
  awk -F'|' '/^\| `/ {
      id = $2; gsub(/^[ \t]+`|`[ \t]+$/, "", id)
      mark = $(NF - 1); gsub(/^[ \t]+|[ \t]+$/, "", mark)
      if (mark == "要対応") print id
    }' "$OUT_DIR/report.md" | sort
}

ok() {
  passed=$((passed + 1))
  echo "ok: $1"
}

ng() {
  failed=$((failed + 1))
  printf 'NG: %s\n  何が違うか: %s\n  走査の出力:\n%s\n' "$1" "$2" "$OUT" >&2
  if [ -f "$OUT_DIR/report.md" ]; then
    printf '  報告:\n' >&2
    sed 's/^/    /' "$OUT_DIR/report.md" >&2
  fi
}

# 通る場合: 終了コード 0 で、要対応の集合が期待（引数の 2 つめ以降。5/試験の差し替え は自動で足す）と一致し、
# 1 行めの件数が集合の数と一致し、報告に絶対パスの形が無い
expect_attention() {
  local name="$1" want got first
  shift
  want="$( { printf '%s\n' "$OVERRIDE_ID"; [ "$#" -eq 0 ] || printf '%s\n' "$@"; } | sort)"
  if [ "$RC" -ne 0 ] || [ ! -f "$OUT_DIR/report.md" ]; then
    ng "$name" "終了コードが 0 でないか、報告が無い（終了コード $RC）。"
    return
  fi
  got="$(attention_ids)"
  first="$(head -n 1 "$OUT_DIR/report.md")"
  if [ "$got" != "$want" ]; then
    ng "$name" "要対応の集合が違う。期待: $(printf '%s' "$want" | tr '\n' ' ')／実際: $(printf '%s' "$got" | tr '\n' ' ')"
  elif [ "$first" != "走査の結果: 要対応 $(printf '%s\n' "$got" | wc -l | tr -d ' ') 件" ]; then
    ng "$name" "1 行めの件数が、要対応の行の数と合わない（$first）。"
  elif grep -Eq '(^|[^A-Za-z0-9._-])/(home|Users|tmp|private|var|opt|runner)/' "$OUT_DIR/report.md"; then
    ng "$name" "報告に絶対パスの形がある。"
  else
    ok "$name"
  fi
}

# 失敗する場合: 終了コードが期待どおりで、報告が残っていない。出力に期待の文字列がある
expect_exit() {
  local name="$1" want_rc="$2" want_text="$3"
  if [ "$RC" -ne "$want_rc" ]; then
    ng "$name" "終了コードが $want_rc でない（$RC）。"
  elif [ -e "$OUT_DIR/report.md" ]; then
    ng "$name" "失敗したのに報告が残っている。"
  elif ! printf '%s' "$OUT" | grep -qF -- "$want_text"; then
    ng "$name" "出力に「$want_text」が無い。"
  else
    ok "$name"
  fi
}

# 報告のある行の印が期待どおりか
expect_mark() {
  local name="$1" id="$2" want="$3" got
  got="$(awk -F'|' -v want_id="$id" '/^\| `/ {
      id = $2; gsub(/^[ \t]+`|`[ \t]+$/, "", id)
      mark = $(NF - 1); gsub(/^[ \t]+|[ \t]+$/, "", mark)
      if (id == want_id) print mark
    }' "$OUT_DIR/report.md" 2>/dev/null || true)"
  if [ "$got" = "$want" ]; then
    ok "$name"
  else
    ng "$name" "行 $id の印が「$want」でない（実際: 「$got」）。"
  fi
}

# 必須の節がそろった、有効な書式の計画（日付は引数）
put_old_plan() {
  local d="$1"
  put "docs/exec-plans/active/$d-sample.md" \
    '# 見本の計画' '' '## 作業の場所' '' '- ブランチ: `sample`' '' '## 目的' '' '見本。' '' \
    '## 検証（完了の条件）' '' '### V1 見本' '' '- 前提: 見本。' '- 操作: 見本。' '- 期待する結果: 見本。' \
    '- 確かめ方: 自動テスト' '' '## 手順' '' '1. 見本。' '' '## 進捗' '' "- $d: 手順 1 を始めた。" '' \
    '## 発見' '' '## 判断の記録' '' '## 結果と振り返り'
}

# --- 通る場合
new_sample
commit_sample
run_scan ""
expect_attention "通る 1: 計画が 0 件で、段がすべて成功する見本は、要対応が差し替えの行だけ"
expect_mark "通る 1: 試験の差し替えの行は「あり」で要対応" "$OVERRIDE_ID" "要対応"
if grep -qF "| \`5/試験の差し替え\` | あり |" "$OUT_DIR/report.md" && grep -qF "| \`5/契機\` | local |" "$OUT_DIR/report.md" &&
  grep -qF "| \`5/間隔\` | 7 日 |" "$OUT_DIR/report.md"; then
  ok "通る 1: 項目 5 に、差し替え「あり」、契機 local、注釈から読んだ間隔 7 日がある"
else
  ng "通る 1: 項目 5 に、差し替え「あり」、契機 local、注釈から読んだ間隔 7 日がある" "項目 5 の行が期待と違う。"
fi
if grep -qF '| `2/.github/workflows/drift-scan.yml` |' "$OUT_DIR/report.md" && grep -qF '| `1/test:harness` | 0 | 0 | 参考 |' "$OUT_DIR/report.md" &&
  grep -qF '| `3/TD-1` | `src/app/page.ts` | 10 | ある | 1 | 参考 |' "$OUT_DIR/report.md"; then
  ok "通る 1: 項目 1〜3 の行がある（地図のファイル、段、場所のある技術的負債と、見つけた日より後のコミット 1 件）"
else
  ng "通る 1: 項目 1〜3 の行がある（地図のファイル、段、場所のある技術的負債と、見つけた日より後のコミット 1 件）" "項目 1〜3 の行が期待と違う。"
fi

new_sample
put_old_plan "$D_40"
commit_sample
run_scan "check:docs=1"
expect_attention "通る 2: 段の結果だけで決まる（40 日前の計画を置いても、段を差し替えた走査では計画のファイルは結果に影響しない）。check:docs だけを失敗にすると、1/check:docs と、それを識別子に持つ評価 B の行" \
  "1/check:docs" "4/領域:文書が実物と合っている"

new_sample
commit_sample
run_scan "lint=1"
expect_attention "通る 3: lint だけが失敗する見本は、1/lint と、lint を識別子に持つ評価 B の行（評価 C の行は入らない）" \
  "1/lint" "4/層:src/app/"
expect_mark "通る 3: 識別子の段が失敗しても、評価 C の行は要対応にしない" "4/領域:外部と時刻を差し替えて試験できる" "参考"

new_sample
put_tracker "| TD-1 | $D_10 | \`src/app/page.ts\` | 見本 | 見本 |" "| TD-2 | $D_10 | \`src/app/removed.ts\` 3 行 | 見本 | 見本 |"
commit_sample
run_scan ""
expect_attention "通る 4: 場所のファイルが無い技術的負債の行は 3/TD-<n>" "3/TD-2"

new_sample
put_quality "$D_100"
commit_sample
run_scan ""
expect_attention "通る 5: 評価した日が 100 日前の行は、見直しの目安（90 日）を超えて要対応" "4/領域:文書が実物と合っている"

new_sample
put_quality "$D_10" "| 秘匿値の push の範囲 | A | \`check:secrets:push\` | 見本 | $D_10 | 0000000 |"
commit_sample
run_scan ""
expect_attention "通る 6: 識別子が check に無い段（check:secrets:push）だけの行は要対応に入らない"
expect_mark "通る 6: その行の印は「照合しない」" "4/領域:秘匿値の push の範囲" "照合しない"

new_sample
put_quality "$D_10" "" '| 層 | 評価 | 検査の識別子 | 根拠 | 評価した日 | 評価したコミット |'
commit_sample
run_scan ""
expect_attention "通る 7: 表 2 の見出しの行が違う品質目標は 4/表" "4/表"

new_sample
put_quality "$D_10" "| 見本の領域 | B | \`no-such-script\` | 見本 | $D_10 | 0000000 |"
commit_sample
run_scan ""
expect_attention "通る 8: 識別子が scripts に無い行は 4/表" "4/表"

new_sample
put_quality "$D_10" "| 見本の領域 | E | \`lint\` | 見本 | $D_10 | 0000000 |"
commit_sample
run_scan ""
expect_attention "通る 9: 評価が E の行は 4/表" "4/表"

new_sample
put_quality "$D_10" "| 見本の領域 | B | \`lint\` | 見本 | 2026-02-30 | 0000000 |"
commit_sample
run_scan ""
expect_attention "通る 10: 評価した日が暦に無い行は 4/表" "4/表"

new_sample
put_quality "$D_10" "|  \`見本の領域\`  |  B  |  \`lint\` ,\`test\`  |  見本  |  $D_10  |  0000000  |"
commit_sample
run_scan ""
expect_attention "通る 11: セルの前後の空白とバッククォートを除いて読む（読めるので 4/表 にならない）"
expect_mark "通る 11: その行は、空白とバッククォートを除いた名前の識別子になる" "4/領域:見本の領域" "参考"

new_sample
sed 's/npm run test:harness"/npm run test:harness \&\& npm run check:extra"/; s/"lint": "exit 97",/"lint": "exit 97", "check:extra": "exit 97",/' \
  "$SAMPLE/package.json" >"$SAMPLE/package.json.new"
mv "$SAMPLE/package.json.new" "$SAMPLE/package.json"
commit_sample
run_scan "check:extra=3"
expect_attention "通る 12: check に段を 1 つ足すと、その段が項目 1 に現れる（段の一覧を check から読む）" "1/check:extra"

new_sample
commit_sample "$D_50"
run_scan ""
expect_attention "通る 13: origin/main の最後のコミットが 50 日前なら 5/origin-main（45 日以上）" "5/origin-main"

new_sample
sed 's/exit 97/exit 0/g; s/"lint": "exit 0"/"lint": "exit 1"/' "$SAMPLE/package.json" >"$SAMPLE/package.json.new"
mv "$SAMPLE/package.json.new" "$SAMPLE/package.json"
commit_sample
run_scan "--real"
expect_attention "通る 14: 段の差し替えを付けずに見本の段（exit 0 と exit 1）を実際に実行すると、1/lint と lint を識別子に持つ評価 B の行" \
  "1/lint" "4/層:src/app/"

# 実物の品質目標・技術的負債の一覧・AGENTS.md（地図）・package.json を写して、書式を走査が読めることを確かめる
new_sample
for f in docs/QUALITY_SCORE.md docs/exec-plans/tech-debt-tracker.md AGENTS.md package.json; do
  cp "$ROOT/$f" "$SAMPLE/$f"
done
commit_sample
run_scan ""
if [ "$RC" -eq 0 ] && [ -f "$OUT_DIR/report.md" ] && ! grep -qF '| `4/表` |' "$OUT_DIR/report.md" &&
  ! grep -qF '| `3/表` |' "$OUT_DIR/report.md" && ! grep -qF '| 無い（場所を読めない） |' "$OUT_DIR/report.md" &&
  grep -qF '`4/領域:文書が実物と合っている`' "$OUT_DIR/report.md"; then
  ok "通る 15: 実物の品質目標と技術的負債の一覧を、4/表・3/表・場所を読めない行なしで読める"
else
  ng "通る 15: 実物の品質目標と技術的負債の一覧を、4/表・3/表・場所を読めない行なしで読める" \
    "実物の文書の書式を、走査が読めない（終了コード $RC）。文書の書式か、走査の読み方を直す。"
fi

new_sample
: >"$TMP_ROOT/outside-$case_no.ts"
put_tracker "| TD-1 | $D_10 | \`../outside-$case_no.ts\` | 見本 | 見本 |"
commit_sample
run_scan ""
expect_attention "通る 16: 場所が .. を含む行は、git に渡さずに要対応（リポジトリの外のファイルがあっても）" "3/TD-1"
expect_mark "通る 16: その行の印は要対応" "3/TD-1" "要対応"
if grep -qF '無い（リポジトリの外を指す）' "$OUT_DIR/report.md" 2>/dev/null; then
  ok "通る 16: 場所のファイルの欄は「無い（リポジトリの外を指す）」"
else
  ng "通る 16: 場所のファイルの欄は「無い（リポジトリの外を指す）」" "場所のファイルの欄が期待と違う。"
fi

new_sample
: >"$TMP_ROOT/outside-$case_no.md"
put docs/notes.md '# 見本' '' "\`docs/../../outside-$case_no.md\` と \`docs/QUALITY_SCORE.md\`"
put AGENTS.md '# 見本' '' '## 文書の地図' '' '| 種類 | パス | 読む条件 |' '|---|---|---|' \
  '| 見本 | `docs/notes.md` | 見本 |' "| 外 | \`../outside-$case_no.md\` | 見本 |" '| 絶対 | `/srv/sample/a.md` | 見本 |' '' '## 落とし穴'
commit_sample
run_scan ""
expect_attention "通る 17: 地図と文書の中の、.. を含むパスと / で始まるパスは、書かず、git にも渡さない"
if grep -qF '| `2/docs/notes.md` | '"$D_5"' | 1 | 0 | 参考 |' "$OUT_DIR/report.md" 2>/dev/null &&
  ! grep -qF 'outside' "$OUT_DIR/report.md" && ! grep -qF '/srv/' "$OUT_DIR/report.md"; then
  ok "通る 17: 文書の中のパスは、リポジトリの中のものだけを数える"
else
  ng "通る 17: 文書の中のパスは、リポジトリの中のものだけを数える" "リポジトリの外のパスが報告にあるか、数が違う。"
fi

new_sample
put docs/exec-plans/tech-debt-tracker.md '# 技術的負債の一覧' '' '## 一覧' '' '| 識別子 | 日付 | 場所 | 内容 | 見つけた作業 |' \
  '|---|---|---|---|---|' "| TD-1 | $D_10 | \`src/app/page.ts\` | 見本 | 見本 |"
commit_sample
run_scan ""
expect_attention "通る 18: 技術的負債の一覧の見出しの行が違うと 3/表" "3/表"

new_sample
put_tracker "| TD-1 | 2026-02-30 | \`src/app/page.ts\` | 見本 | 見本 |"
commit_sample
run_scan ""
expect_attention "通る 19: 見つけた日が暦に無い行は 3/表（行は日付を読めないとして書く）" "3/表"
expect_mark "通る 19: その行は場所のファイルがあるので参考" "3/TD-1" "参考"

new_sample
put_quality "$D_10" "| 見本<領域> | B | \`lint\` | 見本 | $D_10 | 0000000 |"
commit_sample
run_scan ""
expect_attention "通る 20: 名前のセルに使えない文字がある行は 4/表" "4/表"

# 制御文字（中間のファイルの区切り 0x1f）を名前のセルに入れて、後ろの欄（評価）を書き換えようとする行
US="$(printf '\037')"
new_sample
put_quality "$D_10" "| 見本${US}A${US}lint | C | \`lint\` | 見本 | $D_10 | 0000000 |"
commit_sample
run_scan "lint=1"
expect_attention "通る 21: 名前のセルに区切りの制御文字がある行は読まず 4/表（評価を書き換えられない）" \
  "1/lint" "4/層:src/app/" "4/表"
if grep -q '見本' "$OUT_DIR/report.md" 2>/dev/null; then
  ng "通る 21: 制御文字のある行は報告に書かない" "制御文字のある行の名前が報告にある。"
else
  ok "通る 21: 制御文字のある行は報告に書かない"
fi

new_sample
put_tracker "| TD-1 | $D_10 | \`src/app/page.ts\`${US}x | 見本 | 見本 |"
commit_sample
run_scan ""
expect_attention "通る 22: 技術的負債の行に制御文字があれば読まず 3/表" "3/表"

new_sample
put_quality "$D_10"
grep -v '^|---|---|---|---|---|---|---|$' "$SAMPLE/docs/QUALITY_SCORE.md" >"$SAMPLE/docs/QUALITY_SCORE.md.new"
mv "$SAMPLE/docs/QUALITY_SCORE.md.new" "$SAMPLE/docs/QUALITY_SCORE.md"
commit_sample
run_scan ""
expect_attention "通る 23: 品質目標の表 2 の見出しの直後に区切り行が無ければ 4/表（1 行めを読み飛ばさない）" "4/表"
expect_mark "通る 23: 区切り行の無い表の行は読まない" "4/層:src/app/" ""

new_sample
put docs/exec-plans/tech-debt-tracker.md '# 技術的負債の一覧' '' '## 一覧' '' '| 識別子 | 見つけた日 | 場所 | 内容 | 見つけた作業 |' \
  "| TD-1 | $D_10 | \`src/app/removed.ts\` | 見本 | 見本 |"
commit_sample
run_scan ""
expect_attention "通る 24: 技術的負債の一覧の見出しの直後に区切り行が無ければ 3/表（1 行めを読み飛ばさない）" "3/表"

# シンボリックリンクで、リポジトリの外を指す文書・親ディレクトリ
new_sample
mkdir -p "$TMP_ROOT/outdir-$case_no"
put_outside() { printf '%s\n' '# 外' '`src/app/page.ts`' >"$TMP_ROOT/outdir-$case_no/$1"; }
put_outside a.md
put_outside b.md
ln -s "$TMP_ROOT/outdir-$case_no/b.md" "$SAMPLE/docs/link.md"
ln -s "$TMP_ROOT/outdir-$case_no" "$SAMPLE/docs/linkdir"
put docs/notes.md '# 見本' '' '`docs/linkdir/a.md` と `docs/link.md` と `docs/QUALITY_SCORE.md`'
put AGENTS.md '# 見本' '' '## 文書の地図' '' '| 種類 | パス | 読む条件 |' '|---|---|---|' \
  '| 見本 | `docs/notes.md` | 見本 |' '| リンク | `docs/link.md` | 見本 |' '| 親がリンク | `docs/linkdir/a.md` | 見本 |' '' '## 落とし穴'
put_tracker "| TD-1 | $D_10 | \`docs/linkdir/a.md\` | 見本 | 見本 |" "| TD-2 | $D_10 | \`docs/link.md\` | 見本 | 見本 |"
commit_sample
run_scan ""
expect_attention "通る 25: 実体がリポジトリの外にある場所（リンクと、親ディレクトリのリンク）は、無いとして要対応" "3/TD-1" "3/TD-2"
if grep -qF '| `2/docs/notes.md` | '"$D_5"' | 1 | 0 | 参考 |' "$OUT_DIR/report.md" 2>/dev/null &&
  ! grep -qF '`2/docs/link.md`' "$OUT_DIR/report.md" && ! grep -qF '`2/docs/linkdir/a.md`' "$OUT_DIR/report.md" &&
  [ "$(grep -c '無い（リポジトリの外を指す）' "$OUT_DIR/report.md")" -ge 2 ]; then
  ok "通る 25: 地図の文書が外へのリンクか、親ディレクトリがリンクなら読まず、文書の中のそのパスも数えない"
else
  ng "通る 25: 地図の文書が外へのリンクか、親ディレクトリがリンクなら読まず、文書の中のそのパスも数えない" \
    "リポジトリの外の実体を読んだか、数えた。"
fi

# --- 走査を続けられない場合（終了コード 2）
new_sample
sed 's/^# 間隔の日数: 7$/# 間隔の日数: 1/' "$ROOT/.github/workflows/drift-scan.yml" >"$SAMPLE/.github/workflows/drift-scan.yml"
commit_sample
run_scan ""
expect_exit "続けない 1: ワークフローの注釈の間隔（1 日）と cron（毎週）が合わない" 2 "合いません"

new_sample
commit_sample
run_scan "" "" --no-args
expect_exit "続けない 2: --out が無い" 2 "--out <置き場> がありません"

new_sample
commit_sample
run_scan "" "" --no-such-option
expect_exit "続けない 2b: 知らない引数がある" 2 "知らない引数"

new_sample
commit_sample
run_scan "" "" --out
expect_exit "続けない 3: --out の後に置き場が無い" 2 "置き場を書いて"

new_sample
commit_sample
run_scan "" "GITHUB_ACTIONS=true"
expect_exit "続けない 4: CI の中で、試験の差し替えの環境変数が付いている" 2 "差し替えの環境変数"

new_sample
commit_sample
mkdir -p "$OUT_DIR"
: >"$OUT_DIR/old.md"
run_scan ""
if [ "$RC" -eq 2 ] && [ ! -e "$OUT_DIR/report.md" ] && [ -e "$OUT_DIR/old.md" ]; then
  ok "続けない 5: --out の置き場が空でない（ほかのファイルを消さず、報告も書かない）"
else
  ng "続けない 5: --out の置き場が空でない（ほかのファイルを消さず、報告も書かない）" "終了コードが 2 でないか、置き場の中身が変わった（終了コード $RC）。"
fi

# --- 公開してよいかの検査に通らない場合（終了コード 3）。どれも、技術的負債の行の場所から報告に入る
OTHER_TMP="$(mktemp -d)"
OTHER_TMP="$(cd "$OTHER_TMP" && pwd -P)"
: >"$OTHER_TMP/file.ts"
new_sample
put_tracker "| TD-1 | $D_10 | \`$OTHER_TMP/file.ts\` | 見本 | 見本 |"
commit_sample
run_scan ""
rm -rf "$OTHER_TMP"
expect_exit "公開しない 1: 技術的負債の場所に、別の一時ディレクトリの絶対パスがある" 3 "絶対パスの形"

# メールアドレスの形は、報告に書く値の文字の検査（@ を許さない）で先に落ちるので、報告に入らないことを確かめる
new_sample
put_tracker "| TD-1 | $D_10 | \`docs/someone$(printf '@')example.com\` | 見本 | 見本 |"
commit_sample
run_scan ""
expect_attention "書かない 1: メールアドレスの形の場所は書かず、「無い（場所を読めない）」にする" "3/TD-1"
if grep -qF '| `3/TD-1` | `-` |' "$OUT_DIR/report.md" 2>/dev/null && ! grep -qF '@' "$OUT_DIR/report.md"; then
  ok "書かない 1: 報告に @ が無く、場所は - と書く"
else
  ng "書かない 1: 報告に @ が無く、場所は - と書く" "場所の値が報告に書かれている。"
fi

new_sample
commit_sample
put_tracker "| TD-1 | $D_10 | \`/srv/sample/file.ts\` | 見本 | 見本 |"
run_scan ""
expect_exit "公開しない 2: 接頭辞の一覧に無い絶対パスでも、表の値が / で始まれば公開しない" 3 "表の値が / か ~ で始まる"

# 模擬の秘匿値（本物でない。secretlint の GitHub のトークンの規則に当たる形）は、検査が試験のファイルを止めないよう、
# 実行のときに組み立てる
FAKE_TOKEN="gh""p_$(printf 'a1B2c3D4e5%.0s' 1 2 3)a1B2c3"
new_sample
put_tracker "| TD-1 | $D_10 | \`docs/$FAKE_TOKEN.md\` | 見本 | 見本 |"
commit_sample
run_scan ""
expect_exit "公開しない 3: secretlint の規則に当たる模擬の秘匿値がある" 3 "secretlint の規則に当たる値"
if printf '%s' "$OUT" | grep -qF "$FAKE_TOKEN"; then
  ng "公開しない 3: 出力に値を出さない" "標準エラーに、当たった値が出ている。"
else
  ok "公開しない 3: 出力に値を出さない"
fi

# --- 写しの一致。走査の CHECK7_RE は、check-docs.sh の検査 7（ARCHITECTURE.md に書いたパス）の正規表現の写しなので、
# 2 つのファイルから正規表現の文字列を取り出して比べる。どちらかで取り出せない（該当の行が 1 行でない、または空）ときも失敗にする
# 比べるのは正規表現の文字列だけで、その前後の取り出し方（バッククォートの中身を取り出す部分）の違いは比べない
OUT=""
OUT_DIR="$TMP_ROOT/no-report"
name="写し 1: drift-scan.sh の CHECK7_RE が、check-docs.sh の検査 7 の正規表現と同じ"
docs_re_lines="$(grep -F 'ARCHITECTURE.md | tr -d' "$ROOT/scripts/harness/check-docs.sh" |
  sed -n "s/^.*| grep -E '\([^']*\)' || true)\$/\1/p" || true)"
scan_re_lines="$(sed -n "s/^CHECK7_RE='\([^']*\)'\$/\1/p" "$ROOT/scripts/harness/drift-scan.sh" || true)"
if [ -z "$docs_re_lines" ] || [ "$(printf '%s\n' "$docs_re_lines" | wc -l | tr -d ' ')" -ne 1 ]; then
  ng "$name" "check-docs.sh から検査 7 の正規表現を 1 つだけ取り出せない（取り出せないか、2 つ以上ある）。検査 7 の行の形を変えたら、この試験の取り出し方も直す。"
elif [ -z "$scan_re_lines" ] || [ "$(printf '%s\n' "$scan_re_lines" | wc -l | tr -d ' ')" -ne 1 ]; then
  ng "$name" "drift-scan.sh から CHECK7_RE を 1 つだけ取り出せない（取り出せないか、2 つ以上ある）。CHECK7_RE='...' の 1 行の形を変えたら、この試験の取り出し方も直す。"
elif [ "$docs_re_lines" != "$scan_re_lines" ]; then
  ng "$name" "正規表現が違う。check-docs.sh: $docs_re_lines／drift-scan.sh: $scan_re_lines。同じ変更で両方を同じにする（どちらの注記にも、写しがあることを書いてある）。"
else
  ok "$name"
fi

total=$((passed + failed))
if [ "$failed" -gt 0 ]; then
  echo "drift-scan.test: $total 件中 $failed 件が期待と違います" >&2
  exit 1
fi
echo "drift-scan.test: $total 件中 $total 件が期待どおり"
