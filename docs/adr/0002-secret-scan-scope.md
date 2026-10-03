# 0002 秘匿値の検査の範囲（作業ツリーとコミットの中身）と、CI の順序

## 背景

[0001](0001-layers-and-checks.md) の秘匿値の検査には、P1 の実装のレビューで次の穴が見つかった。

- `git ls-files` の既定の出力は日本語の名前を引用符付きの形にするため、そのファイルが黙って検査から外れた。
  先頭がハイフンの名前は secretlint のオプションとして読まれた。
- secretlint は `.gitignore`、`.secretlintignore`、無効化のコメントに従い、設定ファイル（`.secretlintrc.*`）を既定で
  対象外にする。そのため、表示した件数と実際に調べた件数が食い違い、ファイルを足すだけで検査を弱められた。
- 作業ツリーだけを調べていたので、push で公開される中身（途中のコミットに入れて後で消した値、ステージした内容と
  作業ツリーの違い）を見ていなかった。
- CI は `npm ci` で依存のインストール用のスクリプトを動かしてから検査していたので、変更でスクリプトを足すと、
  検査の前に作業ツリーを書き換えられた。

## 判断

- 作業ツリーの検査（`npm run check:secrets`）は、`git -c core.quotePath=false ls-files -z` の NUL 区切りの一覧を
  使い、secretlint にはファイル名の前に `--no-glob` と `--` を渡す。`--no-gitignore` を付け、除外の設定のファイル名も
  使われない名前にする。一覧にあるのに検査できなかったファイル（作業ツリーで削除したものを除く）、シンボリック
  リンク、名前が `.secretlintignore` で始まるファイル、secretlint の無効化のコメント、中身に NUL バイトを 1 つでも
  含み、既知のバイナリの拡張子（ico、png、jpg、jpeg、gif、webp、avif、bmp、woff、woff2、ttf、otf、eot）でないファイル
  （UTF-16 で書いた文字のファイルなど。secretlint も単純な内容検査も中の文字を読めないため）は、どれも失敗にする。
  コミットの中身の検査でも同じにする。
- secretlint が既定で対象外にするファイルと、文字のファイルでないファイル（`favicon.ico` など）は、
  `scripts/harness/check-secrets.mjs` の中の単純な内容検査（代表的な鍵とトークンの接頭辞）で調べる。既知のバイナリの
  拡張子のファイルは、Latin-1 で読んだ中身に加えて、UTF-16LE と UTF-16BE で読んだ中身（偶数と奇数の両方の位置から）も
  調べる。表示する件数は、
  secretlint が実際に調べたファイル（secretlint の JSON の結果から数える）と、単純な内容検査のファイルに分けて示す。
- コミットの中身の検査（`npm run check:secrets:push`）を足した。範囲の各コミットのファイルを `git ls-tree` と
  `git cat-file --batch` で一時ディレクトリへ取り出し、同じ検査をする（secretlint は、引数の長さの上限を超えないよう
  ファイルを分けて何回か起動する）。範囲のコミットメッセージと、手元のすべての注釈付きのタグの注釈も、単純な内容検査に
  掛ける。範囲の既定は「HEAD --branches --tags --not --remotes=origin」（手元のすべてのブランチとタグから辿れて、push 先の
  リモートの追跡ブランチから辿れないコミット。初回の push ではすべて）で、push 先は `--remote <名前>` で変えられる。
  HEAD だけから辿ると、今いるブランチ以外のブランチや、HEAD から辿れないタグを push したときに検査から外れるため、
  手元のすべてのブランチとタグを起点にする。範囲のコミットが 0 件でも、タグの注釈は調べる。`git archive` は
  `.gitattributes` の `export-ignore` でファイルを省けるので使わない。AGENTS.md の「push の前」の決まりは、この検査に
  合わせた。
- CI は pull request と、すべてのブランチとタグへの push で動く。`npm ci --ignore-scripts` で依存を入れ、リポジトリ由来の
  他の段より先に、作業ツリーの検査と、変更の範囲のコミットの検査（pull request では base から試しのマージのコミット
  まで、push では前の先頭から今の先頭まで。新しいブランチやタグの最初の push ではすべてのコミット）を行う。秘匿値の
  検査は `npm run` を経由せず `node scripts/harness/check-secrets.mjs` を直接呼ぶ（変更で足した `pre` で始まる npm の
  スクリプトを、検査の前に動かさないため）。インストール用のスクリプトが要る依存が出たら、秘匿値の検査の後に `npm rebuild` の段を足す。
- アクションはコミットの SHA で固定し、Dependabot で npm の依存とアクションの更新を追う。

## 検討した代わりの案

- gitleaks（履歴の検査ができる）: 手元では単体の実行ファイルのインストールが要り、手元と CI で別の道具になる。
  コミットの検査を secretlint で書けたので採らなかった。
- 初回の push の前にコミットを 1 つにまとめる: 初回にしか効かず、2 回目以降の push の途中のコミットを守れない。
- secretlint の除外を設定で上書きする: 既定の除外（`.secretlintrc.*` など）は CLI の引数では外せないため、
  単純な内容検査で補った。

## 結果と限界

- 単純な内容検査は接頭辞の形しか見ないので、secretlint の規則より検出できる形が少ない。
- 検査の道具と設定は、作業ツリー（CI では検査する変更そのもの）から読む。変更が検査そのものを弱めた場合は防げない
  ので、次のものの変更は、人が差分を読んで確かめる。
  - `package.json` の `scripts`（手元の `npm run check:secrets` と、CI の lint などの段が使う）
  - `.github/` の下のすべて（CI の手順と Dependabot の設定）
  - `scripts/harness/` の下のすべて（検査のスクリプト）
  - `.secretlintrc.json`（secretlint の規則の設定）
  - `package-lock.json`（書き換えると、別の secretlint を入れられる。`--ignore-scripts` はこれを防がない）
  - Dependabot が secretlint とその規則（`secretlint`、`@secretlint/` で始まる依存）を入れ替える pull request
- 範囲の既定は、push 先のリモートの追跡ブランチにあるコミットを除く。手元の追跡ブランチが古いと、範囲は次のように変わる。
  - 他の人が push したコミットを `git fetch` で取り込んでいないとき: 範囲が広がる（検査が増えるだけで、見落としは無い）。
  - サーバーで消したブランチの追跡ブランチが手元に残っているとき: そのブランチにだけあるコミットが範囲から外れ、
    狭まる。そのため手順は `git fetch --prune origin` とする。
  - 別のリモート（私的なミラーなど）に push するとき: `--remote <名前>` を付けないと、origin を基準にした範囲になる。
- 単純な内容検査は、手元のすべての注釈付きのタグを調べるので、手元にだけある古いタグの注釈も失敗の原因になる。
  軽量のタグ（注釈の無いタグ）は中身を持たないので調べない。
- 既知のバイナリの拡張子のファイルは、NUL バイトを含んでも失敗にせず、単純な内容検査（UTF-16 で読んだ中身を含む）
  で調べる。この拡張子の名前を付けた文字のファイルには、secretlint の規則が掛からないことがある。
  NUL バイトを含まない、UTF-8 以外の文字コード（Shift_JIS など）のファイルは見分けない。
- 範囲の既定は手元のすべてのブランチとタグから辿るので、push しないつもりの手元のブランチやタグにあるコミットも
  失敗の原因になる。
- コミットの検査は、`git ls-tree` をコミットごとに 1 回起動するので、範囲のコミットの数に比例して時間が掛かる。
- 手元の push 前の検査（`--commits`）が調べるのは、ブランチとタグから辿れるコミットだけである。git notes、
  `refs/stash`、独自の参照は対象外なので、`git push --mirror` と、ブランチとタグ以外の参照の push は使わない。
- commit 以外（blob や tree）を指すタグの中身、入れ子のタグの内側の注釈、コミットの見出し（mergetag の行）は検査しない。
- 既知のバイナリの拡張子のファイルは、Latin-1 と UTF-16 で読んだ中身だけを検査するので、UTF-32 や圧縮された中身は見ない。
- `--commits` に範囲を明示して渡す呼び出し（CI と開発者）は信頼する前提である。`--max-count=0` のような引数で、
  検査を空にできる。
- push を止める仕組み（pre-push のフック）は入れていない。手元では決まり（AGENTS.md）と CI で補う。
- 2026-10-03 の `npm audit` は、高の脆弱性を 6 件（パッケージの数）報告した。原因はどれも braces 3.0.3 の
  GHSA-vfj7-8cjw-p6xm（深く入れ子にした glob のパターンによるサービス妨害）で、経路は 2 つある。
  - `eslint-config-next` → `@next/eslint-plugin-next` → `fast-glob` → `micromatch` → `braces`
  - `@secretlint/secretlint-rule-pattern` → `micromatch` → `braces`
  どれも開発用の依存で、`npm audit --omit=dev` は 0 件だった。パターンを書くのは開発者自身で、外部の入力は
  渡らない。npm が示す修正は、eslint-config-next を 14 へ、secretlint-rule-pattern を 11 へ戻す互換を壊す変更
  なので、修正しない。Dependabot で修正版が出るのを追う。
