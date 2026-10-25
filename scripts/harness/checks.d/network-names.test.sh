#!/usr/bin/env bash
# 追加の検査 network-names.sh（通信の名前の一覧）の試験。文書の検査の試験（scripts/harness/check-docs.test.sh）が最後に流す。
# 単独では次で動かす: bash scripts/harness/checks.d/network-names.test.sh
#
# 読み取りの前提と、受け持てない形:
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
# 場合ごとに、一時ディレクトリに ARCHITECTURE.md と eslint.config.mjs だけを置き、本体と同じ呼び方（作業ディレクトリを
# 検査する根にし、HARNESS_ROOT と HARNESS_ENGINE_DIR を渡す）で network-names.sh を動かす。終了コードと、失敗のときは
# 理由の文言を確かめる。
set -euo pipefail
export LC_ALL=C

H="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ENGINE="$(cd "$H/.." && pwd -P)"
ROOT="$(cd "$H/../../.." && pwd -P)"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

passed=0
failed=0

# 検査を通る最小の不変条件と ESLint の設定（名前は 1 つずつ。読み取りの形は本物と同じ）
MIN_INVARIANTS='## 不変条件

1. 通信のための大域の名前（`fetch`。試験の見本）は、決まった層の外で使わない。
2. 通信のためのモジュール（`http` と、それぞれに `node:` を付けた名前、`undici`）は、決まった層の外で import しない。'
MIN_NET_CONSTS='const NETWORK_MODULE_BASES = ["http"];
const NETWORK_MODULES = [...NETWORK_MODULE_BASES.flatMap((m) => [`node:${m}`, m]), "undici"];
const NETWORK_GLOBALS = ["fetch"];'

# 本物の ARCHITECTURE.md の「## 不変条件」の 1 と 2（見出しから 3 の前まで）と、本物の eslint.config.mjs の 3 つの定数の行を
# 写して使う（読み取りの前提の書き方を、試験に二重に持たないため）
# 節の冒頭の注記（この検査が読み取ることの説明。同じ言い回しを含む）は写さず、見出しと 1・2 の項目だけを写す
REAL_INVARIANTS="$(awk '/^## /{ on = ($0 == "## 不変条件"); if (on) print; next } on && /^1\. /{ items = 1 } on && /^3\. /{ exit } on && items' "$ROOT/ARCHITECTURE.md")"
REAL_NET_CONSTS="$(grep -E '^const NETWORK_(MODULE_BASES|MODULES|GLOBALS) = ' "$ROOT/eslint.config.mjs" || true)"
if [ -z "$REAL_INVARIANTS" ] || [ "$(printf '%s\n' "$REAL_NET_CONSTS" | awk 'END { print NR }')" -ne 3 ]; then
  echo "network-names.test: NG: 本物の ARCHITECTURE.md の不変条件か、eslint.config.mjs の 3 つの定数の行を読み取れません" >&2
  exit 1
fi

# $1 = 根、$2 = 不変条件の節、$3 = eslint.config.mjs の中身
add_net_files() {
  printf '%s\n' "# ARCHITECTURE" "" "$2" > "$1/ARCHITECTURE.md"
  printf '%s\n' "$3" > "$1/eslint.config.mjs"
}

# 場合を 1 つ動かす。$1 = 名前、$2 = 期待（pass / fail）、$3 = 失敗のときに出力に含まれるべき文言、$4 = 準備の関数
run_case() {
  local name="$1" expect="$2" want="$3" setup="$4" d out rc
  d="$TMP_ROOT/case-$((passed + failed + 1))"
  mkdir -p "$d"
  add_net_files "$d" "$MIN_INVARIANTS" "$MIN_NET_CONSTS"
  "$setup" "$d"
  set +e
  out="$(cd "$d" && HARNESS_ROOT="$d" HARNESS_ENGINE_DIR="$ENGINE" bash "$H/network-names.sh" </dev/null 2>&1)"
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

# 文字列 $1 の中の、最初の $2 を $3 に置き換える。$2 が無ければそのまま出す（失敗を期待する場合が通り、試験が NG を出す）
replace_once() {
  awk -v from="$2" -v to="$3" 'BEGIN { RS = "\001" } { i = index($0, from); if (i) $0 = substr($0, 1, i - 1) to substr($0, i + length(from)); printf "%s", $0 }' <<<"$1"
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
# ARCHITECTURE.md の node: の書き方を変える（読み取りの前提が崩れる）
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
# 見逃さないこと）。$1 = 根、$2 = 定数の名前、$3 = 複数行にした本物の宣言（\n で改行）
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
setup_net_base_eslint_only() {
  add_net_files "$1" "$REAL_INVARIANTS" "$(replace_once "$REAL_NET_CONSTS" '"dgram"]' '"dgram", "quic"]')"
}

run_case "通信の名前の一覧: 本物の不変条件と定数" pass "" setup_net_correct
run_case "通信の名前の一覧: 不変条件 2 を「それぞれに」の後の空白で折り返しても読める" pass "" setup_net_fold_at_space
run_case "通信の名前の一覧: eslint.config.mjs が無い" fail "eslint.config.mjs がありません（通信の名前の一覧の検査が" setup_net_no_eslint_config
run_case "通信の名前の一覧: NETWORK_GLOBALS の古い宣言をコメントに残し、本物を複数行にして名前を足す" fail "NETWORK_GLOBALS に値を入れる書き方（「NETWORK_GLOBALS =」。コメントの中を含む）が 2 か所" setup_net_globals_commented_old
run_case "通信の名前の一覧: NETWORK_MODULE_BASES の古い宣言をコメントに残し、本物を複数行にして名前を足す" fail "NETWORK_MODULE_BASES に値を入れる書き方（「NETWORK_MODULE_BASES =」。コメントの中を含む）が 2 か所" setup_net_bases_commented_old
run_case "通信の名前の一覧: ARCHITECTURE.md だけにモジュールがある" fail "通信のためのモジュールが合いません（ARCHITECTURE.md だけにある: node:quic、quic。eslint.config.mjs だけにある: なし）" setup_net_module_arch_only
run_case "通信の名前の一覧: eslint.config.mjs だけにモジュールがある" fail "通信のためのモジュールが合いません（ARCHITECTURE.md だけにある: なし。eslint.config.mjs だけにある: ws）" setup_net_module_eslint_only
run_case "通信の名前の一覧: ARCHITECTURE.md だけに大域の名前がある" fail "通信のための大域の名前が合いません（ARCHITECTURE.md だけにある: WebTransport。" setup_net_global_arch_only
run_case "通信の名前の一覧: eslint.config.mjs の NETWORK_MODULE_BASES だけに名前がある" fail "eslint.config.mjs だけにある: node:quic、quic）" setup_net_base_eslint_only
run_case "通信の名前の一覧: eslint.config.mjs だけに大域の名前がある" fail "eslint.config.mjs だけにある: WebTransport）" setup_net_global_eslint_only
run_case "通信の名前の一覧: ARCHITECTURE.md の node: の書き方を変えると、黙って通らず失敗する" fail "に「と、それぞれに \`node:\` を付けた名前、」がありません" setup_net_arch_wording
run_case "通信の名前の一覧: NETWORK_MODULES の組み立て方を変えると、黙って通らず失敗する" fail "eslint.config.mjs の NETWORK_MODULES の行が" setup_net_eslint_form

total=$((passed + failed))
if [ "$failed" -gt 0 ]; then
  echo "network-names.test: $total 件中 $failed 件が期待と違います" >&2
  exit 1
fi
echo "network-names.test: $total 件中 $total 件が期待どおり"
