#!/usr/bin/env bash
# 検査の名前: 通信の名前の一覧
# このプロジェクトだけの文書の検査（追加の検査の口。決まりは同じ置き場の README.md）。文書の検査の本体
# （scripts/harness/check-docs.sh）が、検査する根を作業ディレクトリにして呼ぶ。試験は同じ置き場の network-names.test.sh。
#
# 確かめること（eslint.config.mjs が無いときも失敗にする）:
# - ARCHITECTURE.md の「## 不変条件」の 2 の括弧書き「（`http`、…、`dgram` と、それぞれに `node:` を付けた名前、`undici`）」
#   を、「と、それぞれに `node:` を付けた名前、」の前の名前（node: 付きと無しの両方に展開する）と後の名前に分けて読んだ
#   名前の集まりが、eslint.config.mjs の NETWORK_MODULE_BASES を node: 付きと無しに展開し、NETWORK_MODULES の行の末尾に
#   足した名前を加えた集まりと一致する
# - ARCHITECTURE.md の「## 不変条件」の 1 の「通信のための大域の名前（`fetch`、…、`EventSource`。」の名前の集まりが、
#   eslint.config.mjs の NETWORK_GLOBALS と一致する
# 不変条件の続きの行（字下げした行）は空白 1 つを挟んでつなぎ、連続する空白は 1 つにそろえてから読む（折り返しの位置が
# 空白に来ても読めるようにするため）。``` で囲んだコードブロックの中の行は読まない。
# eslint.config.mjs は実行せず、文字列として読む（この検査は早期通知からも動くので、ほかのファイルを実行しないため）。
# コメントは解析しないので、3 つの定数のそれぞれについて、値を入れる書き方（「名前 =」）がファイル全体（コメントの中を
# 含む）でちょうど 1 か所で、それが行頭から始まる「const 名前 = 」の行であることも確かめる。
# 読み取りの前提（ARCHITECTURE.md の上の書き方と、eslint.config.mjs の 3 つの定数の行の形）が崩れたときは、黙って通さずに失敗にする。
# 終了コード: 0 = 合格、1 = 不合格（「check-docs: NG: 」と「  直し方: 」の組を出す）。
set -euo pipefail
export LC_ALL=C

errors=0
fail() {
  echo "check-docs: NG: $1"
  echo "  直し方: $2"
  errors=$((errors + 1))
}

NET_FIX="通信の名前を足す・外すときは、ARCHITECTURE.md の不変条件（1 は通信のための大域の名前、2 は通信のためのモジュール）と、eslint.config.mjs の NETWORK_GLOBALS、NETWORK_MODULE_BASES（node: 付きと無しの両方に展開される）、NETWORK_MODULES の末尾の名前を、同じ変更で直す"
NET_PREMISE_FIX="書き方を元に戻す。書き方を変えるなら、scripts/harness/checks.d/network-names.sh の読み取りを同じ変更で直す（この検査は決まった書き方を前提に読むので、前提が崩れると一致を確かめられないため）"

# 標準入力の行を「、」でつないで 1 行にする（paste -d は 1 バイトずつの区切りしか扱えないので awk で書く）
join_names() {
  awk 'NR > 1 { printf "、" } { printf "%s", $0 } END { if (NR > 0) printf "\n" }'
}

# ``` で始まる行ごとに、コードブロックの中と外を切り替え、外の行だけを出す
outside_code_blocks() {
  awk '/^```/{inside=!inside; next} !inside' "$1"
}

# 標準入力のタブを空白にし、連続する空白を 1 つにそろえる
squeeze_spaces() {
  tr '\t' ' ' | tr -s ' '
}

# ARCHITECTURE.md の「## 不変条件」の番号 $1 の項目を、続きの行（字下げした行）の先頭の空白を除いて空白 1 つを挟んでつなぎ、
# 連続する空白を 1 つにそろえて 1 行で出す
invariant_text() {
  outside_code_blocks ARCHITECTURE.md | awk -v n="$1" '
    /^## / { on = ($0 == "## 不変条件"); cur = ""; next }
    !on { next }
    /^[0-9]+\. / { cur = substr($0, 1, index($0, ".") - 1); if (cur == n) printf "%s", $0; next }
    /^[[:space:]]+[^[:space:]]/ { if (cur == n) { s = $0; sub(/^[[:space:]]+/, "", s); printf " %s", s }; next }
    { cur = "" }
    END { printf "\n" }' | squeeze_spaces
}

# 「、」で区切った、バッククォートで囲んだ名前の並び $1 から、名前を 1 行ずつ出す。形の違う項目は「BAD<TAB>項目」で出す
backquoted_names() {
  awk '{ n = split($0, a, "、"); for (i = 1; i <= n; i++) { s = a[i]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
    if (s ~ /^`[^`]+`$/) print substr(s, 2, length(s) - 2); else print "BAD\t" s } }' <<<"$1"
}

# JavaScript の配列の中身（"a", "b"）$1 から、名前を 1 行ずつ出す。空の項目は飛ばし、形の違う項目は「BAD<TAB>項目」で出す
quoted_names() {
  awk '{ n = split($0, a, ","); for (i = 1; i <= n; i++) { s = a[i]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); if (s == "") continue
    if (s ~ /^"[^"]+"$/) print substr(s, 2, length(s) - 2); else print "BAD\t" s } }' <<<"$1"
}

# 読み取った名前の並び $2 が空か、形の違う項目を含めば、$1（どこを読んだか）の前提の崩れとして失敗にし、0 を返す
# （読み取れたら 1 を返す）。fail が errors を数えるので、コマンド置換の中では呼ばない
names_unreadable() {
  if [ -z "$2" ]; then
    fail "${1}から、名前を 1 つも読み取れません" "$NET_PREMISE_FIX"
    return 0
  fi
  if grep -q '^BAD	' <<<"$2"; then
    fail "${1}に、名前の形でない項目があります（$(sed -n 's/^BAD	//p' <<<"$2" | join_names)）" "$NET_PREMISE_FIX"
    return 0
  fi
  return 1
}

# $1 = 何の名前か、$2 = ARCHITECTURE.md の名前（1 行 1 つ）、$3 = eslint.config.mjs の名前、$4 = 不変条件の番号、$5 = 定数の名前
compare_name_sets() {
  local only_arch only_eslint
  only_arch="$(grep -vxF -- "$3" <<<"$2" | sort -u | join_names || true)"
  only_eslint="$(grep -vxF -- "$2" <<<"$3" | sort -u | join_names || true)"
  [ -z "$only_arch$only_eslint" ] && return 0
  fail "ARCHITECTURE.md の不変条件 $4 と eslint.config.mjs の $5 で、$1が合いません（ARCHITECTURE.md だけにある: ${only_arch:-なし}。eslint.config.mjs だけにある: ${only_eslint:-なし}）" \
    "2 つを同じ名前の集まりにする。$NET_FIX"
}

# eslint.config.mjs の中で、名前 $1 に値を入れる書き方（「$1 =」。行頭の const の有無、コメントの中かを問わない）が、ちょうど
# 1 か所で、それが行頭から始まる「const $1 = 」の行であることを確かめる。そうでなければ失敗にし、1 を返す。
# JavaScript のコメントを解析せずに、コメントの中に古い 1 行の宣言を残して本物の宣言を複数行にする形を塞ぐため
# （1 行の宣言だけを探すと、コメントの中の古い宣言を拾い、食い違いを見逃す）
single_declaration() {
  local n
  n="$({ grep -oE "(^|[^A-Za-z0-9_\$])$1[[:space:]]*=([^=>]|\$)" eslint.config.mjs || true; } | awk 'END { print NR }')"
  if [ "$n" -ne 1 ] || ! grep -qE "^const $1 = " eslint.config.mjs; then
    fail "eslint.config.mjs に、$1 に値を入れる書き方（「$1 =」。コメントの中を含む）が $n か所あるか、行頭から始まる「const $1 = 」の行ではありません（1 か所で、その形のはず）" \
      "$1 の宣言を、行頭から始まる「const $1 = …;」の 1 行だけにする（コメントの中に古い宣言を残さない）。$NET_PREMISE_FIX"
    return 1
  fi
}

# eslint.config.mjs の定数 $1 の行（「const $1 = [ … ];」の 1 行）の、角括弧の中身を CONST_INNER に入れる。
# ちょうど 1 行でなければ失敗にし、1 を返す（fail が errors を数えるので、コマンド置換の中では呼ばない）
const_inner() {
  local lines n
  CONST_INNER=""
  single_declaration "$1" || return 1
  lines="$(grep -E "^const $1 = \\[.*\\];\$" eslint.config.mjs || true)"
  n="$(printf '%s' "$lines" | awk 'END { print NR }')"
  if [ "$n" -ne 1 ]; then
    fail "eslint.config.mjs に「const $1 = [ … ];」の 1 行が $n 行あります（1 行のはず）" "$NET_PREMISE_FIX"
    return 1
  fi
  CONST_INNER="${lines#*\[}"
  CONST_INNER="${CONST_INNER%\]*}"
}

if [ ! -f eslint.config.mjs ]; then
  fail "eslint.config.mjs がありません（通信の名前の一覧の検査が、通信の名前の一覧を ARCHITECTURE.md と照合できません）" \
    "eslint.config.mjs を戻す。ESLint の設定の置き場を変えたなら、scripts/harness/checks.d/network-names.sh の読み取りを同じ変更で直す"
else
  NET_SEP="$(printf '%s\n' 'と、それぞれに `node:` を付けた名前、' | squeeze_spaces)"
  NET_MODULES_RE='^const NETWORK_MODULES = \[\.\.\.NETWORK_MODULE_BASES\.flatMap\(\(m\) => \[`node:\$\{m\}`, m\]\)(, "[^"]+")*\];$'

  # eslint.config.mjs の側（文字列として読む。実行しない）
  eslint_modules=""
  eslint_globals=""
  if const_inner NETWORK_MODULE_BASES; then
    bases="$(quoted_names "$CONST_INNER")"
    if ! names_unreadable "eslint.config.mjs の NETWORK_MODULE_BASES " "$bases" && single_declaration NETWORK_MODULES; then
      modules_line="$(grep -E '^const NETWORK_MODULES = ' eslint.config.mjs || true)"
      if ! grep -qE "$NET_MODULES_RE" <<<"$modules_line" || [ "$(printf '%s\n' "$modules_line" | awk 'END { print NR }')" -ne 1 ]; then
        fail "eslint.config.mjs の NETWORK_MODULES の行が、「const NETWORK_MODULES = [...NETWORK_MODULE_BASES.flatMap((m) => [\`node:\${m}\`, m]), \"名前\", …];」の 1 行の形ではありません" \
          "$NET_PREMISE_FIX"
      else
        extras_part="${modules_line#*m\]\)}"
        # 末尾の名前は、上の正規表現で「, "名前"」の並びだと確かめてある（無くてもよい）
        extras="$(quoted_names "${extras_part%\];}")"
        eslint_modules="$(printf '%s\n' "$bases" | awk '{ print "node:" $0; print }'; if [ -n "$extras" ]; then printf '%s\n' "$extras"; fi)"
      fi
    fi
  fi
  if const_inner NETWORK_GLOBALS; then
    globals="$(quoted_names "$CONST_INNER")"
    names_unreadable "eslint.config.mjs の NETWORK_GLOBALS " "$globals" || eslint_globals="$globals"
  fi

  # ARCHITECTURE.md の側
  if [ -f ARCHITECTURE.md ]; then
    item2="$(invariant_text 2)"
    rest="${item2#*通信のためのモジュール（}"
    inner="${rest%%）*}"
    if [ "$rest" = "$item2" ] || [ "$inner" = "$rest" ]; then
      fail "ARCHITECTURE.md の「## 不変条件」の 2 に「通信のためのモジュール（…）」の括弧書きがありません" "$NET_PREMISE_FIX"
    else
      case "$inner" in
        *"$NET_SEP"*)
          arch_bases="$(backquoted_names "${inner%%"$NET_SEP"*}")"
          arch_extras="$(backquoted_names "${inner#*"$NET_SEP"}")"
          if ! names_unreadable "ARCHITECTURE.md の不変条件 2 の括弧書きの「$NET_SEP」より前" "$arch_bases" \
            && ! names_unreadable "ARCHITECTURE.md の不変条件 2 の括弧書きの「$NET_SEP」より後" "$arch_extras" \
            && [ -n "$eslint_modules" ]; then
            compare_name_sets "通信のためのモジュール" \
              "$(printf '%s\n' "$arch_bases" | awk '{ print "node:" $0; print }'; printf '%s\n' "$arch_extras")" \
              "$eslint_modules" 2 "NETWORK_MODULES"
          fi
          ;;
        *)
          fail "ARCHITECTURE.md の不変条件 2 の括弧書き「$inner」に「$NET_SEP」がありません（この検査は、この語の前の名前を node: 付きと無しに展開し、後の名前をそのまま足して読む）" \
            "$NET_PREMISE_FIX"
          ;;
      esac
    fi

    item1="$(invariant_text 1)"
    rest="${item1#*通信のための大域の名前（}"
    inner="${rest%%。*}"
    if [ "$rest" = "$item1" ] || [ "$inner" = "$rest" ]; then
      fail "ARCHITECTURE.md の「## 不変条件」の 1 に「通信のための大域の名前（\`fetch\`、…。」の形の並びがありません" "$NET_PREMISE_FIX"
    else
      arch_globals="$(backquoted_names "$inner")"
      if ! names_unreadable "ARCHITECTURE.md の不変条件 1 の通信のための大域の名前の並び" "$arch_globals" && [ -n "$eslint_globals" ]; then
        compare_name_sets "通信のための大域の名前" "$arch_globals" "$eslint_globals" 1 "NETWORK_GLOBALS"
      fi
    fi
  fi
fi

[ "$errors" -eq 0 ] || exit 1
