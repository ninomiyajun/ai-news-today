#!/usr/bin/env bash
# 文書の検査。手元と CI で同じコマンドを使う: npm run check:docs
#
# 確かめること（ハーネスの導入の P4 までの範囲）:
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

# 9. 受け入れ確認の記録（書式の正本は docs/PLANS.md の「検証の節の書式」と「受け入れ確認の記録」）

# ``` で始まる行ごとに、コードブロックの中と外を切り替え、外の行だけを出す
outside_code_blocks() {
  awk '/^```/{inside=!inside; next} !inside' "$1"
}

# 新しい書式の計画の検証の節を調べる。出力は 1 行ずつ、次のどちらかの形:
#   ERR<TAB><問題の説明>   書式の崩れ（下の各項目）
#   ACC<TAB><識別子>       確かめ方が受け入れ確認の基準
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

format_start=""
if [ -f docs/PLANS.md ]; then
  format_start="$(sed -n 's/^新しい書式の適用開始: \([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\)$/\1/p' docs/PLANS.md | head -n 1)"
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
    plan_date="$(printf '%s\n' "$plan_name" | sed -n 's/^\([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\)-.*$/\1/p')"
    if [ -n "$plan_date" ] && [[ "$plan_date" < "$format_start" ]]; then
      continue
    fi
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

if [ "$errors" -gt 0 ]; then
  echo "check-docs: $errors 件の問題があります" >&2
  exit 1
fi
echo "check-docs: OK（ハーネスの版 ${version}）"
