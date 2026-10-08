#!/usr/bin/env bash
# 文書の検査。手元と CI で同じコマンドを使う: npm run check:docs
#
# 確かめること（ハーネスの導入の P5 までの範囲）:
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
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
md_list="$work_dir/md-list"
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

# --- 検査 8〜10 で共有する読み取り ---

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

if [ "$errors" -gt 0 ]; then
  echo "check-docs: $errors 件の問題があります" >&2
  exit 1
fi
echo "check-docs: OK（ハーネスの版 ${version}）"
