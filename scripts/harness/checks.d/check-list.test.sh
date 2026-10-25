#!/usr/bin/env bash
# 追加の検査 check-list.sh（文書の検査の一覧）の試験。文書の検査の試験（scripts/harness/check-docs.test.sh）が最後に流す。
# 単独では次で動かす: bash scripts/harness/checks.d/check-list.test.sh
#
# 受け持てない形（レビューで人が確かめる）:
# - 名前が検査の中身を正しく言い表しているか、と、ほかの文書に書いた検査の一覧（いまは無い）
# - 検査の本体の注釈の番号と、本体が --print checks で出す名前の数が合っているか（本体は規約の正本の写しなので、正本の側の
#   試験が受け持つ）
#
# 場合ごとに、一時ディレクトリに AGENTS.md と docs/QUALITY_SCORE.md だけを置き、本体と同じ呼び方（作業ディレクトリを
# 検査する根にし、HARNESS_ROOT と HARNESS_ENGINE_DIR を渡す）で check-list.sh を動かす。名前の一覧は、本物の検査の本体の
# --print checks から読む。終了コードと、失敗のときは理由の文言を確かめる。
set -euo pipefail
export LC_ALL=C

H="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ENGINE="$(cd "$H/.." && pwd -P)"
ROOT="$(cd "$H/../../.." && pwd -P)"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

passed=0
failed=0

# 検査の対象の行。本物の AGENTS.md の check:docs の行と、本物の docs/QUALITY_SCORE.md の目標「文書が実物と合っている」の
# 行を写して使う（名前の一覧を試験に二重に持たないため）
AGENTS_DOCS_ROW="$(awk '/^## /{ on = ($0 == "## 検査のコマンド"); next } on && index($0, "| `npm run check:docs` |")' "$ROOT/AGENTS.md")"
QUALITY_DOCS_ROW="$(awk '/^## /{ on = ($0 == "## 目標"); next } on && index($0, "| 文書が実物と合っている |") == 1' "$ROOT/docs/QUALITY_SCORE.md")"
if [ -z "$AGENTS_DOCS_ROW" ] || [ -z "$QUALITY_DOCS_ROW" ]; then
  echo "check-list.test: NG: 本物の AGENTS.md か docs/QUALITY_SCORE.md から、検査の対象の行を読み取れません" >&2
  exit 1
fi

# AGENTS.md を書く。$1 = 根、$2 = 「## 検査のコマンド」の表の行
write_agents() {
  printf '%s\n' "# 試験" "" "## 検査のコマンド" "" "| 何を確かめるか | コマンド |" "|---|---|" "$2" > "$1/AGENTS.md"
}

# docs/QUALITY_SCORE.md を書く。$1 = 根、$2 = 「## 目標」の表の行
write_quality() {
  printf '%s\n' "# 品質目標" "" "## 目標" "" "| 目標 | 測る項目 | 確かめ方 | 検査の識別子 |" "|---|---|---|---|" "$2" > "$1/docs/QUALITY_SCORE.md"
}

# 2 つの文書の対象の行を書き換える。$1 = 根、$2 = AGENTS.md の行、$3 = docs/QUALITY_SCORE.md の行
add_check_list_docs() {
  write_agents "$1" "$2"
  write_quality "$1" "$3"
}

# 場合を 1 つ動かす。$1 = 名前、$2 = 期待（pass / fail）、$3 = 失敗のときに出力に含まれるべき文言、$4 = 準備の関数、
# $5 = 失敗のときの「check-docs: NG: 」の行の数（省略時は数えない）
run_case() {
  local name="$1" expect="$2" want="$3" setup="$4" want_ng="${5:-}" d out rc ng
  d="$TMP_ROOT/case-$((passed + failed + 1))"
  mkdir -p "$d/docs"
  add_check_list_docs "$d" "$AGENTS_DOCS_ROW" "$QUALITY_DOCS_ROW"
  "$setup" "$d"
  set +e
  out="$(cd "$d" && HARNESS_ROOT="$d" HARNESS_ENGINE_DIR="$ENGINE" bash "$H/check-list.sh" </dev/null 2>&1)"
  rc=$?
  set -e
  ng="$(grep -c '^check-docs: NG: ' <<<"$out" || true)"
  if [ "$expect" = pass ] && [ "$rc" -eq 0 ]; then
    echo "ok: $name（通る）"
    passed=$((passed + 1))
  elif [ "$expect" = fail ] && [ "$rc" -eq 1 ] && grep -qF -- "$want" <<<"$out" && { [ -z "$want_ng" ] || [ "$ng" = "$want_ng" ]; }; then
    echo "ok: $name（失敗する: $want${want_ng:+。NG は $want_ng 件}）"
    passed=$((passed + 1))
  else
    echo "NG: $name（期待: $expect${want_ng:+、NG は $want_ng 件}、終了コード: $rc、NG は $ng 件）" >&2
    printf '%s\n' "$out" | sed 's/^/    /' >&2
    failed=$((failed + 1))
  fi
}

# 本体の検査の名前は書き込まず、本体の --print checks の出力から位置で選ぶ（写しの版が変わって名前が変わっても、試験の
# 意図を保つため）。選ぶのは、末尾、中ほど、7 番目（本体の検査 7。ファイル名を含む名前で、docs/QUALITY_SCORE.md では
# ファイル名をバッククォートで囲む）、2 番目と 3 番目
CHECK_NAMES_OUT="$(bash "$ENGINE/check-docs.sh" --print checks)"
n_names="$(printf '%s\n' "$CHECK_NAMES_OUT" | awk 'END { print NR }')"
if [ "$n_names" -lt 7 ]; then
  echo "check-list.test: NG: 本体の --print checks の名前が $n_names 個です（7 個以上のはず）" >&2
  exit 1
fi
name_at() { printf '%s\n' "$CHECK_NAMES_OUT" | sed -n "${1}p"; }
NAME_LAST="$(name_at "$n_names")"
NAME_MID="$(name_at "$(( (n_names + 1) / 2 ))")"
NAME_7="$(name_at 7)"
NAME_2="$(name_at 2)"
NAME_3="$(name_at 3)"

# 行 $1 から、名前 $2 を、前の「、」とともに消す。そのままの形で見つからなければ、先頭の語（ファイル名）をバッククォートで
# 囲んだ形でも探す。どちらも見つからなければ行をそのまま出す（失敗を期待する場合が通り、試験が NG を出す）
drop_name() {
  local quoted
  quoted="$(awk '{ i = index($0, " "); if (i) print "`" substr($0, 1, i - 1) "`" substr($0, i); else print "`" $0 "`" }' <<<"$2")"
  awk -v s="、$2" -v q="、$quoted" '{ i = index($0, s); n = length(s); if (!i) { i = index($0, q); n = length(q) }
    if (i) $0 = substr($0, 1, i - 1) substr($0, i + n); print }' <<<"$1"
}

setup_list_correct() { add_check_list_docs "$1" "$AGENTS_DOCS_ROW" "$QUALITY_DOCS_ROW"; }
# 出どころ 1 の形（TD-4）: docs/QUALITY_SCORE.md の測る項目だけが狭い
setup_list_quality_narrow() {
  add_check_list_docs "$1" "$AGENTS_DOCS_ROW" "$(drop_name "$QUALITY_DOCS_ROW" "$NAME_LAST")"
}
# AGENTS.md の表の行だけが狭い
setup_list_agents_narrow() {
  add_check_list_docs "$1" "$(drop_name "$AGENTS_DOCS_ROW" "$NAME_MID")" "$QUALITY_DOCS_ROW"
}
# 出どころ 2 の形（PR #38）: 2 つの文書がそろって検査 7 の名前を欠く（2 つを比べるだけでは見つからない）
setup_list_both_missing_check7() {
  add_check_list_docs "$1" "$(drop_name "$AGENTS_DOCS_ROW" "$NAME_7")" "$(drop_name "$QUALITY_DOCS_ROW" "$NAME_7")"
}
# 名前はそろっているが順が違う（2 番目と 3 番目を入れ替える）
setup_list_order() {
  local row
  row="$(awk -v a="$NAME_2、$NAME_3" -v b="$NAME_3、$NAME_2" '{ i = index($0, a); if (i) $0 = substr($0, 1, i - 1) b substr($0, i + length(a)); print }' <<<"$AGENTS_DOCS_ROW")"
  add_check_list_docs "$1" "$row" "$QUALITY_DOCS_ROW"
}
# 節はあるのに、check:docs の行が無い
setup_list_agents_row_missing() {
  add_check_list_docs "$1" "| 試験 | \`npm run test\` |" "$QUALITY_DOCS_ROW"
}

run_case "文書の検査の一覧: 本物の 2 つの行（バッククォートの有無は問わない）" pass "" setup_list_correct
run_case "文書の検査の一覧: docs/QUALITY_SCORE.md の測る項目だけが狭い" fail "docs/QUALITY_SCORE.md の「## 目標」の表の、目標が「文書が実物と合っている」の行の測る項目の括弧書き" setup_list_quality_narrow
run_case "文書の検査の一覧: 欠けた名前を示す" fail "が、文書の検査の一覧と合いません（足りない名前: $NAME_LAST）" setup_list_quality_narrow
run_case "文書の検査の一覧: AGENTS.md の表の行だけが狭い" fail "AGENTS.md の「## 検査のコマンド」の表の、コマンドが \`npm run check:docs\` の行の括弧書き" setup_list_agents_narrow
run_case "文書の検査の一覧: 2 つの文書がそろって検査 7 を欠く" fail "check-docs: NG: " setup_list_both_missing_check7 2
run_case "文書の検査の一覧: 2 つの文書がそろって欠けた名前を示す" fail "（足りない名前: $NAME_7）" setup_list_both_missing_check7
run_case "文書の検査の一覧: 名前の順が違う" fail "（名前の順か区切りが違います）" setup_list_order
run_case "文書の検査の一覧: 節はあるのに check:docs の行が無い" fail "\`npm run check:docs\` の行が 0 行あります（1 行のはず）" setup_list_agents_row_missing

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

total=$((passed + failed))
if [ "$failed" -gt 0 ]; then
  echo "check-list.test: $total 件中 $failed 件が期待と違います" >&2
  exit 1
fi
echo "check-list.test: $total 件中 $total 件が期待どおり"
