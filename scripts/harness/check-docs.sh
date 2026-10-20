#!/usr/bin/env bash
# 文書の検査。手元と CI で同じコマンドを使う: npm run check:docs
#
# 確かめること:
#   1. AGENTS.md に導入済みの印（「ハーネスの版: N」の 1 行）があり、その版で必須のファイルが実在する
#   2. CLAUDE.md が「@AGENTS.md」の 1 行（末尾の改行を含む）と完全に一致する
#   3. AGENTS.md の「文書の地図」に書いたパスが実在する
#   4. Markdown の相対リンクの先が実在する。対応する構文は、インラインのリンクと画像（[文字](先)、![文字](先)）で、
#      先に空白も「)」も含まないものだけ。参照形式（[文字][名前] と [名前]: 先）、山括弧で囲んだ先、タイトル付きの先、
#      自動リンク（<https://...>）、HTML の a 要素は対象外で、リンク先が無くても検出しない。
#      一覧にあるのに検査できない Markdown（シンボリックリンク、読めないもの）は失敗にする
#   5. docs/adr/ の ADR が、すべて目録（docs/adr/README.md）に載っている
#   6. AGENTS.md の行数が上限以下
#   7. ARCHITECTURE.md に書いたパス（src/、docs/、scripts/、.github/、templates/ で始まるものと、根のファイル名）が実在する
#   8. 進行中と完了の計画（docs/exec-plans/active/ と completed/ の直下の .md のうち、名前が .acceptance.md で
#      終わらないもの）に、docs/PLANS.md の「必須の節」の一覧にある見出しが、すべて行として揃っている。
#      ``` で囲んだコードブロックの中の行は見出しに数えない。
#      CR（\r）を含む計画は、改行を直すよう求める 1 件の失敗にし、見出しは照合しない。
#      計画が 0 件のときも、docs/PLANS.md から見出しを読み取れることは確かめる
#   9. 受け入れ確認の記録（docs/PLANS.md の「受け入れ確認の記録」）。
#      - すべての記録（active/ と completed/ の直下の *.acceptance.md）: 同じディレクトリに同じ名前の計画がある。
#        絶対パスの形（/Users/、/home/、/private/、/tmp/、/var/folders/）を含まない
#      - completed/ の計画のうち、ファイル名の日付が docs/PLANS.md の「新しい書式の適用開始: YYYY-MM-DD」以降のもの
#        （日付で始まらない名前の計画も含める）: 検証の節の「### <識別子>」の見出しの下で、確かめ方が受け入れ確認の
#        基準ごとに、記録の中の「確かめた者: app-evaluator」の実行のうち、その基準の行を持つ最も後の実行の結果が「合格」。
#        あわせて、検証の節の書式（check_plan_verification）と、記録の書式（check_record_format）を確かめる。
#      - 計画と記録のどちらも、``` で囲んだコードブロックの中の行は数えない
#  10. 製品の仕様（書式と目録の正本は docs/product-specs/README.md）。
#      (1)〜(5) は docs/product-specs/ があるときだけ働く（利用者に見える機能を持つプロジェクトに置く、条件付きの種類のため）:
#      (1) 目録（README.md の「## 目録」の表）から、略号・仕様のリンク先・状態を読む。表の見出しの行が「略号・仕様・題・状態」の
#          4 列で、各行も 4 列。行が 0 行でもよい
#      (2) 直下の *.md（README.md を除く）がすべて目録に 1 行ずつある／目録のリンク先が直下の *.md で実在する／同じ仕様を指す行が
#          重ならない／略号が英大文字 2〜6 字で重複しない
#      (3) 状態が draft・approved・archived のどれか／仕様のファイルに状態の行（「状態:」で始まる行）が無い／
#          approved と archived の仕様に [NEEDS CLARIFICATION: が残っていない
#      (4) 各仕様に、README.md の「必須の節」の一覧の見出しがすべて行としてある（検査 8 と同じ関数）
#      (5) 「## 受け入れ基準」の「### <識別子> <題>」の識別子が「<略号>-<数字>」で、題があり、同じ仕様の中でも仕様をまたいでも
#          重複しない。各見出しの下に「- 前提:」「- 操作:」「- 期待する結果:」が 1 行ずつある。基準が 1 つ以上ある
#      archived の仕様は、(4) と (5) の書式（必須の節、題、識別子の形、項目の行、基準の数）を調べず、識別子だけを集める
#      （書式を後から変えても、過去の仕様を失敗にしないため）
#      (6)(7) は、仕様の置き場が無くても、新しい書式の計画（active/ と completed/）に対して常に働く:
#      (6) 検証の節の識別子のうち V<数字> でないものが、どれかの仕様の受け入れ基準として実在する。目的の節に書いた仕様と、
#          識別子の所属先の仕様の状態は、active/ の計画では approved、completed/ の計画では approved か archived
#      (7) 目的の節に書いた仕様のパス（docs/product-specs/<名前>.md。名前は英小文字・数字・ハイフン）が目録にあり、検証の節の仕様の識別子の所属先が、
#          目的の節に書いた仕様のどれかと一致する
#      仕様と計画のどちらも、``` で囲んだコードブロックの中の行は数えない
#  11. 古い計画（決まりの正本は docs/PLANS.md の「置き場所と名前」）。進行中の計画（docs/exec-plans/active/ の直下の .md のうち、
#      名前が .acceptance.md で終わらないもの）について、ファイル名の先頭の日付と、「## 進捗」の節の中の YYYY-MM-DD の形の
#      日付のうち、最も新しい日付が、基準の日より STALE_PLAN_DAYS 日以上前なら失敗にする。基準の日の 1 日後より後の日付は
#      数えない（予定の日付を、進めた日付と読み違えないため。手元と CI の時刻帯の差があるので、1 日後までは数える）。
#      暦に無い日付（平年の 2 月 29 日、4 月 31 日など）と、前後に数字が続く並び（12026-10-07 など）も数えない。
#      数える日付が 1 つも無い計画も失敗にする。``` で囲んだコードブロックの中の行は数えない。completed/ の計画と、
#      受け入れ確認の記録は対象にしない。
#      基準の日は、環境変数 HARNESS_TODAY（YYYY-MM-DD。試験用）があればその日、無ければ実行した日。
#      HARNESS_TODAY が暦にある日付でなければ失敗にする
#  12. 文書の検査の一覧（正本は下の CHECK_NAMES）。次の 2 つの括弧書きが、CHECK_NAMES の名前を同じ順に「、」でつないだものと
#      一致する（バッククォートは除いて比べる）:
#      - AGENTS.md の「## 検査のコマンド」の表の、コマンドが `npm run check:docs` の行の 1 列目「文書（…）」の括弧書き
#      - docs/QUALITY_SCORE.md の「## 目標」の表の、目標が「文書が実物と合っている」の行の測る項目の「文書の検査の不整合（…）」の括弧書き
#      あわせて、この冒頭の一覧の検査の番号が 1 から欠けずに並び、その数が CHECK_NAMES の数と同じであることを確かめる。
#      AGENTS.md に「## 検査のコマンド」の見出しの行が無いとき、docs/QUALITY_SCORE.md に「## 目標」の見出しの行が無いときも
#      失敗にする（見出しを変えると検査が黙って働かなくなるため。検査 3 の「## 文書の地図」と同じ扱い）
#  13. 通信の名前の一覧。eslint.config.mjs が無いときも失敗にする（同上）。
#      - ARCHITECTURE.md の「## 不変条件」の 2 の括弧書き「（`http`、…、`dgram` と、それぞれに `node:` を付けた名前、`undici`）」
#        を、「と、それぞれに `node:` を付けた名前、」の前の名前（node: 付きと無しの両方に展開する）と後の名前に分けて読んだ
#        名前の集まりが、eslint.config.mjs の NETWORK_MODULE_BASES を node: 付きと無しに展開し、NETWORK_MODULES の行の末尾に
#        足した名前を加えた集まりと一致する
#      - ARCHITECTURE.md の「## 不変条件」の 1 の「通信のための大域の名前（`fetch`、…、`EventSource`。」の名前の集まりが、
#        eslint.config.mjs の NETWORK_GLOBALS と一致する
#      不変条件の続きの行（字下げした行）は空白 1 つを挟んでつなぎ、連続する空白は 1 つにそろえてから読む（折り返しの位置が
#      空白に来ても読めるようにするため）。
#      eslint.config.mjs は実行せず、文字列として読む（この検査は早期通知からも動くので、ほかのファイルを実行しないため）。
#      コメントは解析しないので、3 つの定数のそれぞれについて、値を入れる書き方（「名前 =」）がファイル全体（コメントの中を
#      含む）でちょうど 1 か所で、それが行頭から始まる「const 名前 = 」の行であることも確かめる。
#      読み取りの前提（ARCHITECTURE.md の上の書き方と、eslint.config.mjs の 3 つの定数の行の形）が崩れたときは、黙って通さずに失敗にする
# 失敗したときは、項目ごとに直し方を表示して、終了コード 1 で終わる。
set -euo pipefail
export LC_ALL=C

# 検査する根。引数が無ければ、自分の置き場から決める（npm run check:docs と CI の呼び出し）。
# 引数 --root <絶対パス> があれば、その作業ツリーの根を検査する。早期通知（notify.sh）が、起動元のこのスクリプトで、
# 別の作業ツリーの文書を検査するための形である。検査 1 の必須のファイルの一覧と、検査 11 の日数は、どちらの場合も
# このスクリプトのものを使う。引数の値が、絶対パスでない、ディレクトリでない、git の作業ツリーの根でないときと、
# 引数の形が違うときは、検査せずに終了コード 2 で終わる。
# git の呼び出しには -c core.fsmonitor=false を付ける（検査する作業ツリーの設定で、ファイルの監視のプログラムを起動しないため）。
bad_root() {
  echo "check-docs: NG: $1" >&2
  echo "  使い方: check-docs.sh [--root <git の作業ツリーの根の絶対パス>]" >&2
  exit 2
}
if [ "$#" -eq 0 ]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
else
  if [ "$#" -ne 2 ] || [ "$1" != "--root" ]; then
    bad_root "引数の形が違います（受け取るのは --root <絶対パス> だけです）"
  fi
  ROOT="$2"
  case "$ROOT" in
    /*) ;;
    *) bad_root "--root の値が絶対パスではありません" ;;
  esac
  [ -d "$ROOT" ] || bad_root "--root の値がディレクトリではありません"
  root_top="$(git -c core.fsmonitor=false -C "$ROOT" rev-parse --show-toplevel 2>/dev/null)" \
    || bad_root "--root の値が git の作業ツリーの中ではありません"
  if [ -z "$root_top" ] || [ "$(cd -- "$ROOT" && pwd -P)" != "$(cd -- "$root_top" && pwd -P)" ]; then
    bad_root "--root の値が git の作業ツリーの根ではありません"
  fi
fi
# このスクリプト自身の絶対パス（検査 12 が冒頭の一覧を読む。下で検査する根へ移る前に決める）
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
cd -- "$ROOT"

AGENTS_MAX_LINES=120
# 進行中の計画を古いとみなす日数（検査 11）。変えるときは docs/PLANS.md の「置き場所と名前」も直す
STALE_PLAN_DAYS=30
# 検査の短い名前（検査 12）。番号の順に 1 行 1 つ（1 つ目が検査 1）。名前に「、」「（」「）」と「|」を使わない。
# 文書の検査が何を確かめるかの一覧の正本はここだけで、AGENTS.md の検査のコマンドの表の check:docs の行と、
# docs/QUALITY_SCORE.md の目標「文書が実物と合っている」の測る項目の括弧書きは、これを写したものにする。
# 検査を足す・外すときは、冒頭の「確かめること」、ここ、2 つの文書の括弧書きを同じ変更で直す
CHECK_NAMES=(
  "必須のファイル"
  "CLAUDE.md"
  "地図"
  "リンク"
  "目録"
  "行数"
  "ARCHITECTURE.md に書いたパス"
  "計画の必須の節"
  "受け入れ確認の記録"
  "製品の仕様の目録と状態"
  "古い計画"
  "文書の検査の一覧"
  "通信の名前の一覧"
)
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
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
md_list="$work_dir/md-list"
git -c core.fsmonitor=false -c core.quotePath=false ls-files -z --cached --others --exclude-standard -- '*.md' > "$md_list"
while IFS= read -r -d '' md; do
  if [ -L "$md" ]; then
    fail "$md はシンボリックリンクです" "シンボリックリンクをやめ、実体のファイルを置く"
    continue
  fi
  if [ ! -f "$md" ]; then
    # 作業ツリーで削除したファイルは調べない。それ以外で読めないものは失敗にする
    [ -n "$(git -c core.fsmonitor=false --literal-pathspecs ls-files --deleted -- "$md")" ] && continue
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
# 下の正規表現は、scripts/harness/drift-scan.sh の CHECK7_RE に写しがある（変えるときは同じ変更で両方を直す。
# 一致は scripts/harness/drift-scan.test.sh の試験「写し 1」が確かめる）
if [ -f ARCHITECTURE.md ]; then
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    [ -e "$p" ] || fail "ARCHITECTURE.md に書いたパス $p がありません" "ARCHITECTURE.md を実物に合わせるか、$p を作る"
  done <<EOF
$(grep -oE '`[^`]+`' ARCHITECTURE.md | tr -d '`' | grep -E '^(src|docs|scripts|\.github|templates)/|^[A-Za-z0-9._-]+\.(md|cjs|mjs|ts|json|yml)$' || true)
EOF
fi

# --- 検査 8〜11 で共有する読み取り ---

# ``` で始まる行ごとに、コードブロックの中と外を切り替え、外の行だけを出す
outside_code_blocks() {
  awk '/^```/{inside=!inside; next} !inside' "$1"
}

# 書式の文書（docs/PLANS.md、docs/product-specs/README.md）の「## 必須の節」から、必須の見出しを 1 行ずつ出す。
# 読み取るのは「1. `## 目的`: 説明」の形の行の、バッククォートで囲んだ部分だけ
required_headings_of() {
  awk '/^## 必須の節$/{on=1; next} /^## /{on=0} on' "$1" | sed -n 's/^[0-9][0-9]*\. `\(## [^`]*\)`.*$/\1/p'
}

# $1 のファイルに、$2（1 行に 1 つの見出し）のうち行として無い見出しを 1 行ずつ出す。コードブロックの中の行は数えない
missing_headings_in() {
  local body heading
  body="$(outside_code_blocks "$1")"
  while IFS= read -r heading; do
    [ -z "$heading" ] && continue
    grep -qxF -- "$heading" <<<"$body" || printf '%s\n' "$heading"
  done <<EOF
$2
EOF
}

# 計画 $1 が新しい書式の計画か（ファイル名の日付が「新しい書式の適用開始」以降か、日付で始まらない名前）。
# 適用開始の日付（format_start）を読めていないときは、どの計画も新しい書式とみなさない
is_new_format_plan() {
  local name date
  [ -n "${format_start:-}" ] || return 1
  name="$(basename "$1" .md)"
  date="$(printf '%s\n' "$name" | sed -n 's/^\([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\)-.*$/\1/p')"
  if [ -n "$date" ] && [[ "$date" < "$format_start" ]]; then
    return 1
  fi
  return 0
}

format_start=""
if [ -f docs/PLANS.md ]; then
  format_start="$(sed -n 's/^新しい書式の適用開始: \([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\)$/\1/p' docs/PLANS.md | head -n 1)"
fi

# 8. 計画の必須の節。見出しの一覧は docs/PLANS.md の「## 必須の節」から読み取る（一覧を 2 か所に持たないため）
if [ -f docs/PLANS.md ]; then
  plan_headings="$(required_headings_of docs/PLANS.md)"
  if [ -z "$plan_headings" ]; then
    fail "docs/PLANS.md の「## 必須の節」から、計画の必須の見出しを読み取れません" \
      '「## 必須の節」の節に、「1. `## 目的`: 説明」の形で、見出しを 1 行ずつ書く'
  else
    for plan in docs/exec-plans/active/*.md docs/exec-plans/completed/*.md; do
      [ -e "$plan" ] || [ -L "$plan" ] || continue
      # 受け入れ確認の記録は計画ではない（検査 9 で調べる）
      case "$plan" in *.acceptance.md) continue ;; esac
      if [ -L "$plan" ] || [ ! -f "$plan" ]; then
        fail "計画 $plan を検査できません（シンボリックリンクか、通常のファイルではありません）" \
          "$plan を、実体のファイルとして置く"
        continue
      fi
      if grep -q "$(printf '\r')" "$plan"; then
        fail "計画 $plan に CR（\\r）が含まれています" "改行を LF にしてください（CR があると見出しの行が一致しないため）"
        continue
      fi
      while IFS= read -r heading; do
        [ -z "$heading" ] && continue
        fail "計画 $plan に、必須の節の見出し「$heading」の行がありません" \
          "$plan に「$heading」の行を足す（前後に文字を足さない）。書くことがまだ無い節も、見出しは置く（docs/PLANS.md の「必須の節」）"
      done <<EOF
$(missing_headings_in "$plan" "$plan_headings")
EOF
    done
  fi
fi

# 9. 受け入れ確認の記録（書式の正本は docs/PLANS.md の「検証の節の書式」と「受け入れ確認の記録」）

# 新しい書式の計画の検証の節を調べる。出力は 1 行ずつ、次のどれかの形:
#   ERR<TAB><問題の説明>   書式の崩れ（下の各項目）
#   ID<TAB><識別子>        検証の節の基準の識別子のすべて（確かめ方を問わない。検査 10 が使う）
#   ACC<TAB><識別子>       確かめ方が受け入れ確認の基準（検査 9 が使う）
# 確かめること: 閉じていないコードブロックが無い／「### <識別子> <題>」の識別子が重複しない／各見出しの下に
# 「- 確かめ方: <値>」の行がちょうど 1 つあり、値が「自動テスト」「受け入れ確認」「人が確認」のどれか／どの見出しの下にも
# 無い確かめ方の行が無い／「確かめ方」の語に「:」か「：」が続くのに、正しい形（行の頭が「- 確かめ方: 」）でない行が無い／
# 基準の見出しが 1 つ以上ある／受け入れ確認を含む表の行と、「確かめ方」と「受け入れ確認」を両方含むのに正しい形でない行が無い。
check_plan_verification() {
  awk '
    function end_heading() {
      if (id != "") {
        if (count == 0) print "ERR\t基準 " id " に「- 確かめ方: <値>」の行がありません"
        else if (count > 1) print "ERR\t基準 " id " に「- 確かめ方: <値>」の行が " count " 行あります（1 行にする）"
      }
      id = ""; count = 0
    }
    /^```/ { inside = !inside; next }
    inside { next }
    /^## / { if (insec) end_heading(); insec = ($0 == "## 検証（完了の条件）"); if (insec) sawsec = 1; next }
    !insec { next }
    /^###([[:space:]].*)?$/ {
      end_heading()
      nheadings++
      id = $2
      if (id == "") { print "ERR\t識別子の無い基準の見出しがあります: " $0; next }
      if (id in seen) print "ERR\t基準の識別子 " id " が重複しています"
      else print "ID\t" id
      seen[id] = 1
      next
    }
    /^- 確かめ方: / {
      v = substr($0, length("- 確かめ方: ") + 1); sub(/[[:space:]]+$/, "", v)
      if (id == "") { print "ERR\tどの「### <識別子>」の見出しの下にも無い確かめ方の行があります: " $0; next }
      count++
      if (v != "自動テスト" && v != "受け入れ確認" && v != "人が確認") {
        print "ERR\t基準 " id " の確かめ方「" v "」は、「自動テスト」「受け入れ確認」「人が確認」のどれでもありません"
      } else if (v == "受け入れ確認") {
        print "ACC\t" id
      }
      next
    }
    /確かめ方[[:space:]]*(:|：)/ { print "ERR\t形の崩れた確かめ方の行があります（「- 確かめ方: <値>」の形にする）: " $0; next }
    # 正しい形でない書き方の受け入れ確認の基準（表の行、コロンの無い確かめ方の行）。地の文と、ほかの項目の行
    # （「- 期待する結果: ...」など）で受け入れ確認に触れるだけの行は対象にしない。
    /^[[:space:]]*\|/ && index($0, "受け入れ確認") > 0 {
      print "ERR\t表の行に受け入れ確認があります（基準ごとの見出しと「- 確かめ方: 受け入れ確認」の行で書く）: " $0; next
    }
    index($0, "確かめ方") > 0 && index($0, "受け入れ確認") > 0 {
      print "ERR\t形の崩れた確かめ方の行があります（「- 確かめ方: <値>」の形にする）: " $0; next
    }
    END {
      if (insec) end_heading()
      if (sawsec && nheadings == 0) print "ERR\t基準の見出し（### <識別子> <題>）が 1 つもありません"
      if (inside) print "ERR\t閉じていないコードブロック（``` の行の数が奇数）があります"
    }
  ' "$1"
}

# 記録の書式を調べ、問題を 1 行ずつ出す。確かめること: 閉じていないコードブロックが無い／「## 」の見出しは
# 「## 実行 <番号>」だけで、番号が 1 から欠けずに 1 ずつ増える／実行が 1 つ以上ある／各実行に必須の行
# （RECORD_REQUIRED_FIELDS）がちょうど 1 行ずつあり、「確かめた対象」以外は値がある／「全体」の値が合格・不合格・未確認の
# どれか／各実行に「- 基準 <識別子>: <結果>」の行が 1 つ以上あり、各行の下に「  - 証拠: <値>」の行がある。
RECORD_REQUIRED_FIELDS="日時 確かめた者 元のコミット 分岐元 確かめた対象 基準外の所見 未確認の範囲 全体"
check_record_format() {
  awk -v fields="$RECORD_REQUIRED_FIELDS" '
    BEGIN { nreq = split(fields, req, " ") }
    function end_criterion() {
      if (pending != "") print "実行 " runno " の基準 " pending " の下に「  - 証拠: <値>」の行がありません"
      pending = ""
    }
    function end_run(   i) {
      if (!inrun) return
      end_criterion()
      for (i = 1; i <= nreq; i++) {
        if (cnt[req[i]] == 0) print "実行 " runno " に「- " req[i] ":」の行がありません"
        else if (cnt[req[i]] > 1) print "実行 " runno " に「- " req[i] ":」の行が " cnt[req[i]] " 行あります（1 行にする）"
      }
      if (ncrit == 0) print "実行 " runno " に「- 基準 <識別子>: <結果>」の行がありません"
      split("", cnt); ncrit = 0; inrun = 0
    }
    /^```/ { inside = !inside; next }
    inside { next }
    /^## / {
      end_run()
      if ($0 ~ /^## 実行 [0-9]+$/) {
        runs++
        runno = substr($0, length("## 実行 ") + 1) + 0
        if (runno != runs) print runs " 番目の実行の番号が " runno " です（番号は 1 から欠けずに 1 ずつ増やす）"
        inrun = 1
      } else {
        print "「## 実行 <番号>」でない見出しがあります: " $0
      }
      next
    }
    !inrun { next }
    /^- / {
      end_criterion()
      if ($0 ~ /^- 基準 [^ :]+: /) {
        v = substr($0, length("- 基準 ") + 1); pending = substr(v, 1, index(v, ": ") - 1); ncrit++
        next
      }
      for (i = 1; i <= nreq; i++) {
        p = "- " req[i] ":"
        if (substr($0, 1, length(p)) != p) continue
        cnt[req[i]]++
        rest = substr($0, length(p) + 1); sub(/[[:space:]]+$/, "", rest)
        if (req[i] != "確かめた対象" && rest !~ /^ ./) print "実行 " runno " の「- " req[i] ":」に値がありません"
        if (req[i] == "全体" && rest != " 合格" && rest != " 不合格" && rest != " 未確認") {
          print "実行 " runno " の全体の値「" substr(rest, 2) "」は、合格・不合格・未確認のどれでもありません"
        }
        break
      }
      next
    }
    /^[[:space:]]+- 証拠: [^[:space:]]/ { pending = ""; next }
    END {
      end_run()
      if (inside) print "閉じていないコードブロック（``` の行の数が奇数）があります"
      if (runs == 0) print "実行の節（## 実行 <番号>）がありません"
    }
  ' "$1"
}

# 記録から、基準ごとに、判定に数える実行（確かめた者: app-evaluator）のうち最も後の実行の結果を「識別子<TAB>結果」で出す
latest_results_of() {
  outside_code_blocks "$1" | awk '
    function flush(   k) {
      if (who == "app-evaluator") for (k in cur) latest[k] = cur[k]
      split("", cur)
    }
    /^## / { flush(); inrun = ($0 ~ /^## 実行 /); who = ""; next }
    !inrun { next }
    /^- 確かめた者:/ {
      v = $0; sub(/^- 確かめた者:[[:space:]]*/, "", v); sub(/[[:space:]]+$/, "", v); who = v; next
    }
    /^- 基準 / {
      v = $0; sub(/^- 基準 /, "", v)
      p = index(v, ": "); if (p == 0) next
      k = substr(v, 1, p - 1); r = substr(v, p + 2); sub(/[[:space:]]+$/, "", r)
      cur[k] = r; next
    }
    END { flush(); for (k in latest) print k "\t" latest[k] }
  '
}

if [ -f docs/PLANS.md ]; then
  if [ -z "$format_start" ]; then
    fail "docs/PLANS.md に「新しい書式の適用開始: YYYY-MM-DD」の行がありません" \
      "docs/PLANS.md の「検証の節の書式」に、新しい書式を適用し始めた日付をその形の 1 行で戻す（受け入れ確認の記録を検査する計画を決めるため）"
  fi
fi

# 9a. すべての記録: 置き場と、書いてはならないもの
for rec in docs/exec-plans/active/*.acceptance.md docs/exec-plans/completed/*.acceptance.md; do
  [ -e "$rec" ] || [ -L "$rec" ] || continue
  if [ -L "$rec" ] || [ ! -f "$rec" ]; then
    fail "受け入れ確認の記録 $rec を検査できません（シンボリックリンクか、通常のファイルではありません）" \
      "$rec を、実体のファイルとして置く"
    continue
  fi
  if grep -q "$(printf '\r')" "$rec"; then
    fail "受け入れ確認の記録 $rec に CR（\\r）が含まれています" "改行を LF にしてください（CR があると行を読み取れないため）"
    continue
  fi
  if grep -qE '(^|[^A-Za-z0-9._~-])/(Users|home|private|tmp|var/folders)/' "$rec"; then
    fail "受け入れ確認の記録 $rec に絶対パスの形があります" \
      "パスをリポジトリの根からの相対で書き直す。スクリーンショットはファイル名だけを書く（絶対パスにはアカウント名が入るため。docs/PLANS.md の「書いてはならないもの」）"
  fi
  rec_dir="$(dirname "$rec")"
  rec_name="$(basename "$rec" .acceptance.md)"
  if [ ! -f "$rec_dir/$rec_name.md" ]; then
    case "$rec_dir" in
      */active) other_dir="docs/exec-plans/completed" ;;
      *) other_dir="docs/exec-plans/active" ;;
    esac
    if [ -f "$other_dir/$rec_name.md" ]; then
      fail "受け入れ確認の記録 $rec が、計画 $other_dir/$rec_name.md と別のディレクトリにあります" \
        "記録を計画と同じディレクトリへ移す（計画を completed/ へ移すときは、記録も同じ変更で移す）"
    else
      fail "受け入れ確認の記録 $rec に対応する計画 $rec_dir/$rec_name.md がありません" \
        "記録の名前を計画の名前（.md を除いたもの）に .acceptance.md を付けた形に直すか、不要な記録を消す"
    fi
  fi
done

# 9b. 新しい書式の完了した計画: 受け入れ確認の基準ごとの最新の結果
if [ -n "$format_start" ]; then
  for plan in docs/exec-plans/completed/*.md; do
    case "$plan" in *.acceptance.md) continue ;; esac
    # 読めない計画と CR を含む計画は、検査 8 が失敗にしている
    { [ -f "$plan" ] && [ ! -L "$plan" ]; } || continue
    grep -q "$(printf '\r')" "$plan" && continue
    plan_name="$(basename "$plan" .md)"
    is_new_format_plan "$plan" || continue
    verification="$(check_plan_verification "$plan")"
    while IFS= read -r problem; do
      [ -z "$problem" ] && continue
      fail "計画 $plan の検証の節: $problem" \
        "docs/PLANS.md の「検証の節の書式」に合わせて直す（基準ごとに「### <識別子> <題>」の見出しと、その下に「- 確かめ方: <値>」の行を 1 つ）"
    done <<EOF
$(printf '%s\n' "$verification" | sed -n 's/^ERR	//p')
EOF
    criteria="$(printf '%s\n' "$verification" | sed -n 's/^ACC	//p' | sort -u)"
    rec="docs/exec-plans/completed/$plan_name.acceptance.md"
    # 記録があれば、受け入れ確認の基準の有無によらず書式を調べる
    if [ -f "$rec" ] && [ ! -L "$rec" ] && ! grep -q "$(printf '\r')" "$rec"; then
      while IFS= read -r problem; do
        [ -z "$problem" ] && continue
        fail "受け入れ確認の記録 $rec: $problem" \
          "docs/PLANS.md の「受け入れ確認の記録」の書式に合わせて直す。前の実行の記述は書き換えず、足りない行は新しい実行の節で確かめ直して書く"
      done <<EOF
$(check_record_format "$rec")
EOF
    fi
    [ -z "$criteria" ] && continue
    if [ ! -f "$rec" ]; then
      fail "計画 $plan に確かめ方が受け入れ確認の基準があるのに、受け入れ確認の記録 $rec がありません" \
        "受け入れ確認の担当（app-evaluator）に確かめてもらい、記録を計画と同じディレクトリに置く"
      continue
    fi
    latest="$(latest_results_of "$rec")"
    while IFS= read -r id; do
      [ -z "$id" ] && continue
      [ "$id" = "-" ] && continue
      result="$(awk -F '\t' -v k="$id" '$1 == k { print $2 }' <<<"$latest")"
      if [ -z "$result" ]; then
        fail "計画 $plan の基準 $id に、判定に数える受け入れ確認の実行がありません（記録 $rec）" \
          "受け入れ確認の担当（app-evaluator）に基準 $id を確かめてもらう。ほかの名前の実行は判定に数えない"
      elif [ "$result" != "合格" ]; then
        fail "計画 $plan の基準 $id の、最新の受け入れ確認の結果が「$result」です（記録 $rec）" \
          "不具合を直すか確かめられなかった理由を解いてから、受け入れ確認の担当に基準 $id を確かめ直してもらう"
      fi
    done <<EOF
$criteria
EOF
  done
fi

# 10. 製品の仕様（書式と目録の正本は docs/product-specs/README.md）
SPEC_DIR="docs/product-specs"
SPEC_INDEX="$SPEC_DIR/README.md"
SPEC_FIX="docs/product-specs/README.md の書式に合わせて直す"
ABBR_RE='^[A-Z]{2,6}$'
SPEC_NAME_RE='^[a-z0-9][a-z0-9-]*\.md$'
PLAN_ID_RE='^V[0-9]+$'
catalog="$work_dir/spec-catalog.tsv"   # 略号<TAB>仕様のパス（読めなければ -）<TAB>状態
spec_ids="$work_dir/spec-ids.tsv"      # 識別子<TAB>仕様のパス
: > "$catalog"
: > "$spec_ids"
spec_dir_present=0

# 目録の表の見出しの行（列の名前と順序）。docs/product-specs/README.md の「check-docs.sh が直接読む書式」と組
CATALOG_HEADER="略号,仕様,題,状態"

# 目録（「## 目録」の節の表）を読み、1 行ずつ次の形で出す（値が空の欄は「-」にする。read で空の欄が詰まらないように）:
#   HEAD<TAB><列の名前をカンマでつないだもの>         表の 1 行目（見出しの行）
#   ROW<TAB><略号><TAB><リンク先><TAB><状態><TAB><列の数>  3 行目以降（2 行目の区切りの行は読まない）
read_spec_catalog() {
  outside_code_blocks "$1" | awk '
    function v(s) { return (s == "") ? "-" : s }
    /^## / { on = ($0 == "## 目録"); next }
    !on { next }
    /^[[:space:]]*\|/ {
      line = $0
      sub(/^[[:space:]]*\|/, "", line); sub(/\|[[:space:]]*$/, "", line)
      n = split(line, col, "|")
      for (i = 1; i <= n; i++) { gsub(/^[[:space:]]+/, "", col[i]); gsub(/[[:space:]]+$/, "", col[i]) }
      rows++
      if (rows == 1) {
        h = col[1]; for (i = 2; i <= n; i++) h = h "," col[i]
        print "HEAD\t" v(h); next
      }
      if (rows == 2 && col[1] ~ /^:?-+:?$/) next
      target = ""
      if (match(col[2], /\]\([^)]*\)/)) target = substr(col[2], RSTART + 2, RLENGTH - 3)
      print "ROW\t" v(col[1]) "\t" v(target) "\t" v(col[4]) "\t" n
    }
  '
}

# 仕様 $1 の「## 受け入れ基準」の節を調べる。$2 は目録の略号（分からなければ空）。出力は 1 行ずつ:
#   ERR<TAB><問題の説明>
#   ID<TAB><識別子>
check_spec_criteria() {
  awk -v abbr="$2" '
    BEGIN { item[1] = "- 前提:"; item[2] = "- 操作:"; item[3] = "- 期待する結果:" }
    function end_heading(   k) {
      if (id != "") {
        for (k = 1; k <= 3; k++) {
          if (cnt[k] == 0) print "ERR\t基準 " id " に「" item[k] "」の行がありません"
          else if (cnt[k] > 1) print "ERR\t基準 " id " に「" item[k] "」の行が " cnt[k] " 行あります（1 行にする）"
        }
      }
      id = ""; split("", cnt)
    }
    /^```/ { inside = !inside; next }
    inside { next }
    /^## / { if (insec) end_heading(); insec = ($0 == "## 受け入れ基準"); next }
    !insec { next }
    /^###([[:space:]].*)?$/ {
      end_heading()
      nheadings++
      id = $2
      if (id == "") { print "ERR\t識別子の無い基準の見出しがあります: " $0; id = "（識別子の無い見出し）"; next }
      if ($0 !~ /^###[[:space:]]+[^[:space:]]+[[:space:]]+[^[:space:]]/) {
        print "ERR\t基準 " id " の見出しに題がありません（「### <識別子> <題>」の形にする）"
      }
      if (abbr != "") {
        if (id !~ ("^" abbr "-[0-9]+$")) print "ERR\t基準の識別子 " id " が、この仕様の略号の形（" abbr "-<数字>）ではありません"
      } else if (id !~ /^[A-Z]+-[0-9]+$/) {
        print "ERR\t基準の識別子 " id " が「<略号>-<数字>」の形ではありません"
      }
      print "ID\t" id
      next
    }
    {
      for (k = 1; k <= 3; k++) if (index($0, item[k]) == 1) { if (id != "") cnt[k]++; break }
    }
    END {
      if (insec) end_heading()
      if (nheadings == 0) print "ERR\t受け入れ基準の見出し（「## 受け入れ基準」の下の ### <識別子> <題>）が 1 つもありません"
    }
  ' "$1"
}

if [ -e "$SPEC_DIR" ] || [ -L "$SPEC_DIR" ]; then
  spec_dir_present=1
  if [ -L "$SPEC_DIR" ] || [ ! -d "$SPEC_DIR" ]; then
    fail "$SPEC_DIR がディレクトリではありません" "$SPEC_DIR を、実体のディレクトリとして置く"
  elif [ -L "$SPEC_INDEX" ] || [ ! -f "$SPEC_INDEX" ]; then
    fail "$SPEC_DIR があるのに、書式と目録の文書 $SPEC_INDEX がありません" \
      "$SPEC_INDEX を実体のファイルとして置く（仕様の書式と目録の正本。仕様を置かないなら $SPEC_DIR ごと消す）"
  else
    spec_headings="$(required_headings_of "$SPEC_INDEX")"
    if [ -z "$spec_headings" ]; then
      fail "$SPEC_INDEX の「## 必須の節」から、仕様の必須の見出しを読み取れません" \
        '「## 必須の節」の節に、「1. `## 目的`: 説明」の形で、見出しを 1 行ずつ書く'
    fi

    # (1)(2)(3) 目録の行
    catalog_header=""
    while IFS="$(printf '\t')" read -r kind abbr target status ncol; do
      [ -z "$kind" ] && continue
      if [ "$kind" = HEAD ]; then
        catalog_header="$abbr"
        continue
      fi
      if [ "$ncol" != 4 ]; then
        fail "$SPEC_INDEX の目録の行（略号 $abbr）の列の数が $ncol です" \
          "目録の行を「| 略号 | [名前.md](名前.md) | 題 | 状態 |」の 4 列にする（題に「|」を使わない）"
      fi
      [[ "$abbr" =~ $ABBR_RE ]] || fail "$SPEC_INDEX の目録の略号 $abbr が、英大文字 2〜6 字ではありません" \
        "略号を英大文字 2〜6 字にする（受け入れ基準の識別子 <略号>-<数字> と計画の V<数字> を区別するため）"
      path="-"
      if [ "$target" = "-" ]; then
        fail "$SPEC_INDEX の目録の略号 $abbr の行に、仕様へのリンクがありません" \
          "仕様の欄を [名前.md](名前.md) のインラインのリンクにする"
      elif [[ "$target" == */* ]] || [[ "$target" != *.md ]] || [ "$target" = "README.md" ]; then
        fail "$SPEC_INDEX の目録の略号 $abbr のリンク先 $target が、$SPEC_DIR の直下の仕様のファイルではありません" \
          "仕様は $SPEC_DIR の直下に <名前>.md で置き、リンク先はファイル名だけにする"
      else
        path="$SPEC_DIR/$target"
        [[ "$target" =~ $SPEC_NAME_RE ]] || fail "$SPEC_INDEX の目録の略号 $abbr のリンク先 $target: 仕様のファイル名が英小文字・数字・ハイフンではありません" \
          "仕様のファイル名を英小文字・数字・ハイフンだけにし（英小文字か数字で始める）、目録のリンク先も合わせる"
        if [ ! -f "$path" ]; then
          fail "$SPEC_INDEX の目録の略号 $abbr のリンク先 $path がありません" \
            "目録の行を実在する仕様に直すか、仕様のファイルを置く"
          path="-"
        fi
      fi
      case "$status" in
        draft|approved|archived) ;;
        *) fail "$SPEC_INDEX の目録の略号 $abbr の状態「$status」は、draft・approved・archived のどれでもありません" \
             "状態の欄を draft・approved・archived のどれか 1 語にする" ;;
      esac
      printf '%s\t%s\t%s\n' "$abbr" "$path" "$status" >> "$catalog"
    done <<EOF
$(read_spec_catalog "$SPEC_INDEX")
EOF
    if [ -z "$catalog_header" ]; then
      fail "$SPEC_INDEX の「## 目録」の節に、目録の表がありません" \
        "「## 目録」の節に、見出しの行が「| 略号 | 仕様 | 題 | 状態 |」の表を置く（行が 0 行でもよい）"
    elif [ "$catalog_header" != "$CATALOG_HEADER" ]; then
      fail "$SPEC_INDEX の目録の表の見出しの行が「$catalog_header」です（期待: $CATALOG_HEADER）" \
        "目録の表の見出しの行を「| 略号 | 仕様 | 題 | 状態 |」に戻す。列を変えるときは scripts/harness/check-docs.sh も直す"
    fi
    while IFS= read -r dup; do
      [ -z "$dup" ] && continue
      fail "$SPEC_INDEX の目録の略号 $dup が重複しています" "略号を仕様ごとに別のものにする"
    done <<EOF
$(cut -f1 "$catalog" | sort | uniq -d)
EOF
    while IFS= read -r dup; do
      [ -z "$dup" ] && continue
      fail "$SPEC_INDEX の目録に、仕様 $dup の行が 2 行以上あります" "仕様 1 つにつき目録の行を 1 行にする"
    done <<EOF
$(cut -f2 "$catalog" | grep -vxF -- '-' | sort | uniq -d || true)
EOF

    # (2)〜(5) 仕様のファイルごと
    for spec in "$SPEC_DIR"/*.md; do
      [ -e "$spec" ] || [ -L "$spec" ] || continue
      [ "$spec" = "$SPEC_INDEX" ] && continue
      if [ -L "$spec" ] || [ ! -f "$spec" ]; then
        fail "仕様 $spec を検査できません（シンボリックリンクか、通常のファイルではありません）" "$spec を、実体のファイルとして置く"
        continue
      fi
      if grep -q "$(printf '\r')" "$spec"; then
        fail "仕様 $spec に CR（\\r）が含まれています" "改行を LF にしてください（CR があると見出しの行が一致しないため）"
        continue
      fi
      [[ "$(basename "$spec")" =~ $SPEC_NAME_RE ]] || fail "仕様 $spec: 仕様のファイル名が英小文字・数字・ハイフンではありません" \
        "仕様のファイル名を英小文字・数字・ハイフンだけにし（英小文字か数字で始める）、目録のリンク先も合わせる（計画の目的の節のパスを拾う形と合わせるため）"
      abbr=""
      status=""
      row="$(awk -F '\t' -v p="$spec" '$2 == p { print; exit }' "$catalog")"
      if [ -z "$row" ]; then
        fail "仕様 $spec が目録 $SPEC_INDEX にありません" \
          "$SPEC_INDEX の「## 目録」の表に、略号・[名前.md](名前.md)・題・状態（新しい仕様は draft）の行を足す"
      else
        abbr="$(printf '%s\n' "$row" | cut -f1)"
        status="$(printf '%s\n' "$row" | cut -f3)"
        [[ "$abbr" =~ $ABBR_RE ]] || abbr=""
      fi
      spec_body="$(outside_code_blocks "$spec")"
      if grep -qE '^(- )?状態[:：]' <<<"$spec_body"; then
        fail "仕様 $spec に状態の行があります" \
          "状態の行を消す。状態は $SPEC_INDEX の目録の「状態」の列だけに持つ（2 か所に持つと食い違うため）"
      fi
      case "$status" in
        approved|archived)
          if grep -qF '[NEEDS CLARIFICATION:' <<<"$spec_body"; then
            fail "仕様 $spec は $status なのに、未決の点（[NEEDS CLARIFICATION:）が残っています" \
              "未決の点を利用者に尋ねて仕様に反映し、承認をやり直すまで目録の状態を draft に戻す"
          fi
          ;;
      esac
      criteria="$(check_spec_criteria "$spec" "$abbr")"
      # archived の仕様は、必須の節と基準の項目の書式を調べない（書式を後から変えても、過去の仕様を失敗にしないため）。
      # 識別子は集める（完了した計画が引く識別子の実在と、識別子の使い回しを確かめるため）
      if [ "$status" != archived ]; then
        if [ -n "${spec_headings:-}" ]; then
          while IFS= read -r heading; do
            [ -z "$heading" ] && continue
            fail "仕様 $spec に、必須の節の見出し「$heading」の行がありません" \
              "$spec に「$heading」の行を足す（前後に文字を足さない）。書くことがまだ無い節も、見出しは置く（$SPEC_INDEX の「必須の節」）"
          done <<EOF
$(missing_headings_in "$spec" "$spec_headings")
EOF
        fi
        while IFS= read -r problem; do
          [ -z "$problem" ] && continue
          fail "仕様 $spec の受け入れ基準: $problem" "$SPEC_FIX（基準ごとに「### <略号>-<数字> <題>」と、前提・操作・期待する結果の行を 1 行ずつ）"
        done <<EOF
$(printf '%s\n' "$criteria" | sed -n 's/^ERR	//p')
EOF
      fi
      printf '%s\n' "$criteria" | sed -n 's/^ID	//p' | awk -v p="$spec" '{ print $0 "\t" p }' >> "$spec_ids"
    done
    while IFS= read -r dup; do
      [ -z "$dup" ] && continue
      fail "受け入れ基準の識別子 $dup が重複しています（重複のある仕様: $(awk -F '\t' -v k="$dup" '$1 == k { print $2 }' "$spec_ids" | sort -u | tr '\n' ' ' | sed 's/ $//')）" \
        "識別子は、仕様の略号で始め、同じ仕様の中でも仕様をまたいでも重ねない。いちど振った識別子は使い回さない"
    done <<EOF
$(cut -f1 "$spec_ids" | sort | uniq -d)
EOF
  fi
fi

# 計画 $1 が引く仕様 $2 の状態を目録で調べる。進行中の計画は approved だけ、完了した計画は approved か archived を引ける
check_plan_spec_status() {
  local plan="$1" spec="$2" status
  status="$(awk -F '\t' -v p="$spec" '$2 == p { print $3; exit }' "$catalog")"
  case "$plan" in
    docs/exec-plans/active/*)
      [ "$status" = approved ] || fail "進行中の計画 $plan が引く仕様 $spec の状態が「${status:-目録に無い}」です" \
        "進行中の計画は approved の仕様だけを引ける。利用者の承認を得て仕様を approved にしてから計画を書く（承認の前に計画を書かない）"
      ;;
    *)
      case "$status" in
        approved|archived) ;;
        *) fail "完了した計画 $plan が引く仕様 $spec の状態が「${status:-目録に無い}」です" \
             "完了した計画は approved か archived の仕様だけを引ける。仕様の状態を目録で確かめ、承認の経緯を確かめる" ;;
      esac
      ;;
  esac
}

# (6)(7) 新しい書式の計画が引く仕様（目的の節に書いた仕様と、検証の節の識別子の所属先）
for plan in docs/exec-plans/active/*.md docs/exec-plans/completed/*.md; do
  case "$plan" in *.acceptance.md) continue ;; esac
  # 読めない計画と CR を含む計画は、検査 8 が失敗にしている
  { [ -f "$plan" ] && [ ! -L "$plan" ]; } || continue
  grep -q "$(printf '\r')" "$plan" && continue
  is_new_format_plan "$plan" || continue
  # 仕様の名前は英小文字・数字・ハイフン（docs/product-specs/README.md の「置き場と名前」）なので、その文字だけを拾う。
  # 読点などでつないだ 2 つのパスが 1 つにつながらないようにするため
  purpose_specs="$(outside_code_blocks "$plan" | awk '/^## /{ on = ($0 == "## 目的"); next } on' \
    | { grep -oE 'docs/product-specs/[a-z0-9][a-z0-9-]*\.md' || true; } | sort -u)"
  status_checked=""
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    if awk -F '\t' -v p="$p" '$2 == p { found = 1 } END { exit !found }' "$catalog"; then
      check_plan_spec_status "$plan" "$p"
      status_checked="$status_checked
$p"
    else
      fail "計画 $plan の目的の節の仕様 $p が、目録 $SPEC_INDEX にありません" \
        "目的の節の仕様のパスを、目録の行のリンク先の仕様（docs/product-specs/<名前>.md の形）に直す"
    fi
  done <<EOF
$purpose_specs
EOF
  no_purpose_reported=0
  while IFS= read -r id; do
    [ -z "$id" ] && continue
    [[ "$id" =~ $PLAN_ID_RE ]] && continue
    if [ "$spec_dir_present" -eq 0 ]; then
      fail "計画 $plan の基準 $id は V<数字> ではありませんが、製品の仕様の置き場 $SPEC_DIR がありません" \
        "計画の中で振る基準は V<数字> にする。製品の仕様の基準を引くなら、先に仕様を書いて承認を得る（docs/PLANS.md の「検証の節の書式」）"
      continue
    fi
    owner="$(awk -F '\t' -v k="$id" '$1 == k { print $2; exit }' "$spec_ids")"
    if [ -z "$owner" ]; then
      fail "計画 $plan の基準 $id が、どの製品の仕様の受け入れ基準にもありません" \
        "識別子を仕様の受け入れ基準の識別子に合わせるか、計画の中で振る基準なら V<数字> にする"
      continue
    fi
    if ! grep -qxF -- "$owner" <<<"$status_checked"; then
      check_plan_spec_status "$plan" "$owner"
      status_checked="$status_checked
$owner"
    fi
    if [ -z "$purpose_specs" ]; then
      if [ "$no_purpose_reported" -eq 0 ]; then
        fail "計画 $plan は製品の仕様の基準（$id など）を引くのに、目的の節に仕様のパスがありません" \
          "目的の節に、引く仕様のパスを docs/product-specs/<名前>.md の形で書く"
        no_purpose_reported=1
      fi
    elif ! grep -qxF -- "$owner" <<<"$purpose_specs"; then
      fail "計画 $plan の基準 $id は仕様 $owner の基準ですが、目的の節に書いた仕様にありません" \
        "目的の節に $owner を書くか、検証の節の識別子を目的の節に書いた仕様の基準に直す"
    fi
  done <<EOF
$(check_plan_verification "$plan" | sed -n 's/^ID	//p')
EOF
done

# 11. 古い計画（決まりの正本は docs/PLANS.md の「置き場所と名前」）
DATE_SHAPE_RE='^[0-9]{4}-[0-9]{2}-[0-9]{2}$'

# 日付（YYYY-MM-DD）を扱う awk の関数。date コマンドの日付の計算は macOS と Linux で書き方が違うので、awk で計算する。
# どの awk でも同じ結果になるように、substr、int、四則と剰余だけで書く。
#   valid_date(s): 暦にある日付なら 1（月ごとの日数と、うるう年の 2 月を確かめる）
#   day_number(s): 通しの日数
DATE_AWK='
  function leap_year(y) { return (y % 4 == 0 && y % 100 != 0) || y % 400 == 0 }
  function valid_date(s,   y, m, d, last) {
    y = substr(s, 1, 4) + 0; m = substr(s, 6, 2) + 0; d = substr(s, 9, 2) + 0
    if (m < 1 || m > 12 || d < 1) return 0
    last = 31
    if (m == 4 || m == 6 || m == 9 || m == 11) last = 30
    if (m == 2) { if (leap_year(y)) last = 29; else last = 28 }
    return d <= last
  }
  function day_number(s,   y, m, d) {
    y = substr(s, 1, 4) + 0; m = substr(s, 6, 2) + 0; d = substr(s, 9, 2) + 0
    if (m <= 2) { y = y - 1; m = m + 12 }
    return 365 * y + int(y / 4) - int(y / 100) + int(y / 400) + int((153 * (m - 3) + 2) / 5) + d
  }
'

# $1 が、YYYY-MM-DD の形で、暦にある日付か
is_real_date() {
  [[ "$1" =~ $DATE_SHAPE_RE ]] || return 1
  awk -v s="$1" "$DATE_AWK"'BEGIN { exit !valid_date(s) }'
}

# 標準入力の各行から、YYYY-MM-DD の形の並びを 1 行に 1 つずつ出す。前か後ろに数字が続く並び（12026-10-07、
# 2026-10-071 など）は、日付でない数字の一部なので出さない
dates_in_lines() {
  awk '{
    line = $0
    while (match(line, /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/)) {
      before = ""
      if (RSTART > 1) before = substr(line, RSTART - 1, 1)
      after = substr(line, RSTART + 10, 1)
      if (before !~ /[0-9]/ && after !~ /[0-9]/) print substr(line, RSTART, 10)
      line = substr(line, RSTART + 1)
    }
  }'
}

# 計画 $1 の、最も新しい日付を出す（無ければ何も出さない）。$2 = 基準の日。見るのは、ファイル名の先頭の日付と、
# 「## 進捗」の節の中の YYYY-MM-DD の形の日付。コードブロックの中の行、暦に無い日付、基準の日の 1 日後より後の日付は
# 数えない
latest_plan_date() {
  {
    basename "$1" .md | sed -n 's/^\([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\)-.*$/\1/p'
    outside_code_blocks "$1" | awk '/^## /{ on = ($0 == "## 進捗"); next } on' | dates_in_lines
  } | awk -v base="$2" "$DATE_AWK"'BEGIN { limit = day_number(base) + 1 } valid_date($0) && day_number($0) <= limit { print }' \
    | sort | tail -n 1
}

# 日付 $1 から日付 $2 までの日数を出す（どちらも YYYY-MM-DD。$2 が後なら正の数）
days_between() {
  awk -v a="$1" -v b="$2" "$DATE_AWK"'BEGIN { print day_number(b) - day_number(a) }'
}

base_day="${HARNESS_TODAY:-$(date '+%Y-%m-%d')}"
if ! is_real_date "$base_day"; then
  fail "環境変数 HARNESS_TODAY の値「$base_day」が、YYYY-MM-DD の形の、暦にある日付ではありません" \
    "HARNESS_TODAY を YYYY-MM-DD の形の、暦にある日付にするか、外す（外すと、実行した日を基準の日にする）"
else
  for plan in docs/exec-plans/active/*.md; do
    case "$plan" in *.acceptance.md) continue ;; esac
    # 読めない計画と CR を含む計画は、検査 8 が失敗にしている
    { [ -f "$plan" ] && [ ! -L "$plan" ]; } || continue
    grep -q "$(printf '\r')" "$plan" && continue
    latest="$(latest_plan_date "$plan" "$base_day")"
    if [ -z "$latest" ]; then
      fail "進行中の計画 $plan の古さを判定できません（ファイル名の先頭にも「## 進捗」の節にも、数えられる YYYY-MM-DD の形の日付がありません。暦に無い日付と、基準の日 $base_day の 1 日後より後の日付は数えない）" \
        "$plan の「## 進捗」の節に、「- YYYY-MM-DD: 終えた手順」の形で、作業を進めた日付の行を書く（docs/PLANS.md の「必須の節」の進捗の書き方）"
      continue
    fi
    elapsed="$(days_between "$latest" "$base_day")"
    if [ "$elapsed" -ge "$STALE_PLAN_DAYS" ]; then
      fail "進行中の計画 $plan が古くなっています（最も新しい日付 $latest から $elapsed 日。基準の日は $base_day。$STALE_PLAN_DAYS 日以上、日付の更新が無い進行中の計画は失敗にする）" \
        "作業を進めたなら、$plan の「## 進捗」の節に、進めた日付（YYYY-MM-DD）の行を足す。終えたなら、「## 結果と振り返り」を書いて docs/exec-plans/completed/ へ移す。やめたなら、やめた理由を「## 結果と振り返り」に書いて docs/exec-plans/completed/ へ移す（docs/PLANS.md の「置き場所と名前」）"
    fi
  done
fi

# 12. 文書の検査の一覧（一覧の正本は CHECK_NAMES。比べる文書は冒頭の説明のとおり）
CHECK_LIST_FIX="検査を足す・外すときは、scripts/harness/check-docs.sh の冒頭の「確かめること」と CHECK_NAMES、AGENTS.md の「検査のコマンド」の表の check:docs の行、docs/QUALITY_SCORE.md の「目標」の表の「文書が実物と合っている」の測る項目の 4 か所を同じ変更で直す"

# 標準入力の行を「、」でつないで 1 行にする（paste -d は 1 バイトずつの区切りしか扱えないので awk で書く）
join_names() {
  awk 'NR > 1 { printf "、" } { printf "%s", $0 } END { if (NR > 0) printf "\n" }'
}

expected_names="$(printf '%s\n' "${CHECK_NAMES[@]}")"
expected_list="$(printf '%s\n' "$expected_names" | join_names)"

# 冒頭の「確かめること」の検査の番号（「#   1. 」「#  12. 」の形の行）が 1 から欠けずに並び、数が CHECK_NAMES と同じか
header_numbers="$(awk 'NR == 1 { next } !/^#/ { exit } /^# +[0-9]+\. / { sub(/^# +/, ""); sub(/\..*$/, ""); print }' "$SELF")"
header_count=0
header_in_order=1
while IFS= read -r n; do
  [ -z "$n" ] && continue
  header_count=$((header_count + 1))
  [ "$n" = "$header_count" ] || header_in_order=0
done <<EOF
$header_numbers
EOF
if [ "$header_in_order" -eq 0 ]; then
  fail "scripts/harness/check-docs.sh の冒頭の「確かめること」の検査の番号が、1 から欠けずに並んでいません（$(printf '%s\n' "$header_numbers" | tr '\n' ' ' | sed 's/ $//')）" \
    "冒頭の一覧の番号を 1 から 1 ずつ増やす。$CHECK_LIST_FIX"
elif [ "$header_count" -ne "${#CHECK_NAMES[@]}" ]; then
  fail "scripts/harness/check-docs.sh の冒頭の「確かめること」の検査が $header_count 件なのに、CHECK_NAMES の名前が ${#CHECK_NAMES[@]} 件です" \
    "CHECK_NAMES に、冒頭の一覧の検査ごとに短い名前を 1 つずつ、番号の順に書く。$CHECK_LIST_FIX"
fi

# $1 = 文書の場所の説明、$2 = 文書から読んだ括弧書き。CHECK_NAMES とバッククォートを除いて比べる
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
    "括弧書きを「$expected_list」にする（scripts/harness/check-docs.sh の CHECK_NAMES の名前を、同じ順に「、」でつなぐ。ファイル名にはバッククォートを付けてよい）。$CHECK_LIST_FIX"
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
    "AGENTS.md に、何を確かめるか・コマンドの表を持つ「## 検査のコマンド」の節を置く（見出しを変えると、検査 12 が check:docs の行を探せないため）。$CHECK_LIST_FIX"
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
    "docs/QUALITY_SCORE.md に、目標・測る項目・確かめ方・検査の識別子の表を持つ「## 目標」の節を置く（見出しを変えると、検査 12 が測る項目を探せないため）。$CHECK_LIST_FIX"
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

# 13. 通信の名前の一覧（読み取りの前提は冒頭の説明のとおり）
NET_FIX="通信の名前を足す・外すときは、ARCHITECTURE.md の不変条件（1 は通信のための大域の名前、2 は通信のためのモジュール）と、eslint.config.mjs の NETWORK_GLOBALS、NETWORK_MODULE_BASES（node: 付きと無しの両方に展開される）、NETWORK_MODULES の末尾の名前を、同じ変更で直す"
NET_PREMISE_FIX="書き方を元に戻す。書き方を変えるなら、scripts/harness/check-docs.sh の検査 13 の読み取りを同じ変更で直す（検査 13 は決まった書き方を前提に読むので、前提が崩れると一致を確かめられないため）"

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
  fail "eslint.config.mjs がありません（検査 13 が、通信の名前の一覧を ARCHITECTURE.md と照合できません）" \
    "eslint.config.mjs を戻す。ESLint の設定の置き場を変えたなら、scripts/harness/check-docs.sh の検査 13 の読み取りを同じ変更で直す"
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
          fail "ARCHITECTURE.md の不変条件 2 の括弧書き「$inner」に「$NET_SEP」がありません（検査 13 は、この語の前の名前を node: 付きと無しに展開し、後の名前をそのまま足して読む）" \
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

if [ "$errors" -gt 0 ]; then
  echo "check-docs: $errors 件の問題があります" >&2
  exit 1
fi
echo "check-docs: OK（ハーネスの版 ${version}）"
