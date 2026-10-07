# ai-news-today の規約

ハーネスの版: 1

この行は、このプロジェクトにハーネス（規約と検査の一式）を導入済みであることを示す印である。
`scripts/harness/check-docs.sh` が、この版で必須のファイルが揃っているかを確かめる。印の書式（「ハーネスの版: 」に
整数を続けた 1 行）は、ハーネスの規約が定めたものに合わせている。版の数は、必須のファイルが増えるときに上げ、
同じ変更で `check-docs.sh` の版ごとの一覧を足す。

## このアプリ

AI に関する今日のニュースを表示する Next.js のアプリ。手元の PC で本人だけが見る。コードは公開リポジトリ
ai-news-today（GitHub）に置く。現在は土台だけで、記事の取得と翻訳は未実装。X の投稿の表示は、記事の URL と
記事に添えた文章に含まれる投稿の URL を埋め込みで出す部分だけを実装した（ブックマークレットでの登録は未実装）。

## コードから推測できない決定

- 記事は Hacker News（Algolia の HN Search API。点数）と、はてなブックマーク（テクノロジーの人気エントリーの RSS。
  ブックマーク数）から、AI に関する新しいニュース性のある記事を選ぶ。新しさは記事そのものの公開日で判定し、
  公開日が分からない記事は表示しない。
- 記事の本文は開いたときに取得し、Claude Code の CLI（`claude -p --model haiku`。定額プランの枠）で日本語に翻訳する。
  従量課金の API キーを翻訳の処理に渡さない。
- 取得した本文と翻訳は、手元の PC にだけ保存し、リポジトリにも公開のサーバーにも置かない（私的使用の範囲に留めるため）。
- X の投稿は、HN とはてなブックマークに出た X の投稿の URL と、利用者がブックマークレットで登録した URL を、
  X の公式の埋め込み（oEmbed）で表示する。X のログイン情報は持たない。X を自動で収集しない。
- 開発用のサーバーは `127.0.0.1` にだけ待ち受ける（`package.json` の `dev` と `start`）。

## 秘匿値と個人情報（必須）

- 秘匿値（API の鍵、トークン、Cookie、パスワード）をリポジトリのファイルに書かない。`.env` で始まるファイルは
  `.gitignore` で除外している。例外は、変数の名前だけを書く `.env.example` だけで、値は書かない。
- `NEXT_PUBLIC_` で始まる環境変数に、API の鍵などの秘匿値を置かない。この接頭辞の値は、ブラウザへ渡すコードに
  埋め込まれるためである（Next.js の公式文書 Environment Variables）。
- 公開リポジトリなので、コミットするファイルに個人情報（アカウント名、姓名、メールアドレス）とホームの絶対パスを
  書かない。パスは `~/...` かプレースホルダーで書く。
- push の前に、`git fetch --prune origin` の後で `npm run check:secrets:push` を通す。手元のすべてのブランチとタグから
  辿れて、push 先のリモートの追跡ブランチから辿れないコミット（初回の push ではすべてのコミット）に記録された中身と
  コミットメッセージ、手元のすべての注釈付きのタグの注釈を調べる。今いるブランチ以外のブランチやタグを push する場合も
  含めるためである。push 先が `origin` でなければ `npm run check:secrets:push -- --remote <名前>` とする。
  作業ツリーだけを調べる `npm run check:secrets` では、途中のコミットに入れて後で消した値や、ステージした内容と
  作業ツリーの違いを見落とすためである。CI も同じ検査をするが、CI は push の後にしか動かない。
  `git push --mirror` と、ブランチとタグ以外の参照の push は使わない（検査の対象外のため）。
- 秘匿値の検査を弱めない。`.secretlintignore` のファイルと secretlint の無効化のコメントは、検査が失敗にする。
  誤検出は `.secretlintrc.json` の設定で直し、ADR に理由を書く（`docs/adr/0002-secret-scan-scope.md`）。

## 検査のコマンド

| 何を確かめるか | コマンド |
|---|---|
| 全部（CI と同じ順） | `npm run check` |
| lint | `npm run lint` |
| 型 | `npm run typecheck` |
| 試験 | `npm run test` |
| 文書（必須のファイル、CLAUDE.md、地図、リンク、目録、行数、計画の必須の節、受け入れ確認の記録） | `npm run check:docs` |
| 文書の検査の試験（`check-docs.sh` の計画と受け入れ確認の記録の検査） | `npm run test:harness` |
| 層の依存の向きと、`src/` の直下の名前 | `npm run check:arch` |
| 秘匿値（作業ツリーの、コミットする全ファイル） | `npm run check:secrets` |
| 秘匿値（push する範囲の各コミットの中身） | `npm run check:secrets:push` |
| 手元で起動 | `npm run dev`（http://127.0.0.1:3000）。確認用のデータ（決まった記事と時刻。外部へ通信しない。画面に「確認用のデータで表示中」が出る）で起動するときは `AI_NEWS_FIXTURE=sample npm run dev -- -p <ポート>`（3000 は普段の起動に使うので、確認には 3100 以上を使う。`docs/adr/0004-fixture-data-for-acceptance.md`） |

リンクの検査が見るのは、インラインのリンクと画像（角括弧の文字の直後に、丸括弧で囲んだ先を続ける形）で、先に空白も
`)` も含まないものだけである。参照形式のリンク、山括弧で囲んだ先、タイトル付きの先、自動リンク、HTML の a 要素は検査しないので、
文書の中のリンクはインラインの形で書く。

## 文書の地図

| 種類 | パス | 読む条件 |
|---|---|---|
| 設計の正本（層、依存の向き、不変条件） | `ARCHITECTURE.md` | コードを変える前 |
| 設計判断の記録 | `docs/adr/README.md` | 設計を変える前、過去の判断の理由を知りたいとき |
| 計画の書式 | `docs/PLANS.md` | 計画を書くとき、計画を読むとき |
| アプリの起動の手順 | `.claude/skills/run-ai-news-today/SKILL.md` | アプリを起動して画面を確かめるとき（受け入れ確認を含む） |
| 進行中の計画 | `docs/exec-plans/active/` | 作業を再開するとき |
| 完了した計画 | `docs/exec-plans/completed/` | 過去の作業の経緯を知りたいとき |
| 品質目標 | `docs/QUALITY_SCORE.md` | 設計の品質を判断するとき |
| ハーネスの評価課題 | `docs/quality-eval/README.md` | ハーネスを変えた後に効果を測るとき |

## 落とし穴

- この版の Next.js（16）は、学習データの Next.js と API が違うことがある。コードを書く前に `node_modules/next/dist/docs/`
  の該当の文書を読む（下の Next.js の区画を参照）。
- 下の `nextjs-agent-rules` の区画は `next dev` が書き戻す。消さずにコミットする。
- Claude Code は、`CLAUDE.md` があるとこのファイルを自分からは読まない。そのため `CLAUDE.md` は `@AGENTS.md` の 1 行に
  している。`CLAUDE.md` に他の内容を書かず、指示はこのファイルに書く（`npm run check:docs` が 1 行との完全な一致を確かめる）。
- 現在時刻と外部への通信は `src/ports/` からだけ得る（ESLint が他の場所での `fetch` などの通信の名前、`Date.now()`、
  `Date()`、引数の無い `new Date()`、`Temporal.Now` と、通信のためのモジュールの import を拒否する。別名を経由した
  書き方は ESLint では止められない。詳細は `ARCHITECTURE.md` の不変条件）。

<!-- BEGIN:nextjs-agent-rules -->

# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` (resolved from this file's directory; in monorepos the `next` package may not be visible from the repo root) before writing any code. Heed deprecation notices.

This block is written and re-added by `next dev` — verify at `node_modules/next/dist/server/lib/generate-agent-files.js`. Removing it from a diff only re-creates the uncommitted change; committing it with your work keeps the tree clean.

<!-- END:nextjs-agent-rules -->
