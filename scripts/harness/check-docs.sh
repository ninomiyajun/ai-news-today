#!/usr/bin/env bash
# 文書の検査。手元と CI で同じコマンドを使う: npm run check:docs
#
# 確かめること（ハーネスの導入の P2 までの範囲。後の段階で、受け入れ確認の記録などを足す）:
#   1. AGENTS.md に導入済みの印（「ハーネスの版: N」の 1 行）があり、その版で必須のファイルが実在する
#   2. CLAUDE.md が「@AGENTS.md」の 1 行（末尾の改行を含む）と完全に一致する
#   3. AGENTS.md の「文書の地図」に書いたパスが実在する
#   4. Markdown の相対リンクの先が実在する。対応する構文は、インラインのリンクと画像（[文字](先)、![文字](先)）で、
#      先に空白も「)」も含まないものだけ。参照形式（[文字][名前] と [名前]: 先）、山括弧で囲んだ先、タイトル付きの先、
#      自動リンク（<https://...>）、HTML の a 要素は対象外で、リンク先が無くても検出しない。
#      一覧にあるのに検査できない Markdown（シンボリックリンク、読めないもの）は失敗にする
#   5. docs/adr/ の ADR が、すべて目録（docs/adr/README.md）に載っている
#   6. AGENTS.md の行数が上限以下
#   7. ARCHITECTURE.md に書いたパスが実在する
#   8. 進行中と完了の計画（docs/exec-plans/active/ と completed/ の直下の .md）に、docs/PLANS.md の「必須の節」の
#      一覧にある見出しが、すべて行として揃っている。``` で囲んだコードブロックの中の行は見出しに数えない。
#      CR（\r）を含む計画は、改行を直すよう求める 1 件の失敗にし、見出しは照合しない。
#      計画が 0 件のときも、docs/PLANS.md から見出しを読み取れることは確かめる
# 失敗したときは、項目ごとに直し方を表示して、終了コード 1 で終わる。
set -euo pipefail
export LC_ALL=C

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

AGENTS_MAX_LINES=120
errors=0

fail() {
  echo "check-docs: NG: $1" >&2
  echo "  直し方: $2" >&2
  errors=$((errors + 1))
}

# 版ごとの必須のファイル（末尾が / のものはディレクトリ）
required_for_version() {
  case "$1" in
    1)
      cat <<'EOF'
AGENTS.md
CLAUDE.md
ARCHITECTURE.md
.gitignore
docs/adr/README.md
docs/PLANS.md
docs/exec-plans/active/
docs/exec-plans/completed/
docs/QUALITY_SCORE.md
docs/quality-eval/README.md
docs/quality-eval/tasks/
docs/quality-eval/results/
scripts/harness/check-docs.sh
scripts/harness/check-arch.sh
scripts/harness/check-secrets.sh
scripts/harness/check-secrets.mjs
.dependency-cruiser.cjs
.secretlintrc.json
.github/workflows/harness.yml
.github/dependabot.yml
EOF
      ;;
    *)
      return 1
      ;;
  esac
}

# 1. 導入済みの印と、必須のファイル
if [ ! -f AGENTS.md ]; then
  fail "AGENTS.md がありません" "リポジトリのルートに AGENTS.md を置く（ハーネスの規約の正本）"
  version=""
else
  version="$(sed -n 's/^ハーネスの版: \([0-9][0-9]*\)$/\1/p' AGENTS.md | head -n 1)"
  if [ -z "$version" ]; then
    fail "AGENTS.md に導入済みの印（「ハーネスの版: N」の 1 行）がありません" \
      "AGENTS.md に「ハーネスの版: 1」の行を戻す。このプロジェクトは導入済みで、印が無いと必須のファイルの検査が働かないため"
  fi
fi

if [ -n "$version" ]; then
  if ! required="$(required_for_version "$version")"; then
    fail "ハーネスの版 $version の必須のファイルの一覧がありません" \
      "scripts/harness/check-docs.sh の required_for_version に、版 $version の一覧を足す"
  else
    while IFS= read -r path; do
      [ -z "$path" ] && continue
      case "$path" in
        */) [ -d "$path" ] || fail "必須のディレクトリ $path がありません（ハーネスの版 $version）" \
              "$path を作る（空なら .gitkeep を置く）。不要になったのなら、版を上げて required_for_version を直す" ;;
        *) [ -f "$path" ] || fail "必須のファイル $path がありません（ハーネスの版 $version）" \
              "$path を戻す。不要になったのなら、版を上げて required_for_version を直す" ;;
      esac
    done <<EOF
$required
EOF
  fi
fi

# 2. CLAUDE.md が「@AGENTS.md」の 1 行だけであること（指示が AGENTS.md と CLAUDE.md に分かれないようにする）
if [ -f CLAUDE.md ] && ! printf '@AGENTS.md\n' | cmp -s - CLAUDE.md; then
  fail "CLAUDE.md が「@AGENTS.md」の 1 行（末尾の改行を含む）と一致しません" \
    "CLAUDE.md を「@AGENTS.md」の 1 行にし、足したい指示は AGENTS.md に書く。CLAUDE.md があると Claude Code は AGENTS.md を自分からは読まないため"
fi

# 3. 文書の地図のパス
if [ -f AGENTS.md ]; then
  map="$(awk '/^## 文書の地図/{on=1; next} /^## /{on=0} on' AGENTS.md)"
  if [ -z "$map" ]; then
    fail "AGENTS.md に「## 文書の地図」の節がありません" "AGENTS.md に、種類・パス・読む条件の表を持つ「## 文書の地図」の節を置く"
  else
    while IFS= read -r p; do
      [ -z "$p" ] && continue
      [ -e "$p" ] || fail "文書の地図のパス $p がありません" "AGENTS.md の文書の地図を実物に合わせるか、$p を作る"
    done <<EOF
$(printf '%s\n' "$map" | grep '^|' | grep -oE '`[^`]+`' | tr -d '`' || true)
EOF
  fi
fi

# 4. Markdown の相対リンク（対応する構文は冒頭の説明のとおり）。一覧は git から NUL 区切りで得る
#    （日本語の名前を引用符付きの形にしないため）。node_modules などの除外は .gitignore に従う。
md_list="$(mktemp)"
trap 'rm -f "$md_list"' EXIT
git -c core.quotePath=false ls-files -z --cached --others --exclude-standard -- '*.md' > "$md_list"
while IFS= read -r -d '' md; do
  if [ -L "$md" ]; then
    fail "$md はシンボリックリンクです" "シンボリックリンクをやめ、実体のファイルを置く"
    continue
  fi
  if [ ! -f "$md" ]; then
    # 作業ツリーで削除したファイルは調べない。それ以外で読めないものは失敗にする
    [ -n "$(git --literal-pathspecs ls-files --deleted -- "$md")" ] && continue
    fail "$md を検査できません（一覧にあるのにファイルとして読めません）" "$md の種類と読み取りの権限を確かめる"
    continue
  fi
  set +e
  links="$(grep -oE '\]\([^)[:space:]]+\)' -- "$md")"
  rc=$?
  set -e
  if [ "$rc" -gt 1 ]; then
    fail "$md を grep で読めません（終了コード $rc）" "$md の読み取りの権限と中身を確かめる"
    continue
  fi
  dir="$(dirname -- "$md")"
  while IFS= read -r target; do
    [ -z "$target" ] && continue
    case "$target" in
      http://*|https://*|mailto:*|\#*) continue ;;
    esac
    path="${target%%#*}"
    [ -z "$path" ] && continue
    [ -e "$dir/$path" ] || fail "$md のリンク先 $target がありません" "$md のリンクを実在するパスに直す"
  done <<EOF
$(printf '%s\n' "$links" | sed -e 's/^](//' -e 's/)$//')
EOF
done < "$md_list"

# 5. ADR の目録
if [ -f docs/adr/README.md ]; then
  for adr in docs/adr/[0-9][0-9][0-9][0-9]-*.md; do
    [ -e "$adr" ] || continue
    name="$(basename "$adr")"
    grep -qF "($name)" docs/adr/README.md || fail "ADR $name が目録 docs/adr/README.md に載っていません" \
      "docs/adr/README.md の目録の表に、[番号]($name) の行を足す"
  done
fi

# 6. AGENTS.md の行数
if [ -f AGENTS.md ]; then
  lines="$(wc -l < AGENTS.md | tr -d ' ')"
  if [ "$lines" -gt "$AGENTS_MAX_LINES" ]; then
    fail "AGENTS.md が $lines 行で、上限 $AGENTS_MAX_LINES 行を超えています" \
      "詳細を docs/ の文書へ移し、AGENTS.md には決まりの要約と文書の地図の行だけを残す"
  fi
fi

# 7. ARCHITECTURE.md に書いたパス
if [ -f ARCHITECTURE.md ]; then
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    [ -e "$p" ] || fail "ARCHITECTURE.md に書いたパス $p がありません" "ARCHITECTURE.md を実物に合わせるか、$p を作る"
  done <<EOF
$(grep -oE '`[^`]+`' ARCHITECTURE.md | tr -d '`' | grep -E '^(src|docs|scripts|\.github)/|^[A-Za-z0-9._-]+\.(md|cjs|mjs|ts|json|yml)$' || true)
EOF
fi

# 8. 計画の必須の節。見出しの一覧は docs/PLANS.md の「## 必須の節」から読み取る（一覧を 2 か所に持たないため）。
#    読み取るのは「1. `## 目的`: 説明」の形の行の、バッククォートで囲んだ部分だけ
if [ -f docs/PLANS.md ]; then
  plan_headings="$(awk '/^## 必須の節$/{on=1; next} /^## /{on=0} on' docs/PLANS.md \
    | sed -n 's/^[0-9][0-9]*\. `\(## [^`]*\)`.*$/\1/p')"
  if [ -z "$plan_headings" ]; then
    fail "docs/PLANS.md の「## 必須の節」から、計画の必須の見出しを読み取れません" \
      '「## 必須の節」の節に、「1. `## 目的`: 説明」の形で、見出しを 1 行ずつ書く'
  else
    for plan in docs/exec-plans/active/*.md docs/exec-plans/completed/*.md; do
      [ -e "$plan" ] || [ -L "$plan" ] || continue
      if [ -L "$plan" ] || [ ! -f "$plan" ]; then
        fail "計画 $plan を検査できません（シンボリックリンクか、通常のファイルではありません）" \
          "$plan を、実体のファイルとして置く"
        continue
      fi
      if grep -q "$(printf '\r')" "$plan"; then
        fail "計画 $plan に CR（\\r）が含まれています" "改行を LF にしてください（CR があると見出しの行が一致しないため）"
        continue
      fi
      # ``` で始まる行ごとに、コードブロックの中と外を切り替え、外の行だけを照合に使う
      plan_lines="$(awk '/^```/{inside=!inside; next} !inside' "$plan")"
      while IFS= read -r heading; do
        [ -z "$heading" ] && continue
        grep -qxF -- "$heading" <<<"$plan_lines" || fail "計画 $plan に、必須の節の見出し「$heading」の行がありません" \
          "$plan に「$heading」の行を足す（前後に文字を足さない）。書くことがまだ無い節も、見出しは置く（docs/PLANS.md の「必須の節」）"
      done <<EOF
$plan_headings
EOF
    done
  fi
fi

if [ "$errors" -gt 0 ]; then
  echo "check-docs: $errors 件の問題があります" >&2
  exit 1
fi
echo "check-docs: OK（ハーネスの版 ${version}）"
