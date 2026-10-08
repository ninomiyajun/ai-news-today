# 今日のニュースを情報源ごとの節に分けて表示する

## 作業の場所

- ブランチ: `feat/news-sections`
- worktree のディレクトリ名: `wt-news-sections`

## 目的

今日のニュースの画面（`/`）の記事一覧を、情報源（Hacker News、はてなブックマーク）ごとの節に分けて表示する。点数の意味が
情報源によって違う（Hacker News は投票の点数、はてなブックマークはブックマークの数）ので、節の中だけで点数の高い順に並べ、
同じ意味の点数どうしで記事を比べられるようにするためである。

製品の仕様: `docs/product-specs/news-by-source.md`（略号 SRC、目録の状態は `approved`）。受け入れ基準 SRC-1〜SRC-13 をすべて
実装する。仕様と目録（`docs/product-specs/` の下）は、この計画では変えない。

前提として読む文書:

- `ARCHITECTURE.md` の「層と責務」（画面の層は組み立てだけ、表示の部品は受け取った値を出すだけ、整形・選別は純粋な関数だけ、
  処理の流れの層は画面から整形・選別の関数を使うときの入口）、「依存の向き」（`src/app/` は `src/curation/` を import できない。
  `src/ui/` は `src/ui/` と `src/domain/` だけを import できる）、「不変条件」の 5（X の埋め込みのスクリプトの扱い）、「確認用のデータ」。
- ADR: `docs/adr/0001-layers-and-checks.md`（層の構成と依存の向き）、`docs/adr/0003-x-post-embed.md`（X の投稿の埋め込み）、
  `docs/adr/0004-fixture-data-for-acceptance.md`（確認用のデータ）。情報源ごとの節についての ADR は無い。
- 完了した計画 `docs/exec-plans/completed/2026-10-08-min-score-filter.md`（点数の下限の絞り込み。この計画はその仕組みを変えずに使う）。
- アプリの起動の手順: `.claude/skills/run-ai-news-today/SKILL.md`。

変えない範囲（まとめ役の指示。ほかの作業と変更が重ならないようにするため）:

- `src/services/today-news.ts` の `getTodayNews` と `TodayNewsDeps`、`src/curation/select.ts` の `selectRecent`、`src/sources/` の下の
  すべてのファイル（確認用のデータ `src/sources/fixture.ts` を含む）。これらのファイルとその試験のファイルは書き換えない（V6）。
  そのため、節に分ける処理と節の中の並べ替えは、`getTodayNews` の結果を受け取る新しい関数として作る。

この計画で使う用語:

- **節**: 1 つの情報源の記事だけを集めた、画面の区画。見出しと記事の一覧を持つ。
- **節の並べ替え**: 節の中の記事を、点数の高い順、点数が同じなら公開日時の新しい順に並べること。
- **表示の順**: 画面の上から下へ記事が出る順。Hacker News の節の記事、はてなブックマークの節の記事の順になる。
- **確認用のデータ**: `AI_NEWS_FIXTURE=sample` で起動したときの決まった記事。選別の後に画面に出るのは、Hacker News の 2 件
  （点数 412 と 88）と、はてなブックマークの 2 件（ブックマーク数 156 と 37）である。ほかに、選別で落ちる 2 件（点数 999 の古い
  Hacker News の記事と、点数 500 の公開日時の無いはてなブックマークの記事。題に「表示されない」を含む）がある。
  X の投稿の URL を含む記事は無い（`src/sources/fixture.ts`）。

## 検証（完了の条件）

確かめ方の「自動テスト」は、`npm run test`（vitest）で通ることを指す（V6 は、書いたコマンドの結果も含む）。

「受け入れ確認」は、実装した本人とは別の受け入れ確認の担当（`app-evaluator`）が、`.claude/skills/run-ai-news-today/SKILL.md` の
手順で確認用のデータで起動した画面を操作して確かめ、`2026-10-08-news-by-source.acceptance.md` に記録することを指す。受け入れ
確認の基準の前提はどれも「`AI_NEWS_FIXTURE=sample` を付け、3100 以上のポートで開発用のサーバーを起動し、画面の上に
『確認用のデータで表示中』が出ている」である。見出し、点数、文言は、ブラウザに表示された文字で読む。

仕様の基準の確かめ方の分け方:

- 確認用のデータの記事が、仕様の基準の前提の記事とちょうど一致する基準（SRC-1、SRC-10）は、受け入れ確認で確かめる。
- 確認用のデータに、前提の記事が無い基準は、自動テストで確かめる。確認用のデータは変えない（`src/sources/` の下は変えない範囲の
  ため）。足りない記事は次のとおりである。
  - SRC-2: Hacker News の 3 件とはてなブックマークの 1 件が無い（確認用のデータは 2 件と 2 件）。
  - SRC-3: 取得した順が点数の高い順でない記事が無い（確認用のデータは、どちらの情報源も点数の高い順に並んでいる）。なお、画面の
    全体を通す試験では、`selectRecent`（変えない範囲）が先に全記事を点数の高い順に並べるので、節の中の並べ替えが無くても SRC-3 の
    期待する結果になる。そのため、節の中の並べ替えそのものは、並べ替えの関数に点数の高い順でない記事を直接渡す V5 の (e) で確かめる。
  - SRC-4: X の投稿の URL を含む記事が無い（含めると、ブラウザが外部のスクリプトを読みに行くため、意図して入れていない）。
  - SRC-5: Hacker News の 1 件とはてなブックマークの 3 件が無い。
  - SRC-6: 記事が 0 件の情報源が無い（下限で絞らずに、はてなブックマークが 0 件になる記事の組が無い）。
  - SRC-7: 前提の記事の組（はてなブックマークがブックマーク数 37 の 1 件だけ）が無い。
  - SRC-8: 下限で絞らずに、すべての情報源が 0 件になる記事の組が無い。
  - SRC-9: 前提の記事の組（Hacker News が点数 88 の 1 件、はてなブックマークがブックマーク数 37 の 1 件）が無い。
  - SRC-11: 点数 150 の記事が無い。
  - SRC-12: 同じ点数の記事が無い。
  - SRC-13: 前提の記事の組（どちらの情報源も 1 件だけ）が、下限を指定しない状態では無い。
- 自動テストの基準のうち、確認用のデータでも同じ振る舞いが画面で見えるものは、計画の基準 V1〜V4 として受け入れ確認でも確かめる
  （画面の全体が実際の起動でつながっていることを、受け入れ確認の担当の目で確かめるため）。
- 仕様の基準の自動テストは、画面の全体（`Home`）を通して確かめる。新しい試験のファイル `src/app/page.sections.test.tsx` で、
  組み立ての層 `@/composition/runtime` を vitest の `vi.mock` で差し替え、仕様の前提の記事を返す情報源と、決まった時刻を返す時計と、
  決まった oEmbed の応答を返す HTTP の入口を `Home` に渡す（手順 5）。`getTodayNews`、`selectRecent`、点数の下限の絞り込みは本物が動く。
  試験の中の記事の公開日時は、決まった時刻 `2026-10-07T03:00:00Z`（日本時間の 12 時）より前の 24 時間に収める。仕様の「9 時」
  「11 時」「8 時」は日本時間として、`2026-10-07T00:00:00Z`、`2026-10-07T02:00:00Z`、`2026-10-06T23:00:00Z` にする。
  出力は `renderToStaticMarkup` で文字列にし、手順 5 で決める HTML の形（節は `<section>`、見出しは `<h2>`、点数は `<small>`）から、
  節ごとの見出しの文字列と記事の並びを読み取る。

### SRC-1 記事が情報源ごとの節に分かれて表示される

- 前提: この節の冒頭の受け入れ確認の前提。確認用のデータの記事が、仕様の SRC-1 の前提と一致する。
- 操作: `http://127.0.0.1:<ポート>/` を開く。
- 期待する結果: 仕様の SRC-1 の期待する結果のとおり。確認用のデータの記事の題（「[確認用]」で始まる）で、どの記事がどの節に出たかを読む。
- 確かめ方: 受け入れ確認
- 対象ファイル: `src/app/page.tsx`、`src/services/news-sections.ts`、`src/curation/group-by-source.ts`、`src/ui/NewsSections.tsx`、`src/ui/NewsList.tsx`、`src/ui/source-labels.ts`、`src/domain/news.ts`

### SRC-2 節の見出しは「Hacker News（3 件）」の形で、情報源の名前と記事の件数を出す

- 前提: `src/app/page.sections.test.tsx` で、仕様の SRC-2 の前提の記事を返すように組み立ての層を差し替えている（この節の冒頭）。
- 操作: `Home` を引数なしで呼び、出力を文字列にする。
- 期待する結果: 仕様の SRC-2 の期待する結果のとおり。`<h2>` の文字列が、上から順に、仕様に書かれた 2 つの見出しと完全に一致する。
- 確かめ方: 自動テスト

### SRC-3 節の中は点数の高い順に並ぶ

- 前提: SRC-2 と同じ形で、仕様の SRC-3 の前提の記事を、仕様に書かれた取得の順で情報源が返す。
- 操作: `Home` を引数なしで呼び、出力を文字列にする。
- 期待する結果: 仕様の SRC-3 の期待する結果のとおり。節ごとの `<small>` の数の並びで確かめる。この試験は `selectRecent` が先に
  並べるので、節の中の並べ替えが無くても通る（検証の節の冒頭）。節の中の並べ替えそのものは V5 の (e) で確かめる。
- 確かめ方: 自動テスト

### SRC-4 X の投稿の埋め込みは、節の中でも元の記事の下に出る

- 前提: SRC-2 と同じ形で、仕様の SRC-4 の前提の記事（Hacker News の 1 件、はてなブックマークの 2 件。はてなブックマークの 1 件の
  `text` にだけ X の投稿の URL `https://x.com/a/status/1` を含める）を返す。差し替えた HTTP の入口は、どの要求にも状態 200 と
  `{"type":"rich","author_name":"A"}` を返す。
- 操作: `Home` を引数なしで呼び、出力を文字列にする。
- 期待する結果: 仕様の SRC-4 の期待する結果のとおり。`<blockquote class="twitter-tweet"` が出力の中にちょうど 1 回あり、それが
  はてなブックマークの節の中の、X の投稿の URL を含む記事の `<li>` の中にある。
- 確かめ方: 自動テスト

### SRC-5 Hacker News の節が、はてなブックマークの節より先に出る

- 前提: SRC-2 と同じ形で、仕様の SRC-5 の前提の記事を返す。情報源は、はてなブックマークの記事を先に返す。
- 操作: `Home` を引数なしで呼び、出力を文字列にする。
- 期待する結果: 仕様の SRC-5 の期待する結果のとおり。`<h2>` の並びが「Hacker News（1 件）」「はてなブックマーク（3 件）」の順である。
- 確かめ方: 自動テスト

### SRC-6 記事が 0 件の情報源の節は出ない

- 前提: SRC-2 と同じ形で、仕様の SRC-6 の前提の記事を返す。
- 操作: `Home` を引数なしで呼び、出力を文字列にする。
- 期待する結果: 仕様の SRC-6 の期待する結果のとおり。`<section` がちょうど 1 つで、「はてなブックマーク」の文字列と「表示できる記事は
  まだありません。」が出力に無い。
- 確かめ方: 自動テスト

### SRC-7 点数の下限で絞り込んだ結果 0 件になった情報源の節は出ない

- 前提: SRC-2 と同じ形で、仕様の SRC-7 の前提の記事を返す。
- 操作: `Home` に `searchParams` として `{ min: "100" }` を渡し、出力を文字列にする。
- 期待する結果: 仕様の SRC-7 の期待する結果のとおり。`<section` がちょうど 1 つで、その節の `<small>` の数の並びが `[412]` である。
- 確かめ方: 自動テスト

### SRC-8 すべての情報源の記事が 0 件のときは、「表示できる記事はまだありません。」の 1 文だけが出る

- 前提: SRC-2 と同じ形で、情報源が記事を 1 件も返さない。
- 操作: `Home` を引数なしで呼び、出力を文字列にする。
- 期待する結果: 仕様の SRC-8 の期待する結果のとおり。「表示できる記事はまだありません。」がちょうど 1 回出て、`<section` と `<h2` が
  出力に無い。
- 確かめ方: 自動テスト

### SRC-9 点数の下限で絞り込んだ結果、すべての情報源が 0 件のときも、「表示できる記事はまだありません。」の 1 文だけが出る

- 前提: SRC-2 と同じ形で、仕様の SRC-9 の前提の記事を返す。
- 操作: `Home` に `searchParams` として `{ min: "100" }` を渡し、出力を文字列にする。
- 期待する結果: 仕様の SRC-9 の期待する結果のとおり。確かめ方の細部は SRC-8 と同じ。
- 確かめ方: 自動テスト

### SRC-10 点数の下限は、1 つの値を両方の節の記事に当てる

- 前提: この節の冒頭の受け入れ確認の前提。確認用のデータの記事が、仕様の SRC-10 の前提の記事と一致する。
- 操作: `http://127.0.0.1:<ポート>/?min=100` を開く。
- 期待する結果: 仕様の SRC-10 の期待する結果のとおり。
- 確かめ方: 受け入れ確認
- 対象ファイル: `src/app/page.tsx`、`src/services/news-sections.ts`、`src/curation/group-by-source.ts`、`src/ui/NewsSections.tsx`、`src/ui/NewsList.tsx`、`src/ui/source-labels.ts`、`src/ui/MinScoreNotice.tsx`

### SRC-11 点数の下限で絞り込んだときの見出しの件数は、絞り込んだ後に表示している記事の数になる

- 前提: SRC-2 と同じ形で、仕様の SRC-11 の前提の記事を返す。
- 操作: `Home` に `searchParams` として `{ min: "100" }` を渡し、出力を文字列にする。
- 期待する結果: 仕様の SRC-11 の期待する結果のとおり。
- 確かめ方: 自動テスト

### SRC-12 同じ節で点数が同じ記事は、公開日時の新しい順に並ぶ

- 前提: SRC-2 と同じ形で、仕様の SRC-12 の前提の記事を返す（公開日時は、この節の冒頭の対応で決める）。記事の題を、点数と公開日時が
  分かる別々の文字列にする。情報源は、点数 88 で 9 時の記事を、点数 88 で 11 時の記事より先に返す。
- 操作: `Home` を引数なしで呼び、出力を文字列にする。
- 期待する結果: 仕様の SRC-12 の期待する結果のとおり。Hacker News の節の記事の題の並びで確かめる。
- 確かめ方: 自動テスト

### SRC-13 記事ごとの点数に、情報源に合わせた単位が付く

- 前提: SRC-2 と同じ形で、仕様の SRC-13 の前提の記事を返す。
- 操作: `Home` を引数なしで呼び、出力を文字列にする。
- 期待する結果: 仕様の SRC-13 の期待する結果のとおり。出力に「412 点」と「156 ブックマーク」があり、「(412)」と「(156)」が無い。
- 確かめ方: 自動テスト

### V1 確認用のデータで、節の順、見出しの件数、点数の単位が出る

- 前提: この節の冒頭の受け入れ確認の前提。
- 操作: `http://127.0.0.1:<ポート>/` を開く。
- 期待する結果: 画面の上から、見出し「Hacker News（2 件）」の節、見出し「はてなブックマーク（2 件）」の節の順に出る。Hacker News の節の
  記事の点数は上から「412 点」「88 点」、はてなブックマークの節は上から「156 ブックマーク」「37 ブックマーク」と出る。「(412)」の形の、
  単位の無い数だけの表示は出ない。「表示できる記事はまだありません。」と、題に「表示されない」を含む記事は出ない。
- 対応する仕様の基準: SRC-2、SRC-5、SRC-13（前提の記事は仕様と違い、確認用のデータで同じ振る舞いを見る）
- 確かめ方: 受け入れ確認
- 対象ファイル: `src/app/page.tsx`、`src/services/news-sections.ts`、`src/curation/group-by-source.ts`、`src/ui/NewsSections.tsx`、`src/ui/NewsList.tsx`、`src/ui/source-labels.ts`

### V2 確認用のデータで、下限で絞り込んだ後の件数が見出しに出る

- 前提: この節の冒頭の受け入れ確認の前提。
- 操作: `http://127.0.0.1:<ポート>/?min=100` を開く。
- 期待する結果: 見出しが上から「Hacker News（1 件）」「はてなブックマーク（1 件）」と出る。
- 対応する仕様の基準: SRC-11（前提の記事は仕様と違い、確認用のデータで同じ振る舞いを見る）
- 確かめ方: 受け入れ確認
- 対象ファイル: `src/app/page.tsx`、`src/services/news-sections.ts`、`src/curation/group-by-source.ts`、`src/ui/NewsSections.tsx`、`src/ui/source-labels.ts`

### V3 確認用のデータで、下限で 0 件になった情報源の節が消える

- 前提: この節の冒頭の受け入れ確認の前提。
- 操作: `http://127.0.0.1:<ポート>/?min=157` を開く。
- 期待する結果: 見出し「Hacker News（1 件）」の節だけが出て、その中に「412 点」の記事だけが出る。「はてなブックマーク」の見出しと、
  「表示できる記事はまだありません。」は出ない。「点数 157 以上を表示中」が 1 回出る。
- 対応する仕様の基準: SRC-6、SRC-7（前提の記事は仕様と違い、確認用のデータで同じ振る舞いを見る）
- 確かめ方: 受け入れ確認
- 対象ファイル: `src/app/page.tsx`、`src/services/news-sections.ts`、`src/curation/group-by-source.ts`、`src/ui/NewsSections.tsx`、`src/ui/source-labels.ts`

### V4 確認用のデータで、下限ですべてが 0 件になると、空の文言だけが出る

- 前提: この節の冒頭の受け入れ確認の前提。確認用のデータには、選別で落ちる点数 999 と 500 の記事がある。
- 操作: `http://127.0.0.1:<ポート>/?min=450` を開く。
- 期待する結果: 記事の一覧の場所に「表示できる記事はまだありません。」だけが出て、「Hacker News」と「はてなブックマーク」の見出しは
  出ない。「点数 450 以上を表示中」が出る。題に「表示されない」を含む記事は出ない。
- 対応する仕様の基準: SRC-8、SRC-9（前提の記事は仕様と違い、確認用のデータで同じ振る舞いを見る）
- 確かめ方: 受け入れ確認
- 対象ファイル: `src/app/page.tsx`、`src/ui/NewsSections.tsx`

### V5 節に分ける関数と、処理の流れの関数が、境界の入力でも正しく動く

- 前提: `src/curation/group-by-source.ts` に `groupBySource`、`src/services/news-sections.ts` に `buildNewsSections` がある（手順 2、3）。
- 操作: 次の入力を渡す。(a) 空の配列。(b) 点数が同じで、公開日時の一方が `null` の 2 件（同じ情報源）。(c) 点数も公開日時も同じ
  2 件（同じ情報源）。(d) はてなブックマークの記事を先に並べた、両方の情報源の記事。(e) 点数が 88、412、37 の順で渡した、同じ
  情報源の 3 件。(f) 節の順の定数 `NEWS_SOURCE_ORDER` を、試験の中で書いた `NewsSourceId` のすべての値の表と比べる（手順 2）。
- 期待する結果: (a) `groupBySource` は空の配列を返し、`buildNewsSections` は `{ sections: [], items: [] }` を返す。(b) 公開日時の
  ある記事が先に並ぶ。(c) 渡した順のまま並ぶ。(d) 節は Hacker News、はてなブックマークの順で、`buildNewsSections` の `items` は
  表示の順（Hacker News の節の記事、はてなブックマークの節の記事の順）に並ぶ。(e) `groupBySource` が返す節の中が、点数 412、88、37 の
  順に並ぶ。(f) `NEWS_SOURCE_ORDER` が `NewsSourceId` のすべての値を、ちょうど 1 回ずつ含む。(a)〜(e) のどの場合も、渡した配列
  そのものは変わらない（呼ぶ前と後の配列の中身を比べる）。
- 確かめ方: 自動テスト

### V6 変えない範囲を変えず、検査がすべて通る

- 前提: 実装の後。下の `<分岐元>` は `git -C <worktree の絶対パス> merge-base HEAD origin/main` の値。
- 操作: 対象のパスを `src/services/today-news.ts src/services/today-news.test.ts src/curation/select.ts src/curation/select.test.ts
  src/sources/` として、次の 2 つを実行する。
  - `git -C <worktree の絶対パス> diff <分岐元> --stat -- <対象のパス>`
  - `git -C <worktree の絶対パス> status --porcelain=v1 --untracked-files=all -- <対象のパス>`

  あわせて、`npm run check` と `npm run build` を走らせる。
- 期待する結果: 2 つのコマンドの出力がどちらも空。`npm run check`（秘匿値、lint、型、試験、文書、文書の検査の試験、
  層の向き）と `npm run build` がどちらも終了コード 0 で終わる。
- 確かめ方: 自動テスト

### V7 X の埋め込みのスクリプトは、節がいくつあっても 1 回だけ描く

- 前提: `src/ui/NewsSections.test.tsx` で、`next/script` を、受け取った引数を記録するだけの部品に差し替える（今の
  `src/ui/NewsList.test.tsx` の基準 10 の試験と同じ形）。
- 操作: `NewsSections` に、(a) 2 つの節と、埋め込みが 0 件の対応、(b) 2 つの節と、Hacker News の記事に 1 件、はてなブックマークの
  記事に 2 件の埋め込みの対応、を渡して描く。
- 期待する結果: (a) `Script` を描かない。(b) `Script` を 1 回だけ、`src` が `WIDGETS_JS_URL` で描く。
- 確かめ方: 自動テスト

### V8 X の投稿の問い合わせの上限 10 件は、表示の順の先頭の記事から当てる

- 前提: `src/app/page.sections.test.tsx` で、差し替えた HTTP の入口が問い合わせ先を記録する。情報源は、Hacker News の 6 件（点数 60、50、
  40、30、20、10）と、はてなブックマークの 6 件（ブックマーク数 600、500、400、300、200、100）を返し、記事ごとに別々の X の投稿の URL
  （`https://x.com/a/status/<点数>`）を `text` に持たせる。全体の点数の順と、表示の順（節の順、節の中の順）が異なる組である。
- 操作: `Home` を引数なしで呼び、出力を文字列にする。
- 期待する結果: 問い合わせた投稿は、表示の順の先頭 10 件（Hacker News の 6 件と、ブックマーク数 600、500、400、300 の記事）の投稿だけで、
  ブックマーク数 200 と 100 の記事の投稿は問い合わせない。埋め込みが 10 件出る。`getXPostsByItem` に節に分ける前の記事を渡す実装では
  Hacker News の 20 と 10 の記事が外れるので、この試験が落ちる（実装を一時的にそう変えて落ちることを確かめた）。
- 確かめ方: 自動テスト

## 手順

順序の依存があるので、上から順に進める（後の手順が、前の手順で作る型と関数を import する）。各手順の試験は、その手順の中で書いて
通す。**各手順の完了の条件は、その手順の終わりに `npm run test`、`npm run typecheck`、`npm run lint` がすべて通ることである。** 既存の
画面の出力を変える変更（`NewsList` の点数の表示、0 件のときの文言とスクリプトの置き場、画面のつなぎ替え）は、それを期待している
既存の試験の直しと一緒に、手順 5 の 1 つの手順で行う。途中の手順で既存の試験が落ちたままにならないようにするためである。

1. **節の型を足す**（`src/domain/news.ts`）。
   - `export type NewsSection = { source: NewsSourceId; items: NewsItem[] };` を足す。表示の部品の層は `src/curation/` を import できない
     ので、節の型は型の層に置く（判断の記録の 1）。ほかの型は変えない。
   - 完了の条件: 型を足しただけで、使う箇所はまだ無い。`npm run test`、`npm run typecheck`、`npm run lint` が通る。
2. **節に分ける関数を作る**（新規の `src/curation/group-by-source.ts` と `src/curation/group-by-source.test.ts`）。
   - `export const NEWS_SOURCE_ORDER: readonly NewsSourceId[] = ["hacker-news", "hatena-bookmark"];`（節の順）。配列のまま持つ
     （判断の記録の 9）。
   - `export function compareInSection(a: NewsItem, b: NewsItem): number`: 点数の高い順。点数が同じなら公開日時の新しい順。公開日時が
     `null` の記事は、公開日時のある記事より後。どちらも `null`、または公開日時が同じなら 0 を返す（`Array.prototype.sort` は安定な
     ので、渡した順が残る）。
   - `export function groupBySource(items: readonly NewsItem[]): NewsSection[]`: `NEWS_SOURCE_ORDER` の順に、その情報源の記事を
     `filter` で集め、写しを `compareInSection` で並べ替える。記事が 0 件の情報源の節は返さない。渡した配列は変えない。
   - 試験: V5 の `groupBySource` の部分（(a)〜(f)）と、仕様の SRC-3、SRC-5、SRC-6、SRC-12 の前提の記事での節の並び（関数の単位）。
     - (e) は、点数が 88、412、37 の順の同じ情報源の 3 件を `groupBySource` に直接渡し、節の中が 412、88、37 の順になることを確かめる。
       画面の全体を通す試験では `selectRecent` が先に並べてしまい、節の中の並べ替えを確かめられないためである（検証の節の冒頭）。
     - (f) は、試験の中に `const ALL_SOURCES: Record<NewsSourceId, true> = { "hacker-news": true, "hatena-bookmark": true };` を書き、
       `Object.keys(ALL_SOURCES)` を並べ替えたものと、`NEWS_SOURCE_ORDER` の写しを並べ替えたものが等しいことを確かめる。`Record` の
       型により、`NewsSourceId` に値を足すとこの表が型の検査で失敗するので、表を直すときに `NEWS_SOURCE_ORDER` の直し漏れが試験で
       分かる（重複も、並べ替えた配列の比較で分かる）。
   - 完了の条件: V5 の `groupBySource` の部分（(e) と (f) を含む）の試験が通り、`npm run test`、`npm run typecheck`、`npm run lint` が通る。
3. **処理の流れの関数を作る**（新規の `src/services/news-sections.ts` と `src/services/news-sections.test.ts`）。
   - `export function buildNewsSections(items: readonly NewsItem[]): { sections: NewsSection[]; items: NewsItem[] }`: `groupBySource` を
     呼び、`sections` と、各節の記事を表示の順につないだ `items` を返す。画面の層から整形・選別の関数を使うための入口である
     （判断の記録の 2）。
   - 試験: V5 の `buildNewsSections` の部分。
   - 完了の条件: V5 の `buildNewsSections` の部分の試験が通り、`npm run test`、`npm run typecheck`、`npm run lint` が通る。
4. **情報源の表示名と単位を作る**（新規の `src/ui/source-labels.ts` と `src/ui/source-labels.test.ts`）。
   - `SOURCE_LABELS: Readonly<Record<NewsSourceId, { name: string; unit: string }>>` を置き、`hacker-news` を
     `{ name: "Hacker News", unit: "点" }`、`hatena-bookmark` を `{ name: "はてなブックマーク", unit: "ブックマーク" }` にする。
   - 文言を組み立てる関数 `sectionHeadingText(source: NewsSourceId, count: number): string`（例: `Hacker News（3 件）`。括弧は全角）と
     `scoreText(source: NewsSourceId, score: number): string`（例: `412 点`、`156 ブックマーク`）を置く。どちらも 1 つの文字列を返す
     （判断の記録の 4）。
   - 試験: 2 つの情報源のそれぞれについて、両方の関数の戻り値を確かめる。
   - 完了の条件: この手順では既存のファイルを変えない。`npm run test`、`npm run typecheck`、`npm run lint` が通る。
5. **表示の部品を直し、画面をつなぎ、既存の試験を直す**（`src/ui/NewsList.tsx`、新規の `src/ui/NewsSections.tsx`、`src/app/page.tsx`
   と、それぞれの試験）。この手順の中の変更は互いに依存し、途中では既存の試験が通らないので、1 つの手順として最後まで続けて行う。
   - `src/ui/NewsList.tsx` を直す。点数の表示を `<small>({item.score})</small>` から `<small>{scoreText(item.source, item.score)}</small>`
     にする。0 件のときの「表示できる記事はまだありません。」と、`XWidgetsScript` の描画を `NewsList` から外す（どちらも
     `NewsSections` へ移す。判断の記録の 3）。題のリンクと X の投稿の埋め込み（`XPostCard`）の出し方は変えない。
   - 新規の `src/ui/NewsSections.tsx`: `NewsSections({ sections, xPosts = {} }: { sections: readonly NewsSection[]; xPosts?:
     Readonly<Record<string, readonly XPostEmbed[]>> })`。
     - `sections` が空なら `<p>表示できる記事はまだありません。</p>` だけを描く。
     - そうでなければ、節ごとに `<section key={source} aria-labelledby="news-section-<source>">` を描き、その中に
       `<h2 id="news-section-<source>">{sectionHeadingText(source, items.length)}</h2>` と `<NewsList items={items} xPosts={xPosts} />` を
       置く。`<source>` は `NewsSourceId` の値（`hacker-news` など）。
     - すべての節の記事のどれかに埋め込みが 1 件以上あれば、最後に `XWidgetsScript` を 1 回だけ描く。
     - 判定や並べ替えはしない（受け取った節をそのまま出す）。
   - `src/app/page.tsx` の流れを、`getTodayNews` → `applyMinScore` → `buildNewsSections` → `getXPostsByItem` の順にする。
     `getXPostsByItem` には `buildNewsSections` が返す表示の順の `items` を渡す（判断の記録の 5）。`NewsList` の代わりに
     `<NewsSections sections={sections} xPosts={xPosts} />` を、`MinScoreNotice` の後に置く。`MinScoreNotice` は今と同じく 1 回だけ置く。
     取得や選別の処理は書かない。
   - 試験:
     - `src/ui/NewsList.test.tsx`: 基準 9 の (a) の期待値を、点数の表示を `<small>3 点</small>` にした文字列に直す。基準 10 の
       スクリプトの試験 4 件のうち、スクリプトの定数の試験は残し、`Script` の描画の回数の試験 3 件は `NewsSections.test.tsx` へ移す
       （`NewsList` は `Script` を描かなくなるため）。`NewsList` が埋め込みの有無にかかわらず `Script` を描かないことの試験を 1 件足す。
     - 新規の `src/ui/NewsSections.test.tsx`: V7 の (a)、(b)、移した 3 件（0 件、1 件、2 つの節の記事に分かれた 3 件）、空の
       `sections` で「表示できる記事はまだありません。」だけを描き `<section` を描かないこと、見出しの文字列と `aria-labelledby` と
       `id` の対応。
     - `src/app/page.test.tsx` の既存の試験を、節に分けた後の出力に合わせて直す（判断の記録の 6）。点数を読み取る関数 `scoresOf` の
       正規表現を `<small>(\d+) (?:点|ブックマーク)</small>` にし、確認用のデータの点数の並びの期待値を表示の順に直す。下限なしと
       `{ min: "abc" }`、`{}`、`{ min: "0" }` は `[412, 88, 156, 37]`、`{ min: "100" }` は `[412, 156]`、`{ min: "88" }` と `{ min: "088" }` は
       `[412, 88, 156]`。1 件目の試験の中で直接書いている同じ正規表現も `scoresOf` に置き換える。文言と `fetch` の確かめ方は変えない。
     - 新規の `src/app/page.sections.test.tsx`。`vi.mock("@/composition/runtime", ...)` で、`createRuntimeDeps` が「試験ごとに決めた記事の
       配列を返す情報源 1 つ」と「`2026-10-07T03:00:00Z` を返す時計」を返し、`createXPostDeps` が「どの要求にも状態 200 と
       `{"type":"rich","author_name":"A"}` を返す HTTP の入口」を返し、`isFixtureMode` が偽を返すようにする。情報源と時計と HTTP の
       入口は、試験のファイルの中でオブジェクトとして書き、`src/sources/` と `src/ports/` を import しない（画面の層からは import
       できないため。判断の記録の 7）。大域の `fetch` は、`page.test.tsx` と同じく呼ばれたら失敗させる。
       この試験で、SRC-2〜SRC-9、SRC-11〜SRC-13 を確かめる（検証の節のとおり）。HTML から節ごとの見出しと記事を読み取る補助の関数
       （`<section` から `</section>` までを切り出し、`<h2>` の文字列、`<small>` の数、`<a>` の題を返す）を、このファイルの中に置く。
   - 完了の条件: V7 と、自動テストの仕様の基準（SRC-2〜SRC-9、SRC-11〜SRC-13）の試験と、直した既存の試験が通り、`npm run test`、
     `npm run typecheck`、`npm run lint` が通る。
6. **検証する**。V5〜V7 と、自動テストの仕様の基準を `npm run test` で確かめ、V6 のコマンドを実行して、結果を「進捗」に書く。
   `npm run build` は `.next/` に出力するが、`.next/` は `.gitignore` で除外されていることを `git status --short` で確かめる。
   `next dev` か `next build` が `AGENTS.md` の `nextjs-agent-rules` の区画を書き戻したら、その差分は消さずに残す（`AGENTS.md` の
   「落とし穴」）。実装の担当は、確認用のデータで起動して V1〜V4、SRC-1、SRC-10 を自分で見てよいが、その結果は受け入れ確認の
   記録に書かず、「進捗」に自己確認として書く。起動したサーバーは、確かめた後に止める。
7. **受け入れ確認を受ける**。まとめ役が `app-evaluator` を起動し、担当が SRC-1、SRC-10、V1〜V4 を確かめて
   `docs/exec-plans/active/2026-10-08-news-by-source.acceptance.md` に記録する。不合格の基準があれば直して、その基準を確かめ直して
   もらう。
8. **計画を閉じる**。「結果と振り返り」を書き、この計画と受け入れ確認の記録を同じ変更で `docs/exec-plans/completed/` へ移す。
   `npm run check:docs` が、移した後の計画の受け入れ確認の記録を確かめる。

## 範囲外

この計画では扱わない。必要になったら別の計画にする。

- **点数の下限を節ごとに指定すること**。仕様が、別の仕様で決めるとしている。
- **確認用のデータの記事を足すこと**。`src/sources/` の下は変えない範囲である。そのため、確認用のデータで確かめられない仕様の基準は
  自動テストで確かめる（検証の節の冒頭）。
- **`src/sources/fixture.ts` の説明の文の更新**。この文は「画面に出るのは前の 4 件で、点数の高い順に 412、156、88、37 と並ぶ」と
  書いており、この計画の後は画面の並びが 412、88、156、37 になって実態と合わなくなる。`src/sources/` の下は変えない範囲なので、
  この計画では直さず、まとめ役へ報告する（発見の 1）。
- **`getTodayNews`、`TodayNewsDeps`、`selectRecent` の変更**。`selectRecent` は今も点数の高い順に並べるが、節の並べ替えはその後で
  `groupBySource` がやり直すので、そのまま残す。
- **層の表の行の追加、依存の向きの規則の変更、`ARCHITECTURE.md` の変更、ADR の追加**（判断の記録の 8）。

## 進捗

- 2026-10-08: 計画を起票した。手順 1〜8 は未着手。未コミットの変更: この計画のファイル（新規）。ほかに、起票の前から
  `docs/product-specs/README.md`（目録の行の追加）と `docs/product-specs/news-by-source.md`（新規）が未コミットである（この計画の
  担当は変えていない）。
- 2026-10-08: 設計レビューの指摘を反映した（`NewsList` の変更を手順 5 へ移し、各手順に完了の条件を書いた。V5 に (e) と (f) を足した。
  SRC-3 の確かめ方の説明を直した。V1〜V4 に対応する仕様の基準を書いた。判断の記録の 9 を足した）。手順 1〜8 は未着手。未コミットの
  変更は上と同じ。
- 2026-10-08: 手順 1 を終えた。`src/domain/news.ts` に `NewsSection` を足した。`npm run test`（103 件）、`npm run typecheck`、
  `npm run lint` が通った。残り: 手順 2〜8。
- 2026-10-08: 手順 2 を終えた。`src/curation/group-by-source.ts`（`NEWS_SOURCE_ORDER`、`compareInSection`、`groupBySource`）と
  その試験（13 件。V5 の (a)〜(f)、公開日時がどちらも `null` の場合、SRC-3、SRC-5、SRC-6、SRC-12 の関数の単位、`compareInSection`）を
  書いた。`npm run test`（116 件）、`npm run typecheck`、`npm run lint` が通った。残り: 手順 3〜8。
- 2026-10-08: 手順 3 を終えた。`src/services/news-sections.ts`（`buildNewsSections`）とその試験（5 件。V5 の (a)〜(e)）を書いた。
  `npm run test`（121 件）、`npm run typecheck`、`npm run lint` が通った。残り: 手順 4〜8。
- 2026-10-08: 手順 4 を終えた。`src/ui/source-labels.ts`（`SOURCE_LABELS`、`sectionHeadingText`、`scoreText`）とその試験（5 件）を
  書いた。既存のファイルは変えていない。`npm run test`（126 件）、`npm run typecheck`、`npm run lint` が通った。残り: 手順 5〜8。
- 2026-10-08: 手順 5 を終えた。`src/ui/NewsList.tsx`（点数を `scoreText` で出し、0 件の文言とスクリプトの描画を外した）、新規の
  `src/ui/NewsSections.tsx`、`src/app/page.tsx`（`getTodayNews` → `applyMinScore` → `buildNewsSections` → `getXPostsByItem`）を直した。
  試験: `src/ui/NewsList.test.tsx`（基準 9 の (a) の期待値を `<small>3 点</small>` に直し、`Script` の描画の回数の試験 3 件を移して、
  `Script` を描かないことの試験 1 件を足した）、新規の `src/ui/NewsSections.test.tsx`（8 件。V7 の (a)(b)、移した 3 件、空の節、見出しと
  `aria-labelledby` と `id` の対応、受け取った順のまま描くこと）、`src/app/page.test.tsx`（`scoresOf` の正規表現と点数の並びの期待値を
  直し、1 件目の試験の題の「点数の高い順に」を「節ごとに点数の高い順に」に直した）、新規の `src/app/page.sections.test.tsx`（11 件。
  SRC-2〜SRC-9、SRC-11〜SRC-13）。`npm run test`（143 件）、`npm run typecheck`、`npm run lint` が通った。残り: 手順 6〜8。
- 2026-10-08: 手順 6 を終えた（ただし `npm run check` は、発見の 3 のとおり、この計画の前からある未コミットの目録の行のために
  `npm run test:harness` で失敗する）。
  - V5〜V7 と、自動テストの仕様の基準（SRC-2〜SRC-9、SRC-11〜SRC-13）: `npm run test` で 18 ファイル、143 件がすべて通った。
  - V6 のコマンド: 分岐元は `3081e6e`（HEAD と同じ）。対象のパスの `git diff <分岐元> --stat` と `git status --porcelain=v1
    --untracked-files=all` の出力は、どちらも空だった。
  - `npm run check`: `check:secrets`、`lint`、`typecheck`、`test`、`check:docs`（「check-docs: OK（ハーネスの版 1）」）は通り、
    `test:harness` が「88 件中 8 件が期待と違います」で失敗した（発見の 3）。続きの `check:arch` は単独で走らせて
    「no dependency violations found」で通った。
  - `npm run build`: 終了コード 0 で通った。`.next/` は `.gitignore` の `/.next/` で除外され、`git status --short` に出ない。
    `AGENTS.md` の `nextjs-agent-rules` の区画の書き戻しは起きなかった（差分なし）。
  - 自己確認（受け入れ確認の記録には書かない）: `AI_NEWS_FIXTURE=sample` でポート 3107 に開発用のサーバーを起動し、HTML を取得して
    読んだ。`/` は見出し「Hacker News（2 件）」「はてなブックマーク（2 件）」、点数「412 点」「88 点」「156 ブックマーク」「37 ブックマーク」
    （V1、SRC-1）。`/?min=100` は見出し「Hacker News（1 件）」「はてなブックマーク（1 件）」、点数「412 点」「156 ブックマーク」、
    「点数 100 以上を表示中」（V2、SRC-10）。`/?min=157` は見出し「Hacker News（1 件）」だけで「412 点」だけ（V3）。`/?min=450` は
    見出しが無く、空の文言が 1 回と「点数 450 以上を表示中」（V4）。どれも「確認用のデータで表示中」が出て、「表示されない」と「(412)」は
    出なかった。確かめた後にサーバーを止めた。
  - 残り: 手順 7（受け入れ確認）と手順 8（計画を閉じる）。未コミットの変更: この計画のファイル（新規）、
    `docs/product-specs/README.md` と `docs/product-specs/news-by-source.md`（起票の前から。この計画の担当は変えていない）、
    手順 1〜5 で書いた `src/` の下のファイル（変更: `src/domain/news.ts`、`src/ui/NewsList.tsx`、`src/ui/NewsList.test.tsx`、
    `src/app/page.tsx`、`src/app/page.test.tsx`。新規: `src/curation/group-by-source.ts` とその試験、`src/services/news-sections.ts` と
    その試験、`src/ui/source-labels.ts` とその試験、`src/ui/NewsSections.tsx` とその試験、`src/app/page.sections.test.tsx`）。
- 2026-10-08: 実装レビューの指摘で、`src/ui/NewsList.test.tsx` の基準 9 の (a) の試験の名前を「点数に単位を付けたほかは変更前と同じ
  出力になる」に直した（期待値と名前を合わせるため。名前だけの変更）。`npm run test`（143 件）が通った。残り: 手順 7、8。
- 2026-10-08: 第二レビューの推奨で、基準 V8 を足し（判断の記録の 11）、`src/app/page.sections.test.tsx` に V8 の試験 1 件と、HTTP の入口の
  問い合わせ先の記録を足した。`src/app/page.tsx` の `getXPostsByItem` に節に分ける前の記事を渡すように一時的に変えると V8 の試験だけが
  落ち、元に戻すと通ることを確かめた（`src/app/page.tsx` は元のまま）。`npm run test`（144 件）、`npm run typecheck`、`npm run lint` が
  通った。残り: 手順 7、8。
- 2026-10-08: 手順 7 を終えた。受け入れ確認の担当（`app-evaluator`）の実行 1 で、SRC-1、SRC-10、V1〜V4 がすべて合格した（記録は
  `2026-10-08-news-by-source.acceptance.md`。全体は合格）。記録の「確かめた対象」の 8 ファイルの `git hash-object` の値は、閉じる時点の
  作業ツリーの値と一致する（実行 1 の後に変えたのは試験のファイルと計画だけ）。
- 2026-10-08: 発見の 3 の文書の検査の試験の不具合が、別の PR（main のコミット `5233352`、マージ `caaee44`）で直り、このブランチに取り込まれた。
  取り込んだ後に `npm run check`（試験 18 ファイル 144 件、「check-docs: OK（ハーネスの版 1）」、「check-docs.test: 88 件中 88 件が期待どおり」、
  層の向きの検査「no dependency violations found」）と `npm run build` が、どちらも終了コード 0 で通った。V6 を満たした。
- 2026-10-08: 手順 8 を行った。「結果と振り返り」を書き、この計画と受け入れ確認の記録を `docs/exec-plans/completed/` へ移した。
  未コミットの変更: 上の手順 6 の行に書いたファイル、`src/ui/NewsList.test.tsx`、`src/app/page.sections.test.tsx`（V8）、この計画と
  受け入れ確認の記録（どちらも新規。`completed/` の下）、`docs/product-specs/README.md` と `docs/product-specs/news-by-source.md`。

## 発見

1. **（起票の時点で分かったこと）確認用のデータの説明の文が、この計画の後に実態と合わなくなる。** `src/sources/fixture.ts` の
   `FIXTURE_ITEMS` の説明に「点数の高い順に 412、156、88、37 と並ぶ」とあるが、節に分けた後の画面の並びは 412、88、156、37 になる。
   `src/sources/` の下は変えない範囲なので直さない（範囲外）。
2. **（起票の時点で分かったこと）今の画面の試験と表示の部品の試験は、1 つの列の並びと、単位の無い点数の形（`<small>(412)</small>`）を
   期待している。** `src/app/page.test.tsx` の点数の並びの期待値（`[412, 156, 88, 37]` など）と正規表現、`src/ui/NewsList.test.tsx` の
   基準 9 の (a) の期待値が、この計画の変更で合わなくなる（判断の記録の 6）。
3. **（手順 6 で分かったこと）`npm run test:harness` が、未コミットの目録の行のために失敗する。** `scripts/harness/check-docs.test.sh` は、
   本物の `docs/product-specs/README.md` を「書式と、空の目録」として一時ディレクトリへ写して試験する。起票の前から未コミットの
   目録の行（略号 SRC、`news-by-source.md`）があるので、写した先にその仕様のファイルが無く、通るはずの 8 件が「リンク先
   news-by-source.md がありません」で失敗する。この計画のコードの変更とは関係が無い。確かめ方: 同じ 2 つのスクリプトと
   `docs/PLANS.md`、`docs/PRODUCT_SENSE.md` を一時ディレクトリへ写し、目録を HEAD の版にすると「88 件中 88 件が期待どおり」、
   作業ツリーの版にすると「88 件中 8 件が期待と違います」になった。仕様と目録はこの計画では変えず、`scripts/harness/` は計画の
   範囲の外なので、直さずにまとめ役へ報告する（V6 の `npm run check` はこの点が直るまで通らない）。
   その後、この不具合は別の PR（main のコミット `5233352`「文書の検査の試験が、目録に登録された仕様の行に左右されないようにする」）で
   直り、このブランチに取り込んだ。取り込んだ後は「88 件中 88 件が期待どおり」になり、`npm run check` が通った。

## 判断の記録

1. **節の型 `NewsSection` は `src/domain/news.ts` に置く。** 節を作るのは整形・選別の層で、表示するのは表示の部品の層である。表示の
   部品の層は `src/ui/` と `src/domain/` しか import できないので、両方から使える型の層に置く。
2. **層の分け方: 節に分ける処理と節の並べ替えは `src/curation/group-by-source.ts`、画面からの入口は `src/services/news-sections.ts`、
   表示は `src/ui/NewsSections.tsx`（と直した `src/ui/NewsList.tsx`、新規の `src/ui/source-labels.ts`）、つなぎは `src/app/page.tsx` に
   置く。** 節に分ける処理は記事の配列だけを扱う純粋な関数なので整形・選別の層に当たる。画面の層は整形・選別の層を import できない
   ので、点数の下限と同じく処理の流れの層を入口にする。変えない範囲（`getTodayNews`、`selectRecent`）に手を入れないため、
   `getTodayNews` の結果を受け取る新しい関数にする。
3. **0 件のときの文言と、X の埋め込みのスクリプトの描画は、`NewsList` から `NewsSections` へ移す。** `NewsList` は節ごとに描かれる
   ので、そのままでは節の数だけスクリプトを描き、記事が 0 件の節にも文言を出してしまう。画面に 1 つだけ出すものは、画面に 1 つだけ
   置く `NewsSections` に持たせる。
4. **見出しと点数の文言は、1 つの文字列を返す関数で組み立てる。** JSX で文字列と数を並べると、サーバーで描いた HTML に区切りの
   コメント（`<!-- -->`）が入り、HTML の文字列の検索で文言が見つからなくなる（完了した計画 `2026-10-08-min-score-filter.md` の
   判断の記録の 5 と発見の 3）。情報源の表示名と単位は画面に出す文言なので、表示の部品の層に置く。
5. **`getXPostsByItem` には、表示の順の記事を渡す。** `getXPostsByItem` は、渡された記事の順に、先頭の 10 件の投稿だけを oEmbed に
   問い合わせる（`MAX_X_POSTS_TOTAL`）。表示の順で渡すと、画面の上にある記事の投稿から埋め込みが出る。点数の下限で絞り込んだ後に
   渡すのは今と同じで、表示しない記事のために問い合わせないためである。
6. **既存の画面の試験と表示の部品の試験の期待値を直す。** 仕様が、1 つの列の並びと単位の無い点数の表示を変えるので、それを期待して
   いた試験は仕様に合わせて直す。直すのは期待値と、点数を読み取る正規表現と、`Script` の描画の回数の試験の置き場だけで、確かめている
   性質（確認用のデータのときだけ出る、外部へ通信しない、下限の文言の有無、スクリプトを 1 回だけ描く）は変えない。
7. **仕様の基準の自動テストは、組み立ての層を `vi.mock` で差し替えて、画面の全体（`Home`）を通して確かめる。** 確認用のデータは
   変えない範囲にあり、仕様の前提の記事を画面に出す方法がほかに無い。差し替えるのは組み立ての層だけなので、`getTodayNews`、
   `selectRecent`、点数の下限の絞り込み、節に分ける処理、表示の部品は本物が動く。画面の層の試験から `src/sources/` と `src/ports/` を
   import すると層の向きの検査に反するので、情報源、時計、HTTP の入口は、型が合うオブジェクトを試験のファイルの中に書く。
8. **`ARCHITECTURE.md` と ADR は変えない。** 層、依存の向き、不変条件を変えず、各層の責務の文（処理の流れの層が画面の入口を兼ねる
   ことを含む）の範囲に収まるためである。閉じるときに、残す価値のある設計判断が出ていれば、そのときに ADR にする。

9. **節の順の定数 `NEWS_SOURCE_ORDER` は、`NewsSourceId` の値を並べた配列のまま持ち、すべての値を覆うことは試験で保証する（V5 の
   (f)）。** 配列は順を表せるが、型だけでは値の漏れと重複を防げない。そこで、試験の中に `Record<NewsSourceId, true>` の表を書き、
   型の検査で表の漏れを、試験で配列との食い違いを見つける。漏れたまま動くと、その情報源の記事が画面からどの節にも出ずに消えるためである。
   **情報源を足すときに直す箇所**は次の 3 つで、どれか 1 つでも直し漏れると、型の検査か試験が失敗する。
   - 型の層: `src/domain/news.ts` の `NewsSourceId` に値を足す。
   - 整形・選別の層: `src/curation/group-by-source.ts` の `NEWS_SOURCE_ORDER` に、節の順の位置で値を足す（あわせて、その試験の
     `ALL_SOURCES` の表にも足す）。
   - 表示の部品の層: `src/ui/source-labels.ts` の `SOURCE_LABELS` に、表示名と単位を足す（`Record` の型により、足さないと型の検査で
     失敗する）。

10. **（手順 6）発見の 3 の `npm run test:harness` の失敗は、この計画では直さない。** 原因は起票の前からある目録の行と、本物の目録が
    空であることを前提にした文書の検査の試験の組み合わせで、直す先は仕様の目録（この計画では変えない）か `scripts/harness/`
    （計画の範囲の外）である。どちらもまとめ役の判断が要るので、報告に回した。V6 の完了の条件は変えていない。
11. **（第二レビューの推奨）判断の記録の 5 を画面の全体で確かめる基準 V8 を、合意の後に完了の条件へ足した。** `getXPostsByItem` に
    渡す記事の順を誤って節に分ける前の順に戻しても、ほかの試験は落ちず、問い合わせの上限で画面の上の記事の埋め込みが欠けることに
    気づけないためである。

## 未決の点

[NEEDS CLARIFICATION] の点は無い。

## 結果と振り返り

結果:

- 今日のニュースの画面の記事一覧を、情報源ごとの節（Hacker News、はてなブックマークの順）に分けた。節の見出しは「Hacker News（2 件）」の
  形で、表示している件数を出す。節の中は点数の高い順、点数が同じなら公開日時の新しい順に並ぶ。点数には「412 点」「156 ブックマーク」の
  単位を付けた。記事が 0 件の節は出さず、すべてが 0 件のときは「表示できる記事はまだありません。」だけを出す。点数の下限の指定は変えず、
  1 つの値を両方の節に当てる。
- 層は、節に分ける処理と節の並べ替えを `src/curation/group-by-source.ts`、画面からの入口を `src/services/news-sections.ts`、表示を
  `src/ui/NewsSections.tsx`（と直した `src/ui/NewsList.tsx`、新規の `src/ui/source-labels.ts`）、節の型を `src/domain/news.ts`、つなぎを
  `src/app/page.tsx` に置いた。`getTodayNews`、`TodayNewsDeps`、`selectRecent`、`src/sources/` の下、`ARCHITECTURE.md`、ADR は変えていない（V6）。
- 自動テストの基準（SRC-2〜SRC-9、SRC-11〜SRC-13、V5〜V8）は `npm run test` で合格し、`npm run check` と `npm run build` が終了コード 0 で
  通った。受け入れ確認の基準（SRC-1、SRC-10、V1〜V4）は、受け入れ確認の担当の実行 1 ですべて合格した。
- 合意の後に、第二レビューの推奨で基準 V8（X の投稿の問い合わせの上限を表示の順の先頭から当てること）を足した（判断の記録の 11）。
- 新しい ADR は書かない。層、依存の向き、不変条件を変えず、判断はこの計画の判断の記録で足りるためである（判断の記録の 8）。

振り返り:

- 確認用のデータを変えない範囲に置いたため、仕様の基準の多くは、組み立ての層を差し替えて画面の全体を通す自動テストで確かめた。
  確認用のデータで同じ振る舞いが見える基準（V1〜V4）を受け入れ確認にも置いたことで、実際の起動でのつながりも確かめられた。
- 画面の全体を通す試験では、`selectRecent` が先に全記事を並べるので、節の中の並べ替えが無くても通る基準がある（SRC-3）。並べ替えそのものは
  関数の単位の試験（V5 の (e)）で、渡す記事の順は表示の順と全体の順が食い違う組（V8）で確かめる必要があった。
- 文書の検査の試験が本物の目録を「空の目録」として写していたため、仕様を目録に載せた時点で `npm run check` が落ちた（発見の 3）。
  別の PR で直した。
- 範囲外として残したこと: `src/sources/fixture.ts` の説明の文の並び（412、156、88、37）が、画面の並び（412、88、156、37）と合わなくなった
  こと（発見の 1）。
