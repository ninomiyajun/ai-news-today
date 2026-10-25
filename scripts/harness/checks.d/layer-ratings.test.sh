#!/usr/bin/env bash
# 追加の検査 layer-ratings.sh（層の評価の上限）の試験。文書の検査の試験（scripts/harness/check-docs.test.sh）が最後に流す。
# 単独では次で動かす: bash scripts/harness/checks.d/layer-ratings.test.sh
#
# 受け持てない形（レビューで人が確かめる）:
# - 人が確かめる決まりの数そのものが正しいか（docs/QUALITY_SCORE.md の決まり 1〜4 の対象と、層ごとの数が合っているか）は
#   確かめない。数を 0 と書けば A にできるので、数を直す変更はレビューで人が確かめる
# - 表 1（領域ごと）の評価と、評価と根拠の文章が合っているかは確かめない
# - セルの中に「\|」（表の区切りでない縦線）を書くと、列の数が見出しと合わず、前提の崩れとして失敗する（誤検知だが、
#   すり抜けではなく失敗する側に倒れる。scripts/harness/drift-scan.sh も同じく列の数の違いとして扱う）
#
# 場合ごとに、一時ディレクトリに docs/QUALITY_SCORE.md だけを置き、本体と同じ呼び方（作業ディレクトリを検査する根にし、
# HARNESS_ROOT と HARNESS_ENGINE_DIR を渡す）で layer-ratings.sh を動かす。終了コードと、失敗のときは理由の文言を確かめる。
set -euo pipefail
export LC_ALL=C

H="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ENGINE="$(cd "$H/.." && pwd -P)"
ROOT="$(cd "$H/../../.." && pwd -P)"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

passed=0
failed=0

# 検査を通る最小の表 2（層は 1 つ。見出しの行は本物と同じ）
MIN_RATINGS='## 現在の評価

| 層 | 評価 | 検査の識別子 | 人が確かめる決まりの数 | 根拠 | 評価した日 | 評価したコミット |
|---|---|---|---|---|---|---|
| `src/app/` | B | `lint` | 1 | 試験の見本 | 2026-10-16 | c4b6083 |'

# 本物の docs/QUALITY_SCORE.md の「## 現在の評価」の節（見出しから末尾まで）を写して使う（表 2 の書き方を試験に二重に持たないため）
REAL_RATINGS="$(awk '/^## /{ on = ($0 == "## 現在の評価") } on' "$ROOT/docs/QUALITY_SCORE.md")"
if ! grep -qF '| `src/domain/` | B |' <<<"$REAL_RATINGS"; then
  echo "layer-ratings.test: NG: 本物の docs/QUALITY_SCORE.md の「## 現在の評価」から、表 2 の層 src/domain/ の行を読み取れません" >&2
  exit 1
fi

# docs/QUALITY_SCORE.md を書く。$1 = 根、$2 = 「## 現在の評価」の節。「## 目標」の表は、表 2 と列の違う表の見本として置く
write_quality() {
  printf '%s\n' "# 品質目標" "" "## 目標" "" "| 目標 | 測る項目 | 確かめ方 | 検査の識別子 |" "|---|---|---|---|" \
    "| 見本 | 見本 | 見本 | \`lint\` |" "" "$2" > "$1/docs/QUALITY_SCORE.md"
}

# 場合を 1 つ動かす。$1 = 名前、$2 = 期待（pass / fail）、$3 = 失敗のときに出力に含まれるべき文言、$4 = 準備の関数、
# $5 = 失敗のときの「check-docs: NG: 」の行の数（省略時は数えない）
run_case() {
  local name="$1" expect="$2" want="$3" setup="$4" want_ng="${5:-}" d out rc ng
  d="$TMP_ROOT/case-$((passed + failed + 1))"
  mkdir -p "$d/docs"
  write_quality "$d" "$MIN_RATINGS"
  "$setup" "$d"
  set +e
  out="$(cd "$d" && HARNESS_ROOT="$d" HARNESS_ENGINE_DIR="$ENGINE" bash "$H/layer-ratings.sh" </dev/null 2>&1)"
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

# 文字列 $1 の中の、最初の $2 を $3 に置き換える。$2 が無ければそのまま出す（失敗を期待する場合が通り、試験が NG を出す）
replace_once() {
  awk -v from="$2" -v to="$3" 'BEGIN { RS = "\001" } { i = index($0, from); if (i) $0 = substr($0, 1, i - 1) to substr($0, i + length(from)); printf "%s", $0 }' <<<"$1"
}

T2_HEAD='| 層 | 評価 | 検査の識別子 | 人が確かめる決まりの数 | 根拠 | 評価した日 | 評価したコミット |'
T2_SEP='|---|---|---|---|---|---|---|'
T1_HEAD='| 領域 | 評価 | 検査の識別子 | 根拠 | 評価した日 | 評価したコミット |'

# 「## 現在の評価」の節を $2 にした docs/QUALITY_SCORE.md を書く。$1 = リポジトリ
set_ratings() { write_quality "$1" "$2"; }
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
# 表 1 の直後に空行の無い本文が続いても、この検査は表 1 を読まないので失敗にしない
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
run_case "層の評価の上限: 列の順を変えたとき、決まりの数が 0 の層は失敗にしない" fail "check-docs: NG: " setup_layer_reordered 1
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

total=$((passed + failed))
if [ "$failed" -gt 0 ]; then
  echo "layer-ratings.test: $total 件中 $failed 件が期待と違います" >&2
  exit 1
fi
echo "layer-ratings.test: $total 件中 $total 件が期待どおり"
