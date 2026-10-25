#!/usr/bin/env bash
# 検査の名前: 文書の検査の一覧
# このプロジェクトだけの文書の検査（追加の検査の口。決まりは同じ置き場の README.md）。文書の検査の本体
# （scripts/harness/check-docs.sh）が、検査する根を作業ディレクトリにして呼ぶ。試験は同じ置き場の check-list.test.sh。
#
# 確かめること: 文書の検査の一覧（本体の check-docs.sh --print checks が出す名前。本体の 13 個と、この置き場の検査の名前）を、
# 同じ順に「、」でつないだものが、次の 2 か所の括弧書き（バッククォートを除く）と一致する。
# - AGENTS.md の「## 検査のコマンド」の表の、コマンドが `npm run check:docs` の行の 1 列目「文書（…）」
# - docs/QUALITY_SCORE.md の「## 目標」の表の、目標が「文書が実物と合っている」の行の測る項目「文書の検査の不整合（…）」
# どちらのファイルも、無いときは調べない（本体の検査 1 が失敗にする）。
# 終了コード: 0 = 合格、1 = 不合格（「check-docs: NG: 」と「  直し方: 」の組を出す）。
set -euo pipefail
export LC_ALL=C

errors=0
fail() {
  echo "check-docs: NG: $1"
  echo "  直し方: $2"
  errors=$((errors + 1))
}

CHECK_LIST_FIX="文書の検査を足す・外す（scripts/harness/checks.d/ の検査を足す・外すか、検査の本体の写しを新しい版にする）ときは、AGENTS.md の「検査のコマンド」の表の check:docs の行と、docs/QUALITY_SCORE.md の「目標」の表の「文書が実物と合っている」の測る項目の 2 か所を同じ変更で直す（一覧の正本は bash scripts/harness/check-docs.sh --print checks の出力）"

# 標準入力の行を「、」でつないで 1 行にする（paste -d は 1 バイトずつの区切りしか扱えないので awk で書く）
join_names() {
  awk 'NR > 1 { printf "、" } { printf "%s", $0 } END { if (NR > 0) printf "\n" }'
}

if ! expected_names="$(bash "$HARNESS_ENGINE_DIR/check-docs.sh" --print checks)" || [ -z "$expected_names" ]; then
  fail "検査の本体（$HARNESS_ENGINE_DIR/check-docs.sh --print checks）から、文書の検査の一覧を読み取れません" \
    "bash scripts/harness/check-docs.sh --print checks が検査の名前を出すように、検査の本体の写しと scripts/harness/checks.d/ を直す"
  exit 1
fi
expected_list="$(printf '%s\n' "$expected_names" | join_names)"

# $1 = 文書の場所の説明、$2 = 文書から読んだ括弧書き。文書の検査の一覧とバッククォートを除いて比べる
compare_check_list() {
  local where="$1" got="${2//\`/}" got_names missing extra detail
  [ "$got" = "$expected_list" ] && return 0
  got_names="$(printf '%s\n' "$got" | awk '{ n = split($0, a, "、"); for (i = 1; i <= n; i++) print a[i] }')"
  missing="$(grep -vxF -- "$got_names" <<<"$expected_names" | join_names || true)"
  extra="$(grep -vxF -- "$expected_names" <<<"$got_names" | join_names || true)"
  detail=""
  [ -n "$missing" ] && detail="足りない名前: $missing"
  [ -n "$extra" ] && detail="${detail:+$detail。}余分な名前: $extra"
  [ -z "$detail" ] && detail="名前の順か区切りが違います"
  fail "${where}の括弧書き「$got」が、文書の検査の一覧と合いません（$detail）" \
    "括弧書きを「$expected_list」にする（bash scripts/harness/check-docs.sh --print checks の名前を、同じ順に「、」でつなぐ。ファイル名にはバッククォートを付けてよい）。$CHECK_LIST_FIX"
}

# $1 = ファイル、$2 = 節の見出し。節の中の表の行を出す
table_rows_in_section() {
  awk -v sec="$2" '/^## /{ on = ($0 == sec); next } on && /^[[:space:]]*\|/' "$1"
}

# $1 = 表の行、$2 = 列の番号。前後の空白を除いた値を出す
table_cell() {
  awk -F '|' -v k="$(($2 + 1))" '{ c = $k; gsub(/^[[:space:]]+|[[:space:]]+$/, "", c); print c }' <<<"$1"
}

if [ -f AGENTS.md ] && ! grep -qxF '## 検査のコマンド' AGENTS.md; then
  fail "AGENTS.md に「## 検査のコマンド」の見出しの行がありません" \
    "AGENTS.md に、何を確かめるか・コマンドの表を持つ「## 検査のコマンド」の節を置く（見出しを変えると、文書の検査の一覧の検査が check:docs の行を探せないため）。$CHECK_LIST_FIX"
elif [ -f AGENTS.md ]; then
  where='AGENTS.md の「## 検査のコマンド」の表の、コマンドが `npm run check:docs` の行'
  rows="$(table_rows_in_section AGENTS.md '## 検査のコマンド' | awk -F '|' '{ c = $(NF - 1); gsub(/^[[:space:]]+|[[:space:]]+$/, "", c) } c == "`npm run check:docs`"')"
  nrows="$(printf '%s' "$rows" | awk 'END { print NR }')"
  if [ "$nrows" -ne 1 ]; then
    fail "${where}が ${nrows} 行あります（1 行のはず）" \
      "AGENTS.md の「## 検査のコマンド」の表に、「| 文書（…） | \`npm run check:docs\` |」の行をちょうど 1 行置く。$CHECK_LIST_FIX"
  else
    cell="$(table_cell "$rows" 1)"
    case "$cell" in
      文書（*）)
        items="${cell#文書（}"
        compare_check_list "$where" "${items%）}"
        ;;
      *)
        fail "${where}の 1 列目「$cell」が「文書（…）」の形ではありません" \
          "1 列目を「文書（$expected_list）」にする。$CHECK_LIST_FIX"
        ;;
    esac
  fi
fi

if [ -f docs/QUALITY_SCORE.md ] && ! grep -qxF '## 目標' docs/QUALITY_SCORE.md; then
  fail "docs/QUALITY_SCORE.md に「## 目標」の見出しの行がありません" \
    "docs/QUALITY_SCORE.md に、目標・測る項目・確かめ方・検査の識別子の表を持つ「## 目標」の節を置く（見出しを変えると、文書の検査の一覧の検査が測る項目を探せないため）。$CHECK_LIST_FIX"
elif [ -f docs/QUALITY_SCORE.md ]; then
  where='docs/QUALITY_SCORE.md の「## 目標」の表の、目標が「文書が実物と合っている」の行の測る項目'
  rows="$(table_rows_in_section docs/QUALITY_SCORE.md '## 目標' | awk -F '|' '{ c = $2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", c) } c == "文書が実物と合っている"')"
  nrows="$(printf '%s' "$rows" | awk 'END { print NR }')"
  if [ "$nrows" -ne 1 ]; then
    fail "docs/QUALITY_SCORE.md の「## 目標」の表に、目標が「文書が実物と合っている」の行が ${nrows} 行あります（1 行のはず）" \
      "「## 目標」の表に、その目標の行をちょうど 1 行置く。$CHECK_LIST_FIX"
  else
    cell="$(table_cell "$rows" 2)"
    rest="${cell#*文書の検査の不整合（}"
    if [ "$rest" = "$cell" ] || [ "${rest%%）*}" = "$rest" ]; then
      fail "${where}に「文書の検査の不整合（…）」の形の括弧書きがありません" \
        "測る項目を「文書の検査の不整合（$expected_list）と、…」の形にする。$CHECK_LIST_FIX"
    else
      compare_check_list "$where" "${rest%%）*}"
    fi
  fi
fi

[ "$errors" -eq 0 ] || exit 1
