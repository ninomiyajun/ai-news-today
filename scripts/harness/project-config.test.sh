#!/usr/bin/env bash
# このプロジェクトの設定と文書が、検査の本体の写しの下で決めたとおりに働くことの試験（写しでない、このプロジェクトだけの
# 試験）。手元と CI で同じコマンドを使う: npm run test:harness
#
# 写しの試験（check-docs.test.sh・notify.test.sh・drift-scan.test.sh）は、試験の中で作る見本で本体を確かめるので、このプロジェクト
# だけの値（scripts/harness/harness.conf の arch_path_prefixes の templates、フックの設定の permissions、実物の品質目標と技術的負債の
# 一覧）は確かめない。置き換えの前の試験にあった、それらを確かめる項目をここに置く（場合の名前は置き換えの前と同じ）。
#
# 文書の検査と定期の走査の場合は、作業ツリーの今の中身（コミットする対象のファイル。未コミットの変更を含み、作業ツリーで
# 消したファイルと docs/exec-plans/active/ の下の .md を除く）を、リポジトリの外の一時の置き場に写し、場合ごとの変更を加えてから
# git init してコミットし、origin/main をそのコミットにして流す。
# 一時のリポジトリの作り方は、scripts/harness/harness-log-map.test.sh と同じ（計画の「一時のリポジトリの作り方」）。変えるときは、両方を同じ変更で直す。
# docs/exec-plans/active/ の下の .md を写さないのは、基準の日（HARNESS_TODAY）を固定して流すためである。固定した日より後の
# 日付だけを持つ進行中の計画（後で起票した計画）は、本体の検査 11（古い計画）が日付を数えられず失敗にするので、試験が
# 日が経つと落ちる。あわせて、書きかけの計画の中身（本体の検査 8・9 も進行中の計画を読む）に結果を左右させないためでもある。
set -euo pipefail
export LC_ALL=C

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

passed=0
failed=0

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

# 一時のリポジトリを作る。$1 = 置き場、$2 = コミットの前に加える変更の関数（無ければ空）
make_repo() {
  local d="$1" change="${2:-}" p
  mkdir -p "$d/docs/exec-plans/active"
  while IFS= read -r -d '' p; do
    mkdir -p "$d/$(dirname "$p")"
    if ! cp -pP "$ROOT/$p" "$d/$p"; then
      echo "project-config.test: NG: $p を一時のリポジトリに写せません" >&2
      exit 2
    fi
  done < "$TMP_ROOT/copy.z"
  if [ -n "$change" ]; then "$change" "$d"; fi
  tgit -C "$d" init -q
  tgit -C "$d" add -A
  tgit -C "$d" commit -q -m "見本"
  tgit -C "$d" update-ref refs/remotes/origin/main HEAD
}

# 結果を 1 件数える。$1 = 名前、$2 = 合否（0 なら合格）、$3 = 不合格のときに出す出力
record() {
  if [ "$2" -eq 0 ]; then
    echo "ok: $1"
    passed=$((passed + 1))
  else
    echo "NG: $1" >&2
    printf '%s\n' "$3" | sed 's/^/    /' >&2
    failed=$((failed + 1))
  fi
}

# 文書の検査の場合を 1 つ動かす。$1 = 名前、$2 = 期待（pass / fail）、$3 = 失敗のときに出力に含まれるべき文言、$4 = 変更の関数
run_docs_case() {
  local name="$1" expect="$2" want="$3" change="$4" d out rc ok=1
  d="$TMP_ROOT/case-$((passed + failed + 1))"
  make_repo "$d" "$change"
  set +e
  out="$(cd "$d" && env -u GITHUB_BASE_REF -u HARNESS_BASE_REF HARNESS_TODAY=2026-10-25 bash scripts/harness/check-docs.sh </dev/null 2>&1)"
  rc=$?
  set -e
  if [ "$expect" = pass ] && [ "$rc" -eq 0 ]; then ok=0; name="$name（通る）"
  elif [ "$expect" = fail ] && [ "$rc" -eq 1 ] && grep -qF -- "$want" <<<"$out"; then ok=0; name="$name（失敗する: $want）"
  fi
  record "$name" "$ok" "期待: $expect、終了コード: $rc
$out"
}

# --- ARCHITECTURE.md に書いた templates/ のパス（harness.conf の arch_path_prefixes に templates があること） ---

add_templates_path() { printf '%s\n' "" "ひな形の置き場は \`templates/module/\` である。" >> "$1/ARCHITECTURE.md"; }
add_missing_templates_path() { printf '%s\n' "" "ひな形の置き場は \`templates/no-such-module/\` である。" >> "$1/ARCHITECTURE.md"; }

run_docs_case "設計の正本: 書いた templates/ のパスが実在する" pass "" add_templates_path
run_docs_case "設計の正本: 書いた templates/ のパスが無い" fail "ARCHITECTURE.md に書いたパス templates/no-such-module/ がありません" add_missing_templates_path

# --- 定期の走査が、実物の品質目標と技術的負債の一覧を読める ---

name="通る 15: 実物の品質目標と技術的負債の一覧を、4/表・3/表・場所を読めない行なしで読める"
d="$TMP_ROOT/scan"
make_repo "$d"
# 報告を公開する前の秘匿値の検査（scripts/harness/check-secrets.sh）が依存を使うので、作業ツリーの依存を指すリンクを置く
# （/node_modules は .gitignore で除くので、一時のリポジトリの検査の対象にはならない）
ln -s "$ROOT/node_modules" "$d/node_modules"
mkdir "$TMP_ROOT/scan-out"
set +e
out="$(cd "$d" && env -u GITHUB_ACTIONS DRIFT_SCAN_TEST_TODAY=2026-10-25 DRIFT_SCAN_TEST_STAGES="lint=0" \
  bash scripts/harness/drift-scan.sh --out "$TMP_ROOT/scan-out" </dev/null 2>&1)"
rc=$?
set -e
bad=""
if [ "$rc" -ne 0 ] || [ ! -f "$TMP_ROOT/scan-out/report.md" ]; then
  bad="終了コード $rc か、報告がありません"
else
  bad="$(grep -E '^\| `(3|4)/表`|^\| `3/TD-[0-9]+`.*場所を読めない' "$TMP_ROOT/scan-out/report.md" || true)"
  # 読めたことも確かめる（表を 1 行も読まずに通らないため）。実物の docs/QUALITY_SCORE.md の表 2 の層 src/domain/ の行（検査の
  # 識別子 check:arch）と、表 1 の「秘匿値がリポジトリに無い」の行（段に無い識別子 check:secrets:push は「照合しない」）
  grep -qE '^\| `4/層:src/domain/` \|.*check:arch=成功' "$TMP_ROOT/scan-out/report.md" \
    || bad="${bad:+$bad
}報告に、層 src/domain/ の行（check:arch=成功）がありません"
  grep -qE '^\| `4/領域:秘匿値がリポジトリに無い` \|.*check:secrets:push=照合しない' "$TMP_ROOT/scan-out/report.md" \
    || bad="${bad:+$bad
}報告に、領域「秘匿値がリポジトリに無い」の行（check:secrets:push=照合しない）がありません"
  # 実物の技術的負債の一覧の各行（識別子と、場所の列の最初のバッククォートの中のパス）について、走査の報告に
  # 「| `3/<識別子>` | `<パス>` |」の行があることを求める（写しの scripts/harness/drift-scan.sh の項目 3 の行の作り）。行が 1 つも
  # 無ければ「| `3/なし` |」の行を求める
  td_rows="$(awk -F'|' '/^\| TD-[0-9]+ \|/ { id = $2; gsub(/^[ \t]+|[ \t]+$/, "", id); loc = $4
    if (match(loc, /`[^`]+`/)) print id "\t" substr(loc, RSTART + 1, RLENGTH - 2); else print id "\t" }' "$ROOT/docs/exec-plans/tech-debt-tracker.md")"
  if [ -z "$td_rows" ]; then
    grep -qF '| `3/なし` |' "$TMP_ROOT/scan-out/report.md" || bad="${bad:+$bad
}報告に、技術的負債が無いことの行（3/なし）がありません"
  else
    while IFS="$(printf '\t')" read -r td_id td_path; do
      grep -qF "| \`3/$td_id\` | \`$td_path\` |" "$TMP_ROOT/scan-out/report.md" || bad="${bad:+$bad
}報告に、技術的負債 $td_id の行（場所 $td_path）がありません"
    done <<EOF
$td_rows
EOF
  fi
fi
record "$name" "$([ -z "$bad" ] && echo 0 || echo 1)" "$bad
$out"

# --- フックの設定（.claude/settings.json と .codex/hooks.json） ---

# 規約のひな形 rules-2026.10.25-1 の assets/codex-hooks.json の中身を、そのまま写して持つ（CI では規約のリポジトリを読めないので、
# 実行のときに読まない）。.codex/hooks.json の各フックの command は、この中の command と一字一句同じであることを求める。
# .claude/settings.json の command は、下の期待値（同じ版の assets/claude-settings.json の command）と全文で照らす。
# ひな形が変わって取り込んだら、同じ変更でここも写し直す（docs/adr/0007-harness-engine-copies.md の「更新のたびに行うこと」）
cat > "$TMP_ROOT/codex-hooks.template.json" <<'CODEX_HOOKS_TEMPLATE'
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "apply_patch",
        "hooks": [
          {
            "type": "command",
            "command": "root=$(git -c core.fsmonitor=false worktree list --porcelain | sed -n '1s/^worktree //p'); h=scripts/harness; harness_notify_git() { git --no-pager -C \"$root\" -c core.fsmonitor=false \"$@\"; }; test -n \"$root\" && test \"$(harness_notify_git rev-parse --is-bare-repository)\" = false && harness_notify_git cat-file -e \"HEAD:$h/notify.sh\" && harness_notify_git cat-file -e \"HEAD:$h/check-docs.sh\" && harness_notify_git diff --no-ext-diff --no-textconv --quiet HEAD -- \"$h\" && test -z \"$(harness_notify_git ls-files --others --exclude-standard -- \"$h\")\" && test -f \"$root/$h/notify.sh\" && exec /bin/bash \"$root/$h/notify.sh\" codex; printf '%s\\n' '{\"hookSpecificOutput\":{\"hookEventName\":\"PostToolUse\",\"additionalContext\":\"早期通知は動きませんでした（起動の前の確かめが成り立ちません）。作業は止めていません。\"}}'",
            "timeout": 20
          }
        ]
      }
    ]
  }
}
CODEX_HOOKS_TEMPLATE

settings_problems="$(node -e '
  const fs = require("node:fs");
  const s = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
  const c = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
  const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
  const problems = [];
  if (!same(Object.keys(s).sort(), ["hooks", "permissions"])) problems.push("settings.json の最上位は permissions と hooks だけにする");
  if (!same(s.permissions, { deny: ["Read(.env*)", "Read(!.env.example)"] })) problems.push("permissions は、決めた 2 つの拒否の規則だけにする");
  if (!same(s.hooks, { PostToolUse: [{ matcher: "Edit|Write", hooks: [{ type: "command",
    command: "/bin/bash \"$CLAUDE_PROJECT_DIR/scripts/harness/notify.sh\" claude", timeout: 20 }] }] })) {
    problems.push("settings.json の hooks が、決めた形と違う");
  }
  const group = c.hooks && c.hooks.PostToolUse && c.hooks.PostToolUse[0];
  const hook = group && group.hooks && group.hooks[0];
  if (!same(Object.keys(c), ["hooks"]) || !same(Object.keys(c.hooks), ["PostToolUse"]) || c.hooks.PostToolUse.length !== 1
    || group.matcher !== "apply_patch" || group.hooks.length !== 1 || hook.type !== "command" || hook.timeout !== 20) {
    problems.push("hooks.json が、決めた形と違う");
  }
  const t = JSON.parse(fs.readFileSync(process.argv[3], "utf8"));
  const commands = (x) => ((x.hooks && x.hooks.PostToolUse) || []).flatMap((g) => (g.hooks || []).map((h) => h.command));
  if (!same(commands(c), commands(t))) problems.push("hooks.json の command が、規約のひな形（rules-2026.10.25-1 の assets/codex-hooks.json）の command と一字一句同じでない");
  const text = fs.readFileSync(process.argv[1], "utf8") + fs.readFileSync(process.argv[2], "utf8");
  if (/\/Users\/|\/home\/|ANTHROPIC_|apiKeyHelper/.test(text)) problems.push("設定に、ホームの絶対パスか、置かないと決めた項目がある");
  console.log(problems.join("\n"));
' "$ROOT/.claude/settings.json" "$ROOT/.codex/hooks.json" "$TMP_ROOT/codex-hooks.template.json" 2>&1 || echo "設定を JSON として読めません")"
record "設定: .claude/settings.json と .codex/hooks.json が、決めた形である" "$([ -z "$settings_problems" ] && echo 0 || echo 1)" "$settings_problems"
record "設定: .codex/config.toml を置いていない" "$([ ! -e "$ROOT/.codex/config.toml" ] && echo 0 || echo 1)" ".codex/config.toml があります（docs/adr/0005-early-notify-hooks.md で、置かないと決めた）"

# --- 試験のつなぎ（package.json の test:harness） ---
# scripts/harness/ の直下の *.test.sh と *.test.mjs が、すべて test:harness に書かれていること。checks.d/ の下の試験は、写しの
# scripts/harness/check-docs.test.sh が最後に順に流すので除く。update で新しく作られた写しの試験をつなぎ忘れないため
# （docs/adr/0007-harness-engine-copies.md の「更新のたびに行うこと」）
test_harness="$(node -e 'const p = require(process.argv[1]); process.stdout.write(String((p.scripts || {})["test:harness"] || ""))' "$ROOT/package.json" 2>&1 || true)"
missing=""
for t in "$ROOT"/scripts/harness/*.test.sh "$ROOT"/scripts/harness/*.test.mjs; do
  [ -e "$t" ] || continue
  rel="scripts/harness/$(basename "$t")"
  case " $test_harness " in
    *" $rel "*) ;;
    *) missing="${missing:+$missing、}$rel" ;;
  esac
done
record "試験のつなぎ: scripts/harness/ の直下の試験が、すべて package.json の test:harness にある" "$([ -z "$missing" ] && echo 0 || echo 1)" \
  "test:harness に無い試験: $missing（package.json の test:harness の末尾に「&& bash <パス>」か「&& node <パス>」で足す）"

total=$((passed + failed))
if [ "$failed" -gt 0 ]; then
  echo "project-config.test: $total 件中 $failed 件が期待と違います" >&2
  exit 1
fi
echo "project-config.test: $total 件中 $total 件が期待どおり"
