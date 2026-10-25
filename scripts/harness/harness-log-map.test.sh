#!/usr/bin/env bash
# 文書の検査の本体の検査 12（検査の由来の記録）が、このプロジェクトの文書の地図のまま働くことの試験（写しでない、このプロジェクト
# だけの試験）。手元と CI で同じコマンドを使う: npm run test:harness
#
# 本体の写しの試験（scripts/harness/check-docs.test.sh）は、検査 12 を、試験の中で作る最小の地図（検査の行が scripts/harness/ だけ）で
# 確かめる。この試験は、このプロジェクトの AGENTS.md の文書の地図の「検査（…）」の行に書いたパス（.dependency-cruiser.cjs など）が、
# 検査を定めるファイルとして読まれることを確かめる。
#
# 作り方: 作業ツリーの今の中身（コミットする対象のファイル。未コミットの変更を含み、作業ツリーで消したファイルと
# docs/exec-plans/active/ の下の .md を除く）を、リポジトリの外の一時の置き場に写し、git init してコミットし、origin/main を
# そのコミットにする。検査は GITHUB_BASE_REF・HARNESS_BASE_REF を外し、基準の日を固定して流す。変える前の状態で検査が通り、
# 検査 12 の NG の行が無いことを確かめてから（通らなければ、場合を流さずに失敗にする）、場合ごとに置き場を作り直して変更を
# 作業ツリーに加え、終了コードと検査 12 の NG の行の有無で判定する。
# 一時のリポジトリの作り方は、scripts/harness/project-config.test.sh と同じ（計画の「一時のリポジトリの作り方」）。変えるときは、両方を同じ変更で直す。
# docs/exec-plans/active/ の下の .md を写さないのは、基準の日（HARNESS_TODAY）を固定して流すためである。固定した日より後の
# 日付だけを持つ進行中の計画（後で起票した計画）は、本体の検査 11（古い計画）が日付を数えられず失敗にするので、試験が
# 日が経つと落ちる。あわせて、書きかけの計画の中身（本体の検査 8・9 も進行中の計画を読む）に結果を左右させないためでもある。
#
# 受け持てない形: 地図の「検査（…）」の行のパスのうち、.dependency-cruiser.cjs のほかが読まれることは確かめない（読み方は同じ
# 1 か所の処理で、本体の写しの試験が受け持つ）。
set -euo pipefail
export LC_ALL=C

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

passed=0
failed=0
LOG_NG_RE='^check-docs: NG: .*検査の由来の記録'

tgit() {
  git -c user.name=test -c user.email=test -c commit.gpgsign=false -c core.hooksPath=/dev/null \
    -c core.fsmonitor=false "$@"
}

# 写す一覧（NUL 区切り）を一度だけ作る。作業ツリーで消した項目と、docs/exec-plans/active/ の下の .md を除く
git -C "$ROOT" -c core.fsmonitor=false ls-files -z --cached --others --exclude-standard > "$TMP_ROOT/all.z"
git -C "$ROOT" -c core.fsmonitor=false ls-files -z --deleted > "$TMP_ROOT/deleted.z"
perl -0 -e '
  open(my $d, "<", $ARGV[0]) or die; local $/ = "\0"; my %del; while (<$d>) { chomp; $del{$_} = 1 }
  open(my $a, "<", $ARGV[1]) or die; my %seen;
  while (<$a>) { chomp; next if $del{$_} || $seen{$_}++; next if m{^docs/exec-plans/active/.*\.md$}; print "$_\0" }
' "$TMP_ROOT/deleted.z" "$TMP_ROOT/all.z" > "$TMP_ROOT/copy.z"

# 一時のリポジトリを作る。$1 = 置き場
make_repo() {
  local d="$1" p
  mkdir -p "$d/docs/exec-plans/active"
  while IFS= read -r -d '' p; do
    mkdir -p "$d/$(dirname "$p")"
    if ! cp -pP "$ROOT/$p" "$d/$p"; then
      echo "harness-log-map.test: NG: $p を一時のリポジトリに写せません" >&2
      exit 2
    fi
  done < "$TMP_ROOT/copy.z"
  tgit -C "$d" init -q
  tgit -C "$d" add -A
  tgit -C "$d" commit -q -m "見本"
  tgit -C "$d" update-ref refs/remotes/origin/main HEAD
}

# 一時のリポジトリ $1 で検査を流し、出力を OUT、終了コードを RC に入れる
run_check() {
  set +e
  OUT="$(cd "$1" && env -u GITHUB_BASE_REF -u HARNESS_BASE_REF HARNESS_TODAY=2026-10-25 bash scripts/harness/check-docs.sh </dev/null 2>&1)"
  RC=$?
  set -e
}

# 変える前の状態
make_repo "$TMP_ROOT/base"
run_check "$TMP_ROOT/base"
if [ "$RC" -ne 0 ] || grep -qE "$LOG_NG_RE" <<<"$OUT"; then
  echo "harness-log-map.test: NG: 変える前の一時のリポジトリで、文書の検査が通りません（終了コード $RC）。場合を流さずに失敗にします" >&2
  printf '%s\n' "$OUT" | sed 's/^/    /' >&2
  exit 1
fi
echo "ok: 変える前の状態は通り、検査の由来の記録の NG の行が無い"
passed=$((passed + 1))

# 場合を 1 つ動かす。$1 = 名前、$2 = 期待（pass / fail）、$3 = 失敗のときに出力に含まれるべき文言、$4 = 変更の関数
run_case() {
  local name="$1" expect="$2" want="$3" change="$4" d
  d="$TMP_ROOT/case-$((passed + failed))"
  make_repo "$d"
  "$change" "$d"
  run_check "$d"
  if [ "$expect" = pass ] && [ "$RC" -eq 0 ] && ! grep -qE "$LOG_NG_RE" <<<"$OUT"; then
    echo "ok: $name（通る）"
    passed=$((passed + 1))
  elif [ "$expect" = fail ] && [ "$RC" -eq 1 ] && grep -qF -- "$want" <<<"$OUT"; then
    echo "ok: $name（失敗する: $want）"
    passed=$((passed + 1))
  else
    echo "NG: $name（期待: $expect、終了コード: $RC）" >&2
    printf '%s\n' "$OUT" | sed 's/^/    /' >&2
    failed=$((failed + 1))
  fi
}

change_depcruise() { printf '%s\n' "// 試験の変更" >> "$1/.dependency-cruiser.cjs"; }
change_depcruise_with_row() {
  change_depcruise "$1"
  printf '%s\n' "| 試験の検査 | 試験 | なし | 試験 | |" >> "$1/docs/harness-log.md"
}
change_src_comment() {
  local f
  f="$(tgit -C "$1" ls-files -- 'src/*.ts' | head -n 1)"
  if [ -z "$f" ]; then
    echo "harness-log-map.test: NG: 一時のリポジトリに src/ の下の .ts のファイルがありません" >&2
    exit 1
  fi
  printf '%s\n' "// 試験の変更" >> "$1/$f"
}

run_case "V7: .dependency-cruiser.cjs だけを変えた差分は失敗する" fail \
  "検査を定めるファイル（.dependency-cruiser.cjs）を変えたのに、検査の由来の記録 docs/harness-log.md に行が足されていません" change_depcruise
run_case "V8: 同じ変更に由来の記録の行を足すと通る" pass "" change_depcruise_with_row
run_case "V9: 地図の検査の行に無いファイル（src/ の下）だけを変えても記録を求めない" pass "" change_src_comment

total=$((passed + failed))
if [ "$failed" -gt 0 ]; then
  echo "harness-log-map.test: $total 件中 $failed 件が期待と違います" >&2
  exit 1
fi
echo "harness-log-map.test: $total 件中 $total 件が期待どおり"
