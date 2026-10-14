#!/usr/bin/env bash
# 早期通知（notify.sh、notify-paths.mjs）、check-docs.sh の --root、フックの設定（.claude/settings.json、.codex/hooks.json）の試験。
# 手元と CI で同じコマンドを使う: npm run test:harness（check-docs.test.sh の後に動く）
#
# 一時ディレクトリに、本体と worktree を持つ見本のリポジトリを作り、3 つのスクリプト（notify.sh、notify-paths.mjs、
# check-docs.sh）の写しを置いて、フックの入力の見本を標準入力に渡して動かす。Claude Code と Codex は起動しない。
# 見本の Markdown は、このファイルの中で作り、リポジトリには置かない（文書の検査が見本を拾うため）。
#
# 検査（check-docs.sh）が動く呼び出しは、run_notify、run_check と、試験 15 の、ログの指定なしで notify.sh を呼ぶ 1 回の
# 3 か所だけにあり、どれも基準の日（HARNESS_TODAY）を決まった日にして呼ぶ。検査 11（古い計画）が基準の日を見るので、
# 渡さないと、試験を実行した日によって結果が変わるためである。基準の日を付けない検査の呼び出しを足さない
# （試験 17 の run_cmd が動かすのは、目印を残すだけの見本の notify.sh で、検査は動かない）。
#
# 試験の番号（下の「--- 試験 N」の区切り）は、早期通知の設計の試験の一覧の番号である。
# /bin/bash（macOS では 3.2）で動く書き方だけを使う。
set -euo pipefail
export LC_ALL=C
unset HARNESS_NOTIFY HARNESS_NOTIFY_LOG HARNESS_NOTIFY_TIME_LIMIT GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
H="$ROOT/scripts/harness"
PLANS="$ROOT/docs/PLANS.md"

TMP_ROOT="$(mktemp -d)"
TMP_ROOT="$(cd "$TMP_ROOT" && pwd -P)"
trap 'rm -rf "$TMP_ROOT"' EXIT

# 検査に渡す基準の日（check-docs.test.sh と同じく、新しい書式の適用開始の日。HARNESS_TEST_TODAY で替えられる）
START="$(sed -n 's/^新しい書式の適用開始: \([0-9-]*\)$/\1/p' "$PLANS" | head -n 1)"
if [ -z "$START" ]; then
  echo "notify.test: NG: $PLANS から「新しい書式の適用開始」の日付を読み取れません" >&2
  exit 1
fi
TODAY="${HARNESS_TEST_TODAY:-$START}"

LOG="$TMP_ROOT/notify.log"
ERR="$TMP_ROOT/stderr"
STDIN_FILE="$TMP_ROOT/stdin"
OUT=""
RC=0
EXTRA_ENV=()   # 次の run_notify の 1 回だけに足す環境変数（「名前=値」の並び）
passed=0
failed=0

FAIL_TEXT="文書の検査（npm run check:docs）が不合格です"
MAP_TEXT="文書の地図のパス docs/missing.md がありません"
SHAPE_TEXT="フックの入力の形が、想定と違います"
FOOTER_TEXT="これは早期通知で、作業は止めていません。止めるのは npm run check と CI です。"
NOT_RUN_TEXT="早期通知は動きませんでした"

# --- 見本を作る道具 ---

# 利用者の git の設定（署名、フック、既定のブランチの名前）に左右されない git
tgit() {
  git -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null \
    -c init.defaultBranch=main -c core.fsmonitor=false "$@"
}

# 文書の検査を通る最小のファイルを置く（コミットはしない）
write_base_files() {
  local d="$1" p
  mkdir -p "$d/docs/adr" "$d/docs/exec-plans/active" "$d/docs/exec-plans/completed" "$d/docs/quality-eval/tasks" \
    "$d/docs/quality-eval/results" "$d/scripts/harness" "$d/.github/workflows" "$d/src"
  cp "$PLANS" "$d/docs/PLANS.md"
  printf '%s\n' "# 試験" "" "ハーネスの版: 1" "" "## 文書の地図" "" "| 種類 | パス |" "|---|---|" "| 計画の書式 | \`docs/PLANS.md\` |" > "$d/AGENTS.md"
  printf '@AGENTS.md\n' > "$d/CLAUDE.md"
  printf '# ARCHITECTURE\n' > "$d/ARCHITECTURE.md"
  printf '# ADR\n' > "$d/docs/adr/README.md"
  for p in .gitignore docs/QUALITY_SCORE.md docs/quality-eval/README.md scripts/harness/check-arch.sh \
    scripts/harness/check-secrets.sh scripts/harness/check-secrets.mjs .dependency-cruiser.cjs .secretlintrc.json \
    .github/workflows/harness.yml .github/dependabot.yml docs/exec-plans/active/.gitkeep docs/exec-plans/completed/.gitkeep \
    docs/quality-eval/tasks/.gitkeep docs/quality-eval/results/.gitkeep src/.gitkeep; do
    : > "$d/$p"
  done
}

commit_all() {
  tgit -C "$1" init -q
  tgit -C "$1" add -A
  tgit -C "$1" commit -q -m "見本"
}

# 文書の検査を通る見本のリポジトリ（本体）を作る。3 つのスクリプトは、本物の写し
make_repo() {
  write_base_files "$1"
  cp "$H/check-docs.sh" "$H/notify.sh" "$H/notify-paths.mjs" "$1/scripts/harness/"
  commit_all "$1"
}

# $1 の本体に、worktree $2 を足す
add_worktree() {
  tgit -C "$1" worktree add -q --detach "$2" HEAD
}

# 作業ツリー $1 の文書の検査を不合格にする（地図に、実在しないパスの行を足す）
break_docs() {
  printf '| 無い文書 | `docs/missing.md` |\n' >> "$1/AGENTS.md"
}

# 起動元 $1 の check-docs.sh を、呼ばれた回数と根を $2 に書き足してから本物を動かす版に替える
install_counter() {
  mv "$1/scripts/harness/check-docs.sh" "$1/scripts/harness/check-docs.real.sh"
  {
    printf '#!/bin/bash\n'
    printf 'printf "%%s\\n" "$2" >> %q\n' "$2"
    printf 'exec /bin/bash %q "$@"\n' "$1/scripts/harness/check-docs.real.sh"
  } > "$1/scripts/harness/check-docs.sh"
}

# Claude Code のフックの入力。$1 = file_path、$2 = cwd（省略可）
claude_input() {
  node -e 'process.stdout.write(JSON.stringify({ hook_event_name: "PostToolUse", tool_name: "Write", cwd: process.argv[2],
    tool_input: { file_path: process.argv[1], content: "x" } }))' "$1" "${2:-/}"
}

# Codex のフックの入力。$1 = cwd、$2 以降 = パッチの見出しの行
codex_input() {
  local cwd="$1" patch line
  shift
  patch='*** Begin Patch'
  for line in "$@"; do
    patch="$patch
$line
+本文"
  done
  patch="$patch
*** End Patch"
  node -e 'process.stdout.write(JSON.stringify({ hook_event_name: "PostToolUse", tool_name: "apply_patch", cwd: process.argv[1],
    tool_input: { command: process.argv[2] } }))' "$cwd" "$patch"
}

# --- 動かす道具 ---

# 早期通知を 1 回動かす。$1 = notify.sh のパス、$2 = 呼び出し元、$3 = 作業ディレクトリ、$4 = 標準入力に渡す文字列。
# 標準出力を OUT、終了コードを RC に入れる。ログ（LOG）は、動かす前に空にする
run_notify() {
  : > "$LOG"
  # 標準入力は、ファイルから渡す（早期通知が、大きすぎる入力を途中で読むのをやめても、渡す側の書き込みの失敗にしないため）
  printf '%s' "$4" > "$STDIN_FILE"
  set +e
  OUT="$(cd "$3" && env ${EXTRA_ENV[@]+"${EXTRA_ENV[@]}"} HARNESS_TODAY="$TODAY" HARNESS_NOTIFY_LOG="$LOG" \
    /bin/bash "$1" "$2" < "$STDIN_FILE" 2> "$ERR")"
  RC=$?
  set -e
  EXTRA_ENV=()
}

# check-docs.sh を直接動かす。$1 = スクリプト、$2 = 作業ディレクトリ、$3 以降 = 引数。出力（標準エラーを含む）を OUT に入れる
run_check() {
  local script="$1" cwd="$2"
  shift 2
  set +e
  OUT="$(cd "$cwd" && HARNESS_TODAY="$TODAY" bash "$script" "$@" 2>&1)"
  RC=$?
  set -e
}

# OUT の JSON から、追加の文脈の文面を出す（形が違えば失敗する）
ctx() {
  printf '%s' "$OUT" | node -e '
    const o = JSON.parse(require("node:fs").readFileSync(0, "utf8"));
    if (o.hookSpecificOutput.hookEventName !== "PostToolUse") process.exit(1);
    process.stdout.write(o.hookSpecificOutput.additionalContext);
  ' 2> /dev/null
}

# --- 確かめる道具（どれも、成り立てば 0 を返す） ---

silent() { [ "$RC" -eq 0 ] && [ -z "$OUT" ]; }
told() {   # 終了コード 0 で、文面に、引数の文字列をすべて含む
  local text want
  [ "$RC" -eq 0 ] || return 1
  text="$(ctx)" || return 1
  for want in "$@"; do
    grep -qF -- "$want" <<<"$text" || return 1
  done
}
not_told() {   # 文面に、引数の文字列を含まない
  local text
  text="$(ctx)" || return 1
  ! grep -qF -- "$1" <<<"$text"
}
log_has() { grep -qF -- "$1" "$LOG"; }
log_lines() { [ "$(wc -l < "$LOG" | tr -d ' ')" -eq "$1" ]; }
no_file() { [ ! -e "$1" ]; }
file_lines() { [ -f "$1" ] && [ "$(wc -l < "$1" | tr -d ' ')" -eq "$2" ]; }
file_has_line() { grep -qxF -- "$2" "$1"; }
rc_is() { [ "$RC" -eq "$1" ]; }
out_has() { grep -qF -- "$1" <<<"$OUT"; }

# 確かめを 1 つ行う。$1 = 名前、$2 以降 = 成り立つべきコマンド
expect() {
  local name="$1"
  shift
  if "$@"; then
    echo "ok: $name"
    passed=$((passed + 1))
  else
    echo "NG: $name（成り立たない: $*）" >&2
    echo "    終了コード: $RC" >&2
    printf '%s\n' "$OUT" | sed 's/^/    出力: /' >&2
    [ -f "$LOG" ] && sed 's/^/    ログ: /' "$LOG" >&2
    [ -f "$ERR" ] && sed 's/^/    標準エラー: /' "$ERR" >&2
    failed=$((failed + 1))
  fi
}

skip() {
  echo "skip: $1"
}

# --- 試験 1: 不合格なら文面が出て、通るなら何も出ない ---

T="$TMP_ROOT/t1"
R="$T/main"
make_repo "$R"
N="$R/scripts/harness/notify.sh"
run_notify "$N" claude "$R" "$(claude_input "$R/docs/PLANS.md" "$R")"
expect "1: 通る状態では何も出ない（claude）" silent
expect "1: 通る状態のログの結果は pass" log_has "result=pass"
run_notify "$N" codex "$R" "$(codex_input "$R" "*** Update File: docs/PLANS.md")"
expect "1: 通る状態では何も出ない（codex）" silent
break_docs "$R"
run_notify "$N" claude "$R" "$(claude_input "$R/docs/PLANS.md" "$R")"
expect "1: 不合格の文面が、終了コード 0 で出る（claude）" told "$FAIL_TEXT" "$MAP_TEXT" "$FOOTER_TEXT" "作業ツリー「main」"
expect "1: 不合格のログの結果は fail" log_has "result=fail"
run_notify "$N" codex "$R" "$(codex_input "$R" "*** Update File: docs/PLANS.md")"
expect "1: 不合格の文面が、終了コード 0 で出る（codex）" told "$FAIL_TEXT" "$MAP_TEXT" "$FOOTER_TEXT"
expect "1: 文面に、根の絶対パスを出さない" not_told "$R"

# --- 試験 2: .md でないファイルだけのときは、何も出ず、git も検査も起動しない ---

T="$TMP_ROOT/t2"
R="$T/main"
make_repo "$R"
break_docs "$R"
N="$R/scripts/harness/notify.sh"
mkdir -p "$T/bin"
printf '#!/bin/sh\n: > %s\nexit 1\n' "$T/git-called" > "$T/bin/git"
chmod +x "$T/bin/git"
EXTRA_ENV=("PATH=$T/bin:$PATH")
run_notify "$N" claude "$R" "$(claude_input "$R/src/a.ts" "$R")"
expect "2: .md でないファイルでは何も出ない（claude）" silent
expect "2: git を起動しない（claude）" no_file "$T/git-called"
expect "2: ログに理由 not-md が残る（claude）" log_has "skipped=1(not-md:1)"
EXTRA_ENV=("PATH=$T/bin:$PATH")
run_notify "$N" codex "$R" "$(codex_input "$R" "*** Add File: src/a.ts" "*** Update File: $R/package.json" "*** Delete File: docs/a.mdx")"
expect "2: .md でないファイルだけのパッチでは何も出ない（codex）" silent
expect "2: git を起動しない（codex）" no_file "$T/git-called"
expect "2: ログに理由 not-md が 3 件残る（codex）" log_has "skipped=3(not-md:3)"
EXTRA_ENV=("PATH=$T/bin:$PATH")
run_notify "$N" claude "$R" "$(claude_input "$R/docs/PLANS.md" "$R")"
expect "2: 対照: 文書を書いたときは、置いた偽の git が呼ばれる" [ -e "$T/git-called" ]

# --- 試験 3: 起動元は本体、書いたファイルは別の worktree ---

T="$TMP_ROOT/t3"
R="$T/main"
make_repo "$R"
add_worktree "$R" "$T/wt"
N="$R/scripts/harness/notify.sh"
break_docs "$T/wt"
run_notify "$N" claude "$R" "$(claude_input "$T/wt/docs/PLANS.md" "$R")"
expect "3: worktree だけに不備があると、文面が出る" told "$FAIL_TEXT" "$MAP_TEXT" "作業ツリー「wt」" "起動元（main）の検査で確かめました"
expect "3: ログの起動元は本体、検査した根は worktree" log_has "origin=$R	checked=$T/wt	"
T="$TMP_ROOT/t3b"
R="$T/main"
make_repo "$R"
add_worktree "$R" "$T/wt"
N="$R/scripts/harness/notify.sh"
break_docs "$R"
run_notify "$N" claude "$R" "$(claude_input "$T/wt/docs/PLANS.md" "$R")"
expect "3: 本体だけに不備があると、何も出ない" silent
expect "3: 本体だけに不備があるときも、検査した根は worktree" log_has "checked=$T/wt	"

# --- 試験 4: 別の worktree の悪意のあるスクリプトを実行しない ---

T="$TMP_ROOT/t4"
R="$T/main"
make_repo "$R"
add_worktree "$R" "$T/wt"
N="$R/scripts/harness/notify.sh"
break_docs "$T/wt"
printf '#!/bin/bash\n: > %s\n' "$T/evil-ran" > "$T/wt/scripts/harness/check-docs.sh"
cp "$T/wt/scripts/harness/check-docs.sh" "$T/wt/scripts/harness/notify.sh"
printf 'import { writeFileSync } from "node:fs";\nwriteFileSync(%s, "");\n' "\"$T/evil-ran\"" > "$T/wt/scripts/harness/notify-paths.mjs"
for cwd in "$R" "$T/wt" "$T/wt/scripts/harness"; do
  label="${cwd#"$T"/}"
  run_notify "$N" claude "$cwd" "$(claude_input "$T/wt/docs/PLANS.md" "$cwd")"
  expect "4: 作業ディレクトリが $label でも、起動元の検査の結果が出る（claude）" told "$FAIL_TEXT" "$MAP_TEXT" "作業ツリー「wt」"
  expect "4: 作業ディレクトリが $label でも、worktree のスクリプトを実行しない（claude）" no_file "$T/evil-ran"
  run_notify "$N" codex "$cwd" "$(codex_input "$cwd" "*** Update File: $T/wt/docs/PLANS.md")"
  expect "4: 作業ディレクトリが $label でも、起動元の検査の結果が出る（codex）" told "$FAIL_TEXT" "$MAP_TEXT"
  expect "4: 作業ディレクトリが $label でも、worktree のスクリプトを実行しない（codex）" no_file "$T/evil-ran"
done

# --- 試験 5: 対象外のパス（検査せず、何も出さず、ログに理由が残る）と、「..」を含む相対パス ---

T="$TMP_ROOT/t5"
R="$T/main"
make_repo "$R"
add_worktree "$R" "$T/wt"
make_repo "$T/other"
break_docs "$T/other"
break_docs "$T/wt"
N="$R/scripts/harness/notify.sh"
mkdir -p "$T/plain"
: > "$T/plain/a.md"
ln -s PLANS.md "$R/docs/link.md"
tgit init -q --bare "$R/vendor/bare.git"
tgit init -q --bare "$R/vendor/fake.git"
tgit -C "$R/vendor/fake.git" config core.bare false
tgit -C "$R/vendor/fake.git" config core.worktree "$T/wt"
NONE="checked=	files=	"   # 検査した根も、対象にした文書も無い

run_notify "$N" claude "$R" "$(claude_input "$T/other/docs/PLANS.md" "$R")"
expect "5: 別のリポジトリのファイルでは何も出ない" silent
expect "5: 別のリポジトリのファイルは検査せず、理由 other-repo が残る" log_has "${NONE}skipped=1(other-repo:1)"
run_notify "$N" claude "$R" "$(claude_input "$T/plain/a.md" "$R")"
expect "5: git の作業ツリーの外のファイルでは何も出ない" silent
expect "5: git の作業ツリーの外のファイルは検査せず、理由 not-git が残る" log_has "${NONE}skipped=1(not-git:1)"
run_notify "$N" claude "$R" "$(claude_input "$R/docs/link.md" "$R")"
expect "5: シンボリックリンクでは何も出ない" silent
expect "5: シンボリックリンクは検査せず、理由 symlink が残る" log_has "${NONE}skipped=1(symlink:1)"
run_notify "$N" claude "$R" "$(claude_input "" "$R")"
expect "5: 空のパスでは何も出ない（claude）" silent
expect "5: 空のパスは検査せず、理由 empty が残る（claude）" log_has "${NONE}skipped=1(empty:1)"
run_notify "$N" codex "$R" "$(codex_input "$R" "*** Add File: ")"
expect "5: 空のパスでは何も出ない（codex）" silent
expect "5: 空のパスは検査せず、理由 empty が残る（codex）" log_has "${NONE}skipped=1(empty:1)"
run_notify "$N" claude "$R" "$(claude_input "$R/docs/a
b.md" "$R")"
expect "5: 改行を含むパスでは何も出ない" silent
expect "5: 改行を含むパスは検査せず、理由 control が残る" log_has "${NONE}skipped=1(control:1)"
run_notify "$N" claude "$R" "$(claude_input "$R/vendor/bare.git/a.md" "$R")"
expect "5: 埋め込まれた裸のリポジトリの中のファイルでは何も出ない" silent
expect "5: 埋め込まれた裸のリポジトリの中のファイルは検査しない" log_has "$NONE"
run_notify "$N" claude "$R" "$(claude_input "$R/vendor/fake.git/a.md" "$R")"
expect "5: 作業ツリーを同じリポジトリの worktree に向けた、埋め込まれた git のディレクトリの中のファイルでは何も出ない" silent
expect "5: そのファイルは検査せず、理由 other-repo が残る" log_has "${NONE}skipped=1(other-repo:1)"
run_notify "$N" codex "$R" "$(codex_input "$R" "*** Update File: ../wt/docs/PLANS.md")"
expect "5: 「..」を含む相対パスが同じリポジトリの worktree を指すときは、その worktree を検査する" told "$FAIL_TEXT" "作業ツリー「wt」"
expect "5: そのときのログの検査した根は worktree" log_has "checked=$T/wt	"
run_notify "$N" codex "$R" "$(codex_input "$R" "*** Update File: ../other/docs/PLANS.md")"
expect "5: 「..」を含む相対パスが別のリポジトリを指すときは何も出ない" silent
expect "5: そのときは検査せず、理由 other-repo が残る" log_has "${NONE}skipped=1(other-repo:1)"

# --- 試験 6: 名前（空白、一重と二重の引用符、先頭が -、日本語）でも、正しく 1 回だけ検査する ---

T="$TMP_ROOT/t6/sp ace 'q' \"d\" 日本"
R="$T/main"
make_repo "$R"
add_worktree "$R" "$T/-wt"
COUNT="$TMP_ROOT/t6/count"
install_counter "$R" "$COUNT"
N="$R/scripts/harness/notify.sh"
DOC="docs/-a b 'q' \"d\" 日本語.md"
printf '# 見本\n' > "$T/-wt/$DOC"
run_notify "$N" claude "$R" "$(claude_input "$T/-wt/$DOC" "$R")"
expect "6: 特殊な名前のパスでも、通る状態では何も出ない（claude）" silent
expect "6: 特殊な名前のパスでも、検査は 1 回だけ（claude）" file_lines "$COUNT" 1
expect "6: 検査した根は、書いたファイルのある worktree（claude）" file_has_line "$COUNT" "$T/-wt"
break_docs "$T/-wt"
rm -f "$COUNT"
run_notify "$N" claude "$T/-wt" "$(claude_input "$T/-wt/$DOC" "$T/-wt")"
expect "6: 特殊な名前のパスでも、不合格の文面が出る（claude）" told "$FAIL_TEXT" "$MAP_TEXT" "作業ツリー「-wt」"
expect "6: 不合格のときも、検査は 1 回だけ（claude）" file_lines "$COUNT" 1
rm -f "$COUNT"
run_notify "$N" codex "$T/-wt" "$(codex_input "$T/-wt" "*** Add File: $DOC" "*** Update File: $T/-wt/$DOC")"
expect "6: 相対と絶対で同じ文書を指すパッチでも、不合格の文面が出る（codex）" told "$FAIL_TEXT" "作業ツリー「-wt」"
expect "6: 相対と絶対で同じ文書を指すパッチでも、検査は 1 回だけ（codex）" file_lines "$COUNT" 1
expect "6: ログに、対象にした文書のパスが残る（codex）" log_has "files=$T/-wt/$DOC"

# --- 試験 7: 複数のファイル（Codex の入力） ---

T="$TMP_ROOT/t7"
R="$T/main"
make_repo "$R"
add_worktree "$R" "$T/wt1"
add_worktree "$R" "$T/wt2"
add_worktree "$R" "$T/wt3"
COUNT="$T/count"
install_counter "$R" "$COUNT"
N="$R/scripts/harness/notify.sh"
printf '# 見本\n' > "$R/docs/new one.md"
run_notify "$N" codex "$R" "$(codex_input "$R" "*** Add File: AGENTS.md" "*** Add File: docs/new one.md" "*** Update File: $R/docs/PLANS.md")"
expect "7: 同じ作業ツリーの 3 つの文書では何も出ない" silent
expect "7: 同じ作業ツリーの 3 つの文書では、検査は 1 回だけ" file_lines "$COUNT" 1
expect "7: ログに、空白を含む名前の文書のパスが残る" log_has "$R/docs/new one.md"
rm -f "$COUNT"
run_notify "$N" codex "$R" "$(codex_input "$R" "*** Update File: docs/PLANS.md" "*** Update File: ../wt1/docs/PLANS.md" "*** Add File: $T/wt1/AGENTS.md" "*** Update File: AGENTS.md")"
expect "7: 2 つの作業ツリーにまたがるときは、検査は 2 回" file_lines "$COUNT" 2
expect "7: 本体を 1 回検査する" file_has_line "$COUNT" "$R"
expect "7: worktree を 1 回検査する" file_has_line "$COUNT" "$T/wt1"
rm -f "$COUNT"
run_notify "$N" codex "$R" "$(codex_input "$R" "*** Update File: docs/PLANS.md" "*** Update File: ../wt1/docs/PLANS.md" "*** Update File: ../wt2/docs/PLANS.md" "*** Update File: ../wt3/docs/PLANS.md")"
expect "7: 4 つの作業ツリーのときは、3 つまで検査する" file_lines "$COUNT" 3
expect "7: 4 つの作業ツリーのときは、検査しなかった作業ツリーがあると知らせる" told "検査しなかった作業ツリーがあります（1 個）" "$FOOTER_TEXT"
expect "7: そのときのログの結果に over-limit が残る" log_has "over-limit"

# --- 試験 8: 移動と削除の見出し（Codex の入力） ---

rm -f "$COUNT"
run_notify "$N" codex "$R" "$(codex_input "$R" "*** Update File: docs/PLANS.md
*** Move to: ../wt1/docs/moved.md")"
expect "8: 移動は、先と元の両方の作業ツリーを検査する" file_lines "$COUNT" 2
expect "8: 移動の元の作業ツリーを検査する" file_has_line "$COUNT" "$R"
expect "8: 移動の先の作業ツリーを検査する" file_has_line "$COUNT" "$T/wt1"
rm -f "$COUNT"
run_notify "$N" codex "$R" "$(codex_input "$R" "*** Delete File: docs/gone.md")"
expect "8: 削除は、親ディレクトリが残っていれば検査する" file_lines "$COUNT" 1
rm -f "$COUNT"
run_notify "$N" codex "$R" "$(codex_input "$R" "*** Delete File: docs/removed-dir/gone.md")"
expect "8: 削除で親ごと消えていれば、何も出ない" silent
expect "8: 削除で親ごと消えていれば、検査しない" no_file "$COUNT"
expect "8: 削除で親ごと消えていれば、理由 no-parent が残る" log_has "skipped=1(no-parent:1)"
run_notify "$N" codex "$R" "$(codex_input "$R" "*** Update File: docs/PLANS.md")"
expect "8: 移動を伴わない更新の見出しでも検査する" file_lines "$COUNT" 1

# --- 試験 9: サブディレクトリからの起動 ---

T="$TMP_ROOT/t9"
R="$T/main"
make_repo "$R"
break_docs "$R"
N="$R/scripts/harness/notify.sh"
for sub in src docs; do
  run_notify "$N" claude "$R/$sub" "$(claude_input "$R/docs/PLANS.md" "$R/$sub")"
  expect "9: 作業ディレクトリが $sub でも、同じ文面が出る（claude）" told "$FAIL_TEXT" "$MAP_TEXT" "作業ツリー「main」"
  run_notify "$N" codex "$R/$sub" "$(codex_input "$R/$sub" "*** Update File: ../docs/PLANS.md")"
  expect "9: 作業ディレクトリが $sub でも、同じ文面が出る（codex。相対パス）" told "$FAIL_TEXT" "$MAP_TEXT" "作業ツリー「main」"
  expect "9: 作業ディレクトリが $sub でも、検査した根は作業ツリーの根" log_has "checked=$R	"
done

# --- 試験 10: 入力の形が変わったとき ---

for caller in claude codex; do
  run_notify "$N" "$caller" "$R" ""
  expect "10: 空の入力で、入力の形が変わったという文面が出る（$caller）" told "$SHAPE_TEXT" "$FOOTER_TEXT"
  run_notify "$N" "$caller" "$R" '{"tool_input":'
  expect "10: 壊れた JSON で、入力の形が変わったという文面が出る（$caller）" told "$SHAPE_TEXT"
  run_notify "$N" "$caller" "$R" '{"tool_name":"x","tool_input":{}}'
  expect "10: 期待した項目が無い入力で、入力の形が変わったという文面が出る（$caller）" told "$SHAPE_TEXT"
  expect "10: そのときのログの結果は input-shape（$caller）" log_has "result=input-shape"
done
run_notify "$N" codex "$R" '{"tool_name":"apply_patch","cwd":"/","tool_input":{"command":"*** Begin Patch\n*** Rename File: a.md\n*** End Patch"}}'
expect "10: パッチの見出しを読めない入力で、入力の形が変わったという文面が出る" told "$SHAPE_TEXT" "no-patch-header"
run_notify "$N" codex "$R" '{"tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\n*** Update File: docs/PLANS.md\n*** End Patch"}}'
expect "10: 相対パスなのに cwd が無い入力で、入力の形が変わったという文面が出る" told "$SHAPE_TEXT" "no-cwd"
run_notify "$N" other "$R" "$(claude_input "$R/docs/PLANS.md" "$R")"
expect "10: 呼び出し元の名前が違うときは、実行できなかったという文面が出る" told "早期通知を実行できませんでした" "$FOOTER_TEXT"

# --- 試験 11: 時間切れ ---

T="$TMP_ROOT/t11"
R="$T/main"
make_repo "$R"
N="$R/scripts/harness/notify.sh"
{
  printf '#!/bin/bash\n'
  printf 'echo $$ > %q\n' "$T/pids"
  printf 'sleep 300 &\n'
  printf 'echo $! >> %q\n' "$T/pids"
  printf 'wait\n'
} > "$R/scripts/harness/check-docs.sh"
# 短くした上限（5 秒）には、検査を始める前の処理（入力の変換、パスの判定の git）も含まれる。混んだ機械では、検査を
# 始める前に時間切れになることがあるので、ここでは、どの段階の時間切れかを問わず、時間切れの文面が出て、既定の 18 秒より
# 早く終わることだけを確かめる。検査が起動した後に子と孫のプロセスが残らないことは、下の、既定の上限の回で確かめる
EXTRA_ENV=("HARNESS_NOTIFY_TIME_LIMIT=5")
before="$SECONDS"
run_notify "$N" claude "$R" "$(claude_input "$R/docs/PLANS.md" "$R")"
elapsed=$((SECONDS - before))
expect "11: 検査が終わらないときは、終了コード 0 で時間切れの文面が出る" told "時間切れ" "$FOOTER_TEXT"
expect "11: 短くした上限（5 秒）で打ち切る（かかったのは $elapsed 秒。既定の上限は 18 秒）" [ "$elapsed" -le 15 ]
expect "11: ログの結果は timeout" log_has "result=timeout"
# 検査の見本が、自分と子の PID を書き終えている（検査が起動して、準備を終えた）ことを確かめてから、どちらも残って
# いないことを確かめる
children_gone() {
  local pid
  [ -f "$T/pids" ] && [ "$(wc -l < "$T/pids" | tr -d ' ')" -eq 2 ] || return 1
  sleep 1
  while IFS= read -r pid; do
    if kill -0 "$pid" 2>/dev/null; then
      return 1
    fi
  done < "$T/pids"
}

# 上限の値の先頭が 0 のとき（08 は、算術の式で 8 進数の誤りになる）は受けず、既定の上限（18 秒）で打ち切る。
# 既定の上限は、検査を始める前の処理より十分に長いので、この回で、検査が起動した後の時間切れと、子と孫のプロセスが
# 残らないことを確かめる
EXTRA_ENV=("HARNESS_NOTIFY_TIME_LIMIT=08")
rm -f "$T/pids"
before="$SECONDS"
run_notify "$N" claude "$R" "$(claude_input "$R/docs/PLANS.md" "$R")"
elapsed=$((SECONDS - before))
expect "11: 上限の値が 08 でも、検査の時間切れの文面が出る（上限が無効にならない）" told "時間切れ" "全体の上限 18 秒" "作業ツリー「main」"
expect "11: 上限の値が 08 のときは、既定の上限で打ち切る（かかったのは $elapsed 秒）" [ "$elapsed" -le 40 ]
expect "11: 検査が起動した後の時間切れで、子と孫のプロセスが残らない" children_gone

# パスの判定の途中で時間の上限に達したら、打ち切って知らせる（1 回の呼び出しに 1 秒かかる git を置いて確かめる）
T="$TMP_ROOT/t11b"
R="$T/main"
make_repo "$R"
break_docs "$R"
N="$R/scripts/harness/notify.sh"
mkdir -p "$T/bin"
printf '#!/bin/sh
sleep 1
exec %s "$@"
' "$(command -v git)" > "$T/bin/git"
chmod +x "$T/bin/git"
EXTRA_ENV=("PATH=$T/bin:$PATH" "HARNESS_NOTIFY_TIME_LIMIT=4")
before="$SECONDS"
run_notify "$N" codex "$R" "$(codex_input "$R" "*** Update File: docs/a.md" "*** Update File: docs/b.md" "*** Update File: docs/c.md" "*** Update File: docs/d.md")"
elapsed=$((SECONDS - before))
expect "11: パスの判定の途中で時間の上限に達すると、判定していないパスがあると知らせる" told "判定していないパスがあり" "$FOOTER_TEXT"
expect "11: そのとき、上限の近くで終わる（かかったのは $elapsed 秒）" [ "$elapsed" -le 15 ]
expect "11: そのときのログの結果に timeout が残る" log_has "timeout"

# 最後の 1 件の判定の git が長引いても、全体の上限で打ち切って知らせる（名前に slow-dir を含む呼び出しだけが終わらない git）
mkdir -p "$T/bin2" "$R/slow-dir"
printf '#!/bin/sh\ncase "$*" in *slow-dir*) sleep 300 ;; esac\nexec %s "$@"\n' "$(command -v git)" > "$T/bin2/git"
chmod +x "$T/bin2/git"
EXTRA_ENV=("PATH=$T/bin2:$PATH" "HARNESS_NOTIFY_TIME_LIMIT=5")
before="$SECONDS"
run_notify "$N" codex "$R" "$(codex_input "$R" "*** Update File: docs/a.md" "*** Update File: slow-dir/b.md")"
elapsed=$((SECONDS - before))
expect "11: 最後の 1 件の判定の git が終わらないときも、判定していないパスがあると知らせる" told "判定していないパスがあり" "$FOOTER_TEXT"
expect "11: そのとき、全体の上限（5 秒）の近くで終わる（かかったのは $elapsed 秒）" [ "$elapsed" -le 15 ]
expect "11: そのときのログの結果に timeout が残る" log_has "timeout"

# 名前が .md で終わらないパスは、いくつあっても、何も出さない（パスの数の上限に数えない）
many=()
i=0
while [ "$i" -lt 205 ]; do
  i=$((i + 1))
  many[${#many[@]}]="*** Add File: src/f$i.ts"
done
run_notify "$N" codex "$R" "$(codex_input "$R" "${many[@]}")"
expect "11: .md でないパスが 205 件あっても、何も出ない" silent
expect "11: そのときのログに、205 件を not-md として数えた行が残る" log_has "skipped=205(not-md:205)	result=none"

# 文書のパスの数の上限（200 件）を超えた分は判定せず、知らせる
many=()
i=0
while [ "$i" -lt 205 ]; do
  i=$((i + 1))
  many[${#many[@]}]="*** Add File: docs/f$i.md"
done
run_notify "$N" codex "$R" "$(codex_input "$R" "${many[@]}" "*** Add File: src/a.ts")"
expect "11: 文書のパスが 200 件を超えると、検査していないものがあると知らせる" told "多すぎて（200 件を超える）" "$FOOTER_TEXT"
expect "11: そのときも、判定した分の検査の結果は出る" told "$FAIL_TEXT"
expect "11: そのときのログの結果に too-many-paths が残る" log_has "too-many-paths"

# 入力が大きさの上限（8 MiB）を超えると、読むのをやめて知らせる
BIG="$(head -c 8500000 /dev/zero | tr '\0' 'a')"
before="$SECONDS"
run_notify "$N" claude "$R" "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$R/docs/PLANS.md\",\"content\":\"$BIG\"}}"
elapsed=$((SECONDS - before))
BIG=""
expect "11: 入力が 8 MiB を超えると、大きすぎて調べていないと知らせる" told "フックの入力が大きすぎて（8 MiB を超える）" "$FOOTER_TEXT"
expect "11: そのとき、検査は動かさず、ログの結果は too-large" log_has "checked=	files=	skipped=0()	result=too-large"
expect "11: そのとき、時間の上限より早く終わる（かかったのは $elapsed 秒）" [ "$elapsed" -le 15 ]

# --- 試験 12: 文面の長さ ---

T="$TMP_ROOT/t12"
R="$T/main"
make_repo "$R"
N="$R/scripts/harness/notify.sh"
{
  printf '#!/bin/bash\n'
  printf 'i=0\n'
  printf 'while [ "$i" -lt 300 ]; do i=$((i + 1)); echo "NG $i: 長い出力の見本の行です。長い出力の見本の行です。長い出力の見本の行です。長い出力の見本の行です。長い出力の見本の行です。"; done\n'
  printf 'exit 1\n'
} > "$R/scripts/harness/check-docs.sh"
run_notify "$N" claude "$R" "$(claude_input "$R/docs/PLANS.md" "$R")"
expect "12: 長い出力でも、不合格の文面と、切ったことと、末尾の 1 行が入っている" told "$FAIL_TEXT" "（文面が長いので、ここで切りました）" "$FOOTER_TEXT"
length_ok() {
  printf '%s' "$OUT" | node -e '
    const text = JSON.parse(require("node:fs").readFileSync(0, "utf8")).hookSpecificOutput.additionalContext;
    const size = Array.from(text).length;
    process.exit(size <= 2000 && size >= 1900 && text.endsWith(process.argv[1]) ? 0 : 1);
  ' "$FOOTER_TEXT"
}
expect "12: 文面が 2000 字以内に切られ、末尾の 1 行で終わる" length_ok

# 検査が、不合格でも時間切れでもない終了コードで終わったときは、検査の出力（絶対パスを含みうる）を文面に入れない
{
  printf '#!/bin/bash
'
  printf 'echo "$0: line 1: 見本の誤り" >&2
'
  printf 'exit 3
'
} > "$R/scripts/harness/check-docs.sh"
run_notify "$N" claude "$R" "$(claude_input "$R/docs/PLANS.md" "$R")"
expect "12: 検査が終了コード 3 で終わると、実行できなかったと知らせる" told "文書の検査を実行できませんでした" "終了コード 3" "$FOOTER_TEXT"
expect "12: そのとき、文面に、根の絶対パスを出さない" not_told "$TMP_ROOT"
expect "12: そのときのログの結果は check-error" log_has "result=check-error"

# --- 試験 13: 検査の版の違い（起動元にだけある決まりで、対象が不合格になる） ---

T="$TMP_ROOT/t13"
R="$T/main"
make_repo "$R"
add_worktree "$R" "$T/wt"
N="$R/scripts/harness/notify.sh"
awk '{ print } $0 == "ARCHITECTURE.md" && !done { print "docs/only-in-origin.md"; done = 1 }' "$H/check-docs.sh" > "$R/scripts/harness/check-docs.sh"
: > "$R/docs/only-in-origin.md"
run_notify "$N" claude "$R" "$(claude_input "$R/docs/PLANS.md" "$R")"
expect "13: 対照: 起動元は、起動元の版の決まりで通る" silent
run_notify "$N" claude "$R" "$(claude_input "$T/wt/docs/PLANS.md" "$R")"
expect "13: 起動元にだけある決まりで対象が不合格になり、起動元の検査で確かめたと書かれている" \
  told "$FAIL_TEXT" "必須のファイル docs/only-in-origin.md がありません" "作業ツリー「wt」" "起動元（main）の検査で確かめました"

# --- 試験 14: node が無い環境 ---

T="$TMP_ROOT/t14"
R="$T/main"
make_repo "$R"
break_docs "$R"
N="$R/scripts/harness/notify.sh"
mkdir -p "$T/bin"
for tool in bash sh git perl sed awk grep wc cat date mktemp rm head tail tr cmp sort dirname basename env; do
  found="$(command -v "$tool" || true)"
  case "$found" in
    /*) ln -s "$found" "$T/bin/$tool" ;;
  esac
done
INPUT="$(claude_input "$R/docs/PLANS.md" "$R")"
EXTRA_ENV=("PATH=$T/bin")
run_notify "$N" claude "$R" "$INPUT"
expect "14: node が無いときは、終了コード 0 で固定の文面が出る" told "早期通知を実行できませんでした（node を起動できないか、文面を作れません）" "$FOOTER_TEXT"
expect "14: そのときのログの結果は launch-failed" log_has "result=launch-failed"

# --- 試験 15: 止める手段、ログ、リポジトリの中に書かないこと ---

T="$TMP_ROOT/t15"
R="$T/main"
make_repo "$R"
break_docs "$R"
N="$R/scripts/harness/notify.sh"
snapshot() {
  (cd "$1" && git -c core.fsmonitor=false status --porcelain=v1 --untracked-files=all \
    && git -c core.fsmonitor=false ls-files -z --cached --others | xargs -0 cksum \
    && ls -la . .git)
}
INPUT="$(claude_input "$R/docs/PLANS.md" "$R")"
before="$(snapshot "$R")"
EXTRA_ENV=("HARNESS_NOTIFY=off")
run_notify "$N" claude "$R" "$INPUT"
expect "15: HARNESS_NOTIFY=off では何も出ない" silent
expect "15: HARNESS_NOTIFY=off ではログにも足さない" log_lines 0
run_notify "$N" claude "$R" "$INPUT"
expect "15: 止めていないときは文面が出る" told "$FAIL_TEXT"
expect "15: HARNESS_NOTIFY_LOG に 1 行が足される" log_lines 1
expect "15: ログの行に、呼び出し元、起動元の根、検査した根、対象にした文書、対象外の数、結果がある" \
  log_has "	caller=claude	origin=$R	checked=$R	files=$R/docs/PLANS.md	skipped=0()	result=fail"
after="$(snapshot "$R")"
expect "15: リポジトリの中のファイルが、前後で変わらない" [ "$before" = "$after" ]
set +e
OUT="$(cd "$R" && printf '%s' "$INPUT" | HARNESS_TODAY="$TODAY" /bin/bash "$N" claude 2> "$ERR")"
RC=$?
set -e
: > "$LOG"
expect "15: HARNESS_NOTIFY_LOG が無くても、文面が出る" told "$FAIL_TEXT"

# --- 試験 16: check-docs.sh --root ---

T="$TMP_ROOT/t16"
R="$T/main"
make_repo "$R"
add_worktree "$R" "$T/wt"
mkdir -p "$T/plain"
C="$R/scripts/harness/check-docs.sh"
run_check "$C" "$R" --root docs
expect "16: --root の値が絶対パスでないと、終了コード 2" rc_is 2
run_check "$C" "$R" --root "$R/AGENTS.md"
expect "16: --root の値がディレクトリでないと、終了コード 2" rc_is 2
run_check "$C" "$R" --root "$T/no-such-dir"
expect "16: --root の値が無いパスだと、終了コード 2" rc_is 2
run_check "$C" "$R" --root "$R/docs"
expect "16: --root の値が作業ツリーの根でない（サブディレクトリ）と、終了コード 2" rc_is 2
run_check "$C" "$R" --root "$T/plain"
expect "16: --root の値が git の作業ツリーの外だと、終了コード 2" rc_is 2
run_check "$C" "$R" --root
expect "16: --root に値が無いと、終了コード 2" rc_is 2
run_check "$C" "$R" --other "$R"
expect "16: 知らない引数は、終了コード 2" rc_is 2
run_check "$C" "$R" --root "$R" extra
expect "16: 余分な引数は、終了コード 2" rc_is 2
run_check "$C" "$T/plain" --root "$T/wt"
expect "16: --root で指定した根を検査する（通る）" rc_is 0
break_docs "$R"
run_check "$C" "$R" --root "$T/wt"
expect "16: 起動元の側の不備は拾わない" rc_is 0
run_check "$C" "$R/docs"
expect "16: 引数なしでは、自分の置き場の根を検査する（サブディレクトリから呼んでも同じ）" rc_is 1
expect "16: 引数なしでは、自分の置き場の根の不備を拾う" out_has "$MAP_TEXT"
T="$TMP_ROOT/t16b"
R="$T/main"
make_repo "$R"
add_worktree "$R" "$T/wt"
break_docs "$T/wt"
run_check "$R/scripts/harness/check-docs.sh" "$R" --root "$T/wt"
expect "16: --root で指定した根だけに入れた不備を拾う" rc_is 1
expect "16: そのときの出力に、不備の内容がある" out_has "$MAP_TEXT"
run_check "$R/scripts/harness/check-docs.sh" "$R"
expect "16: 引数なしでは、--root の側の不備を拾わない" rc_is 0

# --- 試験 17: Codex のフックのコマンド ---

CMD="$(node -e '
  const j = JSON.parse(require("node:fs").readFileSync(process.argv[1], "utf8"));
  process.stdout.write(j.hooks.PostToolUse[0].hooks[0].command);
' "$ROOT/.codex/hooks.json")"

# スクリプトの見本を持つリポジトリを作る。notify.sh は、呼ばれたら、自分の置き場と引数を $2 に 1 行足すだけの目印。
# $3 が commit なら、スクリプトをコミットする。untracked なら、スクリプトの無いコミットの後に、同じ場所へ置く
make_marker_repo() {
  local d="$1" ran="$2" mode="$3"
  write_base_files "$d"
  if [ "$mode" = untracked ]; then
    commit_all "$d"
  fi
  {
    printf '#!/bin/bash\n'
    printf 'here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"\n'
    printf 'printf "%%s %%s\\n" "$here" "$1" >> %q\n' "$ran"
  } > "$d/scripts/harness/notify.sh"
  printf '// 見本\n' > "$d/scripts/harness/notify-paths.mjs"
  printf '#!/bin/bash\n' > "$d/scripts/harness/check-docs.sh"
  if [ "$mode" = commit ]; then
    commit_all "$d"
  fi
}

# コマンドを、シェル（$1 以降。最後に -c とコマンドを足す）で動かす。作業ディレクトリは RUN_CWD
RUN_CWD=""
run_cmd() {
  : > "$ERR"
  set +e
  OUT="$(cd "$RUN_CWD" && "$@" -c "$CMD" 2> "$ERR" < /dev/null)"
  RC=$?
  set -e
}
ran_main() { silent && file_lines "$RAN" 1 && file_has_line "$RAN" "$MAIN/scripts/harness codex"; }
not_run() { told "$NOT_RUN_TEXT" && no_file "$RAN" && no_file "$EVIL"; }

# シェル 1 つについて、見本のリポジトリの各状態でコマンドを動かす。$1 = 名前、$2 以降 = シェルの起動の形
codex_command_cases() {
  local name="$1" T bare
  shift
  T="$TMP_ROOT/t17 $name sp ace"
  MAIN="$T/main"
  RAN="$T/ran"
  EVIL="$T/evil-ran"
  make_marker_repo "$MAIN" "$RAN" commit
  add_worktree "$MAIN" "$T/wt"
  # worktree の側のスクリプトを、コミットせずに、別の目印を作るものに替える（動いてはならない）
  printf '#!/bin/bash\n: > %q\n' "$EVIL" > "$T/wt/scripts/harness/notify.sh"
  cp "$T/wt/scripts/harness/notify.sh" "$T/wt/scripts/harness/check-docs.sh"

  for RUN_CWD in "$MAIN" "$MAIN/docs" "$T/wt" "$T/wt/docs/adr"; do
    rm -f "$RAN"
    run_cmd "$@"
    expect "17（$name）: 作業ディレクトリが ${RUN_CWD#"$T"/} のとき、本体の notify.sh が 1 回だけ実行される" ran_main
    expect "17（$name）: そのとき、worktree の側のスクリプトは実行されない" no_file "$EVIL"
  done
  rm -f "$RAN"

  bare="$T/bare.git"
  tgit clone -q --bare "$MAIN" "$bare"
  tgit -C "$bare" worktree add -q --detach "$T/bare-wt" HEAD
  RUN_CWD="$T/bare-wt"
  run_cmd "$@"
  expect "17（$name）: 裸のリポジトリと worktree の組では、実行されず、固定の JSON が終了コード 0 で出る" not_run

  mkdir -p "$T/plain"
  RUN_CWD="$T/plain"
  run_cmd "$@"
  expect "17（$name）: git の外では、実行されず、固定の JSON が終了コード 0 で出る" not_run

  write_base_files "$T/no-scripts"
  commit_all "$T/no-scripts"
  RUN_CWD="$T/no-scripts"
  run_cmd "$@"
  expect "17（$name）: 本体にスクリプトが無い状態では、実行されず、固定の JSON が終了コード 0 で出る" not_run

  make_marker_repo "$T/untracked" "$RAN" untracked
  RUN_CWD="$T/untracked"
  run_cmd "$@"
  expect "17（$name）: HEAD に無いスクリプトを同じ場所に置いた状態では、実行されず、固定の JSON が終了コード 0 で出る" not_run

  printf '# 変更\n' >> "$MAIN/scripts/harness/check-docs.sh"
  RUN_CWD="$T/wt"
  run_cmd "$@"
  expect "17（$name）: scripts/harness/ の下にコミットしていない変更がある状態では、実行されず、固定の JSON が終了コード 0 で出る" not_run
  tgit -C "$MAIN" add scripts/harness/check-docs.sh
  RUN_CWD="$MAIN"
  run_cmd "$@"
  expect "17（$name）: その変更をステージした状態でも、実行されない" not_run
}

codex_command_cases sh /bin/sh
ZSH="/bin/zsh"
[ -x "$ZSH" ] || ZSH="$(command -v zsh || true)"
if [ -n "$ZSH" ]; then
  # Codex は、利用者のシェルを -lc で起動する。利用者の設定を読まないように、ZDOTDIR を空の見本に向ける
  ZD="$TMP_ROOT/zdot-plain"
  mkdir -p "$ZD"
  codex_command_cases zsh env "ZDOTDIR=$ZD" "$ZSH" -l
  for alias_body in "g=git" "g=:"; do
    ZD="$TMP_ROOT/zdot-$alias_body"
    mkdir -p "$ZD"
    printf 'alias %s\n' "$alias_body" > "$ZD/.zshenv"
    T="$TMP_ROOT/t17 alias $alias_body"
    MAIN="$T/main"
    RAN="$T/ran"
    EVIL="$T/evil-ran"
    make_marker_repo "$MAIN" "$RAN" commit
    add_worktree "$MAIN" "$T/wt"
    for RUN_CWD in "$MAIN" "$T/wt"; do
      rm -f "$RAN"
      run_cmd env "ZDOTDIR=$ZD" "$ZSH" -l
      expect "17（zsh、alias $alias_body）: 作業ディレクトリが ${RUN_CWD#"$T"/} のとき、本体の notify.sh が実行される" ran_main
    done
  done
else
  skip "17（zsh）: zsh が無いので、zsh での確かめを省いた（sh での確かめは行った）"
fi

# --- 試験 18: 実行するものを 3 つのファイルに限る決まり ---

# シェルのスクリプト $1 から、注釈だけの行を除いたものを出す
code_lines() {
  grep -vE '^[[:space:]]*#' "$1" || true
}
no_loader_in_sh() {
  ! code_lines "$1" | grep -nE '(^|[;&|({[:space:]])(source|eval)([[:space:]]|$)|^[[:space:]]*\.[[:space:]]+[^[:space:]]'
}
only_node_imports() {
  local lines bad
  lines="$(grep -vE '^[[:space:]]*//' "$1" | grep -E '(^|[^A-Za-z0-9_.])(import|require)([[:space:]({]|$)' || true)"
  [ -n "$lines" ] || return 1
  bad="$(grep -vE "^import \{ [A-Za-z, ]+ \} from 'node:[a-z_/]+';\$" <<<"$lines" || true)"
  [ -z "$bad" ]
}
no_dynamic_code_in_mjs() {
  ! grep -vE '^[[:space:]]*//' "$1" | grep -nE 'eval\(|Function\(|createRequire|node:(vm|module|child_process|worker_threads)'
}
only_node_require_in_sh() {
  ! code_lines "$1" | grep -E 'require\(' | grep -vE 'require\("node:[a-z_/]+"\)'
}
expect "18: notify-paths.mjs の読み込みは、node: で始まるものだけ" only_node_imports "$H/notify-paths.mjs"
expect "18: notify-paths.mjs に、文字列をコードとして実行する書き方と、別のプロセスを起こすモジュールが無い" no_dynamic_code_in_mjs "$H/notify-paths.mjs"
expect "18: notify.sh に、ほかのファイルを読み込んで実行する行が無い" no_loader_in_sh "$H/notify.sh"
expect "18: check-docs.sh に、ほかのファイルを読み込んで実行する行が無い" no_loader_in_sh "$H/check-docs.sh"
expect "18: notify.sh の中の node のコードの読み込みは、node: で始まるものだけ" only_node_require_in_sh "$H/notify.sh"
printf '#!/bin/bash\n  source ./x.sh\n' > "$TMP_ROOT/loader-1.sh"
printf '#!/bin/bash\n. ./x.sh\n' > "$TMP_ROOT/loader-2.sh"
printf '#!/bin/bash\ntrue && eval "$x"\n' > "$TMP_ROOT/loader-3.sh"
printf "import { a } from './a.mjs';\n" > "$TMP_ROOT/loader-4.mjs"
printf "import { a } from 'node:fs';\nconst b = await import('./b.mjs');\n" > "$TMP_ROOT/loader-5.mjs"
bad_samples_found() {
  ! no_loader_in_sh "$TMP_ROOT/loader-1.sh" > /dev/null && ! no_loader_in_sh "$TMP_ROOT/loader-2.sh" > /dev/null \
    && ! no_loader_in_sh "$TMP_ROOT/loader-3.sh" > /dev/null && ! only_node_imports "$TMP_ROOT/loader-4.mjs" \
    && ! only_node_imports "$TMP_ROOT/loader-5.mjs"
}
expect "18: 対照: 検索が、読み込みの行の見本を見つける" bad_samples_found

# --- フックの設定のファイルの形（早期通知の設計の「フックの設定」） ---

settings_ok() {
  node -e '
    const fs = require("node:fs");
    const s = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    const c = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
    const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
    const problems = [];
    if (!same(Object.keys(s).sort(), ["hooks", "permissions"])) problems.push("settings.json の最上位は permissions と hooks だけにする");
    if (!same(s.permissions, { deny: ["Read(.env*)", "Read(!.env.example)"] })) problems.push("permissions は、決めた 2 つの拒否の規則だけにする");
    if (!same(s.hooks, { PostToolUse: [{ matcher: "Edit|Write", hooks: [{ type: "command",
      command: "/bin/bash \"$CLAUDE_PROJECT_DIR\"/scripts/harness/notify.sh claude", timeout: 20 }] }] })) {
      problems.push("settings.json の hooks が、決めた形と違う");
    }
    const group = c.hooks && c.hooks.PostToolUse && c.hooks.PostToolUse[0];
    const hook = group && group.hooks && group.hooks[0];
    if (!same(Object.keys(c), ["hooks"]) || !same(Object.keys(c.hooks), ["PostToolUse"]) || c.hooks.PostToolUse.length !== 1
      || group.matcher !== "apply_patch" || group.hooks.length !== 1 || hook.type !== "command" || hook.timeout !== 20) {
      problems.push("hooks.json が、決めた形と違う");
    }
    const text = fs.readFileSync(process.argv[1], "utf8") + fs.readFileSync(process.argv[2], "utf8");
    if (/\/Users\/|\/home\/|ANTHROPIC_|apiKeyHelper/.test(text)) problems.push("設定に、ホームの絶対パスか、置かないと決めた項目がある");
    for (const p of problems) console.error(p);
    process.exit(problems.length === 0 ? 0 : 1);
  ' "$ROOT/.claude/settings.json" "$ROOT/.codex/hooks.json"
}
expect "設定: .claude/settings.json と .codex/hooks.json が、決めた形である" settings_ok
expect "設定: .codex/config.toml を置いていない" no_file "$ROOT/.codex/config.toml"

total=$((passed + failed))
if [ "$failed" -gt 0 ]; then
  echo "notify.test: $total 件中 $failed 件が期待と違います" >&2
  exit 1
fi
echo "notify.test: $total 件中 $total 件が期待どおり"
