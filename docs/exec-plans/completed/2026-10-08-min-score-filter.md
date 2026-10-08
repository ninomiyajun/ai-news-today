# 点数の下限で記事を絞り込む

## 作業の場所

- ブランチ: `feat/min-score-filter`
- worktree のディレクトリ名: `wt-news-minscore`（`origin/main` から作成した）

## 目的

画面（`/`）の URL のクエリ `?min=<数>` で点数の下限を指定すると、その点数以上の記事だけを表示し、画面に
「点数 N 以上を表示中」と出す。点数の低い記事を読み飛ばしたいときに、URL だけで一覧を短くできるようにするためである。

利用者と合意した範囲:

- `?min=<数>` を指定すると、点数がその数以上の記事だけを表示する。ちょうどその点数の記事も含める。
- 絞り込んでいるときは、画面に「点数 N 以上を表示中」と出す（N は下限の数）。
- 不正な値（数でない、負、空など）のときは絞り込まない。
- 記事の取得はまだ無いので、画面の確認は確認用のデータ（`AI_NEWS_FIXTURE=sample`。画面に出る記事の点数は 412、156、88、37 の
  4 件）で行う。
- 細部（不正な値の扱いの詳細、表示の文言の細部、層の分け方）は、計画の担当が `ARCHITECTURE.md` と既存のコードに合わせて決める
  （判断の記録）。

前提として読む文書:

- 製品の仕様: 無い（このプロジェクトに仕様の文書はまだ無い）。完了の条件は、この計画の「検証（完了の条件）」に直接書く。
- `ARCHITECTURE.md` の「層と責務」（画面の層は組み立てだけ、表示の部品は表示だけ、整形・選別は純粋な関数だけ）、
  「依存の向き」（`src/app/` は `src/curation/` を import できない）、「確認用のデータ」。
- ADR: `docs/adr/0001-layers-and-checks.md`（層の構成と依存の向き）、`docs/adr/0004-fixture-data-for-acceptance.md`
  （確認用のデータ）。点数の絞り込みについての ADR は無い。
- アプリの起動の手順: `.claude/skills/run-ai-news-today/SKILL.md`。
- Next.js 16 の頁の `searchParams`: `node_modules/next/dist/docs/01-app/03-api-reference/03-file-conventions/page.md`（発見の 1）。

この計画で使う用語:

- **下限の値**: クエリ `min` の値を解釈した結果。0 以上の整数か、「絞り込まない」（`null`）のどちらか。
- **解釈の関数**: クエリ `min` の生の値（文字列、文字列の配列、無し）を受け取り、下限の値を返す関数 `parseMinScore`。
- **絞り込みの関数**: 記事の配列と下限の値を受け取り、点数が下限の値以上の記事だけを、元の順のまま返す純粋な関数 `filterByMinScore`。

## 検証（完了の条件）

確かめ方の「自動テスト」は、`npm run test`（vitest）で通ることを指す（V5 は、書いたコマンドの結果も含む）。
「受け入れ確認」は、実装した本人とは別の受け入れ確認の担当（`app-evaluator`）が、`.claude/skills/run-ai-news-today/SKILL.md` の
手順で確認用のデータで起動した画面を操作して確かめ、`2026-10-08-min-score-filter.acceptance.md` に記録することを指す。
受け入れ確認の基準の前提はどれも「`AI_NEWS_FIXTURE=sample npx next dev -H 127.0.0.1 -p <ポート>`（ポートは 3100 以上）で起動し、
画面の上に『確認用のデータで表示中』が出ている」である。文言と点数は、ブラウザに表示された文字で読む（記事の点数は、
各記事の題の後ろの括弧の中の数）。

### V1 解釈の関数が正しい値を下限として受け取る

- 前提: `src/services/score-filter.ts` に解釈の関数 `parseMinScore(raw: string | readonly string[] | undefined): number | null` がある。
- 操作: 次の値を渡す。`"100"`、`"0"`、`"88"`、`"088"`。
- 期待する結果: 順に `100`、`0`、`88`、`88` を返す。
- 確かめ方: 自動テスト

### V2 解釈の関数が不正な値を絞り込まないとする

- 前提: V1 と同じ。
- 操作: 次の値を渡す。`undefined`、`""`、`"abc"`、`"-5"`、`"1.5"`、`" 100"`、`"100 "`、`"+5"`、`"1e2"`、`"0x10"`、`"１００"`（全角の数字）、
  `"99999999999999999999"`（`Number.MAX_SAFE_INTEGER` を超える）、`["100", "200"]`（同じ名前のクエリが 2 つ）。
- 期待する結果: どれも `null` を返し、例外を投げない。
- 確かめ方: 自動テスト

### V3 絞り込みの関数が境界の値を含め、順を保つ

- 前提: `src/curation/score-filter.ts` に絞り込みの関数 `filterByMinScore(items: readonly NewsItem[], minScore: number | null): NewsItem[]` がある。
  記事は点数が 412、156、88、37 の順の 4 件。
- 操作: 下限の値を (a) `88`、(b) `89`、(c) `0`、(d) `1000`、(e) `null` にして渡す。
- 期待する結果: 返す記事の点数が (a) `[412, 156, 88]`、(b) `[412, 156]`、(c) `[412, 156, 88, 37]`、(d) `[]`、(e) `[412, 156, 88, 37]`。
  渡した配列そのものは変わらない（試験で、呼ぶ前と後の配列の中身を比べる）。
- 確かめ方: 自動テスト

### V4 画面の全体を通して、クエリで絞り込まれ、文言が出る

- 前提: `src/app/page.test.tsx` の既存の 3 件の試験と同じく、大域の `fetch` を失敗させ、`AI_NEWS_FIXTURE=sample` にする。
- 操作: `Home` に `searchParams` として次を渡し、`renderToStaticMarkup` で文字列にする。(a) `{ min: "100" }`、(b) `{ min: "88" }`、
  (c) `{ min: "abc" }`、(d) `{}`、(e) 引数を渡さない（既存の `renderHome()` で呼ぶ）、(f) `{ min: "0" }`、(g) `{ min: "088" }`。
- 期待する結果: 出力の点数（`<small>(<数>)</small>`）が (a) `[412, 156]`、(b) `[412, 156, 88]`、(c)〜(e) `[412, 156, 88, 37]`、
  (f) `[412, 156, 88, 37]`、(g) `[412, 156, 88]`。「点数 100 以上を表示中」が (a) に、「点数 88 以上を表示中」が (b) と (g) に、
  「点数 0 以上を表示中」が (f) に出て、(c)〜(e) には「以上を表示中」の文字列が無い。`fetch` は呼ばれない。既存の 3 件の試験は、
  書き換えずに通る。
- 確かめ方: 自動テスト

### V5 既存の形を変えず、検査がすべて通る

- 前提: 実装の後。下の `<分岐元>` は `git -C <worktree の絶対パス> merge-base HEAD origin/main` の値。
- 操作: 次の 2 つを実行する。対象のパスは `src/services/today-news.ts src/services/today-news.test.ts src/curation/select.ts
  src/curation/select.test.ts src/composition/ src/sources/ src/domain/ src/ports/`（以下「対象のパス」）。
  - `git -C <worktree の絶対パス> diff <分岐元> --stat -- <対象のパス>`
  - `git -C <worktree の絶対パス> status --porcelain=v1 --untracked-files=all -- <対象のパス>`

  あわせて、`npm run check` と `npm run build` を走らせる。
- 期待する結果: 2 つのコマンドの出力がどちらも空。`npm run check`（lint、型、試験、文書、層の向き、秘匿値）と `npm run build`
  （Next.js の頁の型の検査を含む）がどちらも終了コード 0 で終わる。
- 確かめ方: 自動テスト

### V6 クエリが無いときは、これまでどおり 4 件を出し、下限の文言を出さない

- 前提: 確認用のデータで起動している（この節の冒頭）。
- 操作: `http://127.0.0.1:<ポート>/` を開く。
- 期待する結果: 記事が点数 412、156、88、37 の順に 4 件出る。「以上を表示中」の文言はどこにも出ない。
- 確かめ方: 受け入れ確認
- 対象ファイル: `src/app/page.tsx`、`src/ui/MinScoreNotice.tsx`、`src/services/score-filter.ts`、`src/curation/score-filter.ts`

### V7 下限を指定すると、その点数以上の記事だけを出し、文言を出す

- 前提: 確認用のデータで起動している。
- 操作: (a) `http://127.0.0.1:<ポート>/?min=100` を開く。(b) `http://127.0.0.1:<ポート>/?min=0` を開く。
- 期待する結果: (a) 記事が点数 412、156 の順に 2 件だけ出る（88 と 37 の記事は出ない）。見出し「AI News Today」の下、記事の
  一覧の上に「点数 100 以上を表示中」が出る。(b) 記事が点数 412、156、88、37 の順に 4 件出て、「点数 0 以上を表示中」が出る。
- 確かめ方: 受け入れ確認
- 対象ファイル: `src/app/page.tsx`、`src/ui/MinScoreNotice.tsx`、`src/services/score-filter.ts`、`src/curation/score-filter.ts`

### V8 ちょうど下限の点数の記事を含める

- 前提: 確認用のデータで起動している。
- 操作: `http://127.0.0.1:<ポート>/?min=88` を開く。
- 期待する結果: 記事が点数 412、156、88 の順に 3 件出る（37 の記事は出ない）。「点数 88 以上を表示中」が出る。
- 確かめ方: 受け入れ確認
- 対象ファイル: `src/app/page.tsx`、`src/ui/MinScoreNotice.tsx`、`src/services/score-filter.ts`、`src/curation/score-filter.ts`

### V9 不正な値では絞り込まず、文言も出さない

- 前提: 確認用のデータで起動している。
- 操作: 次の URL を 1 つずつ開く。`/?min=abc`、`/?min=-5`、`/?min=`、`/?min=1.5`、`/?min=100&min=200`。
- 期待する結果: どの URL でも、記事が点数 412、156、88、37 の順に 4 件出る。「以上を表示中」の文言は出ない。画面はエラーにならない
  （HTTP の状態が 200）。
- 確かめ方: 受け入れ確認
- 対象ファイル: `src/app/page.tsx`、`src/ui/MinScoreNotice.tsx`、`src/services/score-filter.ts`、`src/curation/score-filter.ts`

### V10 該当する記事が無いときも文言を出し、選別で落とした記事は出さない

- 前提: 確認用のデータで起動している。確認用のデータには、選別で落ちる点数 999 と 500 の記事がある（999 は公開が古く、500 は
  公開日時が無い。`src/sources/fixture.ts`）。
- 操作: `http://127.0.0.1:<ポート>/?min=450` を開く。
- 期待する結果: 記事は 1 件も出ず、「表示できる記事はまだありません。」と「点数 450 以上を表示中」が出る。点数 999 と 500 の記事
  （題に「表示されない」を含む記事）は出ない（絞り込みは選別の後に掛かる）。
- 確かめ方: 受け入れ確認
- 対象ファイル: `src/app/page.tsx`、`src/ui/MinScoreNotice.tsx`、`src/services/score-filter.ts`、`src/curation/score-filter.ts`

## 手順

順序の依存があるので、上から順に進める（後の手順が、前の手順で作る関数を import する）。

1. **絞り込みの関数を作る**（`src/curation/score-filter.ts` と `src/curation/score-filter.test.ts`）。
   - `filterByMinScore`: `minScore` が `null` なら、渡した配列の写しを返す。そうでなければ `item.score >= minScore` の記事だけを
     `filter` で返す。並べ替えはしない（順は前段の選別が決める）。
   - V3 の試験を書く。
2. **解釈の関数と処理の流れの関数を作る**（`src/services/score-filter.ts` と `src/services/score-filter.test.ts`）。
   - クエリの名前の定数 `MIN_SCORE_QUERY_NAME = "min"` を置く。
   - `parseMinScore`: 値が文字列でない（`undefined` か配列）なら `null`。文字列が正規表現 `/^[0-9]+$/` に一致しなければ `null`。
     一致したら `Number` で数にし、`Number.isSafeInteger` でなければ `null`、そうでなければその数を返す（判断の記録の 2）。
   - `applyMinScore(items: readonly NewsItem[], raw: string | readonly string[] | undefined): { items: NewsItem[]; minScore: number | null }`
     を置く。中身は `parseMinScore` と `filterByMinScore` を呼ぶだけにする（判断の記録の 1）。
   - V1、V2 の試験と、`applyMinScore` の試験（`"100"` で 2 件と `minScore: 100`、不正な値で全件と `minScore: null`）を書く。
3. **表示の部品を作る**（`src/ui/MinScoreNotice.tsx` と `src/ui/MinScoreNotice.test.tsx`）。
   - 文言を組み立てる関数 `minScoreNoticeText(n: number): string`（`` `点数 ${n} 以上を表示中` `` の 1 つの文字列を返す）を置く。
   - `MinScoreNotice({ minScore }: { minScore: number | null })`。`null` なら何も描かない。数なら `<p role="status">` の子に
     `minScoreNoticeText(minScore)` の文字列だけを置いて描く（判断の記録の 5）。判定はしない（受け取った値を出すだけ）。
   - 試験は、`null` で空の文字列、`100` で「点数 100 以上を表示中」、`0` で「点数 0 以上を表示中」を含むことの 3 件を書く。
4. **画面をつなぐ**（`src/app/page.tsx` と `src/app/page.test.tsx`）。
   - `Home` に、省略できる引数 `{ searchParams?: Promise<Record<string, string | string[] | undefined>> }` を足す（引数そのものも
     省略できる形にし、既定は `{}`）。`searchParams` を待ち、無ければ空のオブジェクトとして扱う（判断の記録の 4）。
   - `getTodayNews` の結果を `applyMinScore(items, query[MIN_SCORE_QUERY_NAME])` に渡し、その `items` を `getXPostsByItem` と
     `NewsList` に渡す。`MinScoreNotice` を `<h1>` の後、`NewsList` の前に置く。取得や選別の処理は書かない。
   - `src/app/page.test.tsx` に、V4 の (a)〜(g) の試験を足す。(e) は既存の `renderHome()` で呼び、「以上を表示中」が無いことを確かめる。
     既存の 3 件の試験は変えない。
5. **設計の正本を直す**（`ARCHITECTURE.md`）。「層と責務」の表の処理の流れ（`src/services/`）の行の責務に、
   「画面から整形・選別の関数を使うときの入口と、そのための画面の入力（URL のクエリ）の解釈も兼ねる」の 1 文を足す。表の他の行と、依存の向きの規則は変えない（判断の記録の 6）。
6. **検証する**。V1〜V5 を確かめ、結果を「進捗」に書く。`npm run build` は `.next/` に出力するが、`.next/` は `.gitignore` で除外されて
   いることを `git status --short` で確かめる。`next dev` か `next build` が `AGENTS.md` の `nextjs-agent-rules` の区画を書き戻したら、
   その差分は消さずに残す（`AGENTS.md` の「落とし穴」）。
7. **受け入れ確認を受ける**。実装の担当は、V6〜V10 を自分で確かめた結果を受け入れ確認の記録に書かない。まとめ役が `app-evaluator` を
   起動し、担当が `docs/exec-plans/active/2026-10-08-min-score-filter.acceptance.md` に記録する。不合格の基準があれば直して、その基準を
   確かめ直してもらう。
8. **計画を閉じる**。「結果と振り返り」を書き、この計画と受け入れ確認の記録を同じ変更で `docs/exec-plans/completed/` へ移す。
   `npm run check:docs` が、移した後の計画の受け入れ確認の記録（V6〜V10 の最新の結果が合格であること）を確かめる。

## 範囲外

この計画では扱わない。必要になったら別の計画にする。

- **画面の上で下限を入力する欄やボタン**。合意した範囲は URL のクエリだけである。
- **絞り込みを解除するリンク**と、**不正な値を指定したことを画面で知らせる表示**。不正な値は黙って絞り込まない（判断の記録の 3）。
- **情報源ごとの点数の尺度のそろえ**（Hacker News の点数とはてなブックマークのブックマーク数を同じ下限で比べること）。今の
  `NewsItem` の `score` をそのまま比べる。
- **`getTodayNews`、`TodayNewsDeps`、`selectRecent`、確認用のデータ（`src/sources/fixture.ts`）、組み立ての層の変更**。この機能の
  範囲外なので、形を変えない（判断の記録の 1、V5）。
- **層の表の行の追加と、依存の向きの規則の変更**、ADR の追加。層、依存の向き、不変条件を変えないためである（判断の記録の 6）。

## 進捗

- 2026-10-08: 計画を起票した。手順 1〜8 は未着手。未コミットの変更: この計画のファイル（新規）だけ。
- 2026-10-08: 設計レビューの指摘を反映した（層の分け方、V4・V5・V7・V10 の基準、文言の組み立て、`ARCHITECTURE.md` の 1 文）。
- 2026-10-08: 手順 1〜6 を終えた。変えたファイル: `src/curation/score-filter.ts` と試験、`src/services/score-filter.ts` と試験、
  `src/ui/MinScoreNotice.tsx` と試験（いずれも新規）、`src/app/page.tsx`、`src/app/page.test.tsx`（試験 7 件の追加。既存の 3 件は
  変えていない）、`ARCHITECTURE.md`（処理の流れの層の行に 1 文）。基準ごとの結果:
  - V1〜V4: 合格（`npm run test` の 13 ファイル 103 件がすべて通った）。
  - V5: 合格（分岐元 `git merge-base HEAD origin/main` からの対象のパスの `git diff --stat` と `git status --porcelain=v1
    --untracked-files=all` の出力がどちらも空。`npm run check` と `npm run build` がどちらも終了コード 0）。`.next/` は
    `git status --short` に出ず、`AGENTS.md` の書き戻しも無かった。
  - 実装の担当の自己確認（受け入れ確認の記録には数えない）: 確認用のデータでポート 3100 に起動し、`curl` で V6〜V10 の URL を
    開いて、点数と文言が期待する結果のとおりで、どれも状態 200 であることを見た。確かめた後にサーバーを止め、ポート 3100 に待ち受けが
    残っていないことを確かめた。
  - 残りは手順 7（受け入れ確認）と手順 8（計画を閉じる）。未コミットの変更: 上の変えたファイルとこの計画のファイルのすべて。
- 2026-10-08: 手順 7 を終えた。受け入れ確認の担当（`app-evaluator`）が V6〜V10 を確かめ、記録
  `2026-10-08-min-score-filter.acceptance.md` の実行 1 で、V6〜V10 がすべて合格、全体が合格だった。担当が報告した、実行 1 を
  書いた後の記録の全体のバイト数は 4778、sha256 は `35603db1dc3b62e2fd2c00b2f5bcc58e024ec7ffc36e5893e1d74583cbcf5ea8`
  （`wc -c` と `shasum -a 256` で、実物と一致することを確かめた）。
- 2026-10-08: 実装レビューの指摘を直した。`ARCHITECTURE.md` の処理の流れの層の行を、クエリの解釈も兼ねる文に直した（判断の記録の 6）。
  `src/app/page.test.tsx` の V4 の (e) の試験に、`fetch` が呼ばれないことの確認を足した。受け入れ確認の対象ファイル（`src/app/page.tsx`、
  `src/curation/score-filter.ts`、`src/services/score-filter.ts`、`src/ui/MinScoreNotice.tsx`）は変えていないので、受け入れ確認は
  やり直していない。
- 2026-10-08: 手順 8 を終えた。「結果と振り返り」を書き、この計画と受け入れ確認の記録を `docs/exec-plans/completed/` へ移した。
  残っている手順は無い。

## 発見

1. **Next.js 16 の頁の `searchParams` は Promise である。** `node_modules/next/dist/docs/01-app/03-api-reference/03-file-conventions/page.md`
   の「`searchParams` (optional)」に、型が `Promise<{ [key: string]: string | string[] | undefined }>` で、`await` か `use` で読むこと、
   同じ名前のクエリが複数あると値が配列になること（`string[]`）、`URLSearchParams` ではなく普通のオブジェクトであること、使うと
   要求のたびの描画になること、が書かれている。`src/app/page.tsx` は既に `dynamic = "force-dynamic"` なので、描画の仕方は変わらない。
2. **画面の層は `src/curation/` を import できない**（`ARCHITECTURE.md` の「依存の向き」と `.dependency-cruiser.cjs`）。絞り込みの関数を
   `src/curation/` に置くなら、画面の層からは `src/services/` を経由して呼ぶ必要がある（判断の記録の 1）。
3. **（手順 6 で分かったこと）開発用のサーバーが返す実際の HTML では、`NewsList` の点数も `<small>(<!-- -->412<!-- -->)</small>` の
   形になる。** 既存の `NewsList` が JSX で括弧と数を並べているためで、判断の記録の 5 の理由と同じ現象である。`renderToStaticMarkup`
   を使う試験（V4 と既存の試験）では区切りのコメントは入らないので、試験の正規表現はそのままでよい。受け入れ確認では、点数を
   ブラウザに表示された文字で読む（検証の節の冒頭）。HTML の文字列で点数を探すときは、区切りのコメントを挟んだ形も考える。
4. **（手順 7 で分かったこと）起動の手順（`.claude/skills/run-ai-news-today/SKILL.md`）は、リポジトリの根で実行する形で書かれて
   いるが、受け入れ確認の担当の作業ディレクトリがリポジトリの外のときは、`next` の実行ファイルにプロジェクトのディレクトリを渡す形で
   起動した。** 受け入れ確認の担当の報告による（記録の基準外の所見には書かれていない）。起動の手順の改善は、この計画の範囲外として
   残す。

## 判断の記録

1. **層の分け方: 絞り込みの関数は `src/curation/score-filter.ts`、クエリの名前と解釈の関数と束ねは `src/services/score-filter.ts`、
   表示は `src/ui/MinScoreNotice.tsx`、つなぎは `src/app/page.tsx` に置く。** 理由は次のとおり。
   - 絞り込みは、記事の配列と数だけを扱う純粋な関数なので、整形・選別の層の責務に当たる。画面の層に書くと「画面の層は組み立て
     だけ」に反する。
   - クエリの値（文字列、配列、無し）を下限の値に変えるのは、画面の URL の形を知る処理で、記事の整形・選別ではない。そのため、
     整形・選別の層には置かず、画面から呼ばれる処理の流れの層に、クエリの名前と一緒に置く（設計レビューの指摘）。
   - 画面の層は整形・選別の層を import できない（発見の 2）。依存の向きを変えると `ARCHITECTURE.md`、`.dependency-cruiser.cjs`、
     ADR を直す必要があるので、変えずに処理の流れの層の関数を経由する。この役割を `ARCHITECTURE.md` の処理の流れの層の行に書く
     （判断の記録の 6）。
   - 既存の `getTodayNews`、`TodayNewsDeps`、`selectRecent`、確認用のデータの形は変えない（この機能の範囲外のため）。そのため
     `src/services/today-news.ts` と `src/curation/select.ts` には書かず、新しいファイルに分ける。
   - 絞り込みは `getTodayNews` の後、`getXPostsByItem` の前に掛ける。表示しない記事のために X の oEmbed へ要求しないためと、
     選別で落とした記事が絞り込みで戻らないことを保つためである（V10）。
2. **下限の値は 0 以上の整数だけを受け付け、ASCII の数字だけの文字列（`/^[0-9]+$/`）を正しい値とする。** 点数（Hacker News の点数、
   はてなブックマークのブックマーク数）は 0 以上の整数なので、小数の下限は要らない。`Number()` だけで判定すると、`""`（0 になる）、
   `" 100"`、`"1e2"`、`"0x10"` などを数として通してしまい、「空なら絞り込まない」と食い違うので、先に正規表現で形を決める。
   先頭の 0（`"088"`）は数として 88 に読む。`Number.MAX_SAFE_INTEGER` を超える値は、正確な整数として比べられないので不正とする。
   0 は負でないので正しい値とし、全件を出したうえで「点数 0 以上を表示中」を出す。
3. **不正な値のときは、絞り込まず、画面にも何も出さない（「点数 N 以上を表示中」を出さない）。** 合意した範囲が「不正な値のときは
   絞り込まない」だけで、知らせる表示は求めていないためである。同じ名前のクエリが 2 つ以上ある（値が配列になる）ときも、どちらを
   使うかが決まらないので不正として扱う。
4. **`Home` の引数は省略できる形にする。** Next.js は常に `searchParams` を渡すが、既存の呼び出し（引数なしの `Home()`）を壊さない
   ためである。型は Next.js の文書の形（発見の 1）を明示して書き、`next typegen` が作る大域の型 `PageProps` には頼らない。型の
   出どころを読み手が追えるようにするためである。Next.js が頁の引数の型を検査するので、`npm run build` が通ることを V5 で確かめる。
5. **表示の文言は「点数 N 以上を表示中」とし、N は解釈した後の数（`"088"` なら 88）にする。文言は `minScoreNoticeText` が返す
   1 つの文字列で作り、`p` 要素の子はその文字列だけにする。** JSX で文字列と数を並べて書くと、サーバーで描いた実際の HTML では
   間に区切りのコメント（`<!-- -->`）が入り、HTML の文字列の検索で文言が見つからなくなるためである。`FixtureNotice` と同じく
   `role="status"` の `p` 要素で、見出しの下、記事の一覧の上に置く。0 件のときの「表示できる記事はまだありません。」は `NewsList` の
   既存の文言のまま変えない。文言を変えると `NewsList` の既存の試験と、クエリが無いときの画面も変わるためである。下限の文言が
   同時に出るので、絞り込みで 0 件になったことは読み取れる（V10）。
6. **`ARCHITECTURE.md` は、処理の流れの層の行に「画面から整形・選別の関数を使うときの入口と、そのための画面の入力（URL の
   クエリ）の解釈も兼ねる」の 1 文だけを足す。** クエリの解釈（`parseMinScore`）を処理の流れの層に置いたことを、設計の正本から
   読み取れるようにするためである（実装レビューの指摘で、「入口も兼ねる」から直した）。 層の表の
   行と依存の向きの規則は変えず、外部への通信も足さないので、ADR は書かない。閉じるときに、残す価値のある設計判断が出ていれば、
   そのときに ADR にする。`AGENTS.md` は変えない。
7. **（手順 4 で追加）V4 の試験は、(a)〜(d)、(f)、(g) を `it.each` の 1 つの表にまとめ、(e) は既存の `renderHome()` を使う別の試験に
   した。** 表の各行で、点数の並び、下限の文言の有無、`fetch` が呼ばれないことを同じ形で確かめられるためである。点数を読み取る
   正規表現は、既存の試験と同じものを関数 `scoresOf` にして使った（既存の 3 件の試験の本文は変えていない）。

## 未決の点

[NEEDS CLARIFICATION] の点は無い。

## 結果と振り返り

結果:

- 画面の URL のクエリ `?min=<数>` で点数の下限を指定すると、点数がその数以上の記事だけを出し、見出しの下に「点数 N 以上を表示中」を
  出すようにした。不正な値（数でない、負、空、小数、前後の空白、同じ名前のクエリが 2 つなど）では絞り込まず、文言も出さない。
  ちょうど下限の点数の記事を含め、絞り込みは選別の後に掛かる。
- 層は、絞り込みの関数を `src/curation/score-filter.ts`、クエリの名前と解釈と束ねを `src/services/score-filter.ts`、表示を
  `src/ui/MinScoreNotice.tsx`、つなぎを `src/app/page.tsx` に分けた。依存の向きの規則は変えず、`ARCHITECTURE.md` の処理の流れの層の
  行に、画面の入口とクエリの解釈も兼ねることを足した。`getTodayNews`、`TodayNewsDeps`、`selectRecent`、確認用のデータの形は変えていない。
- 基準 V1〜V5（自動テスト）は合格した（`npm run check` と `npm run build` が終了コード 0）。基準 V6〜V10（受け入れ確認）は、
  受け入れ確認の担当の実行 1 ですべて合格した。
- 新しい ADR は書かない。層、依存の向き、不変条件を変えず、判断は計画の判断の記録で足りるためである（判断の記録の 6）。

振り返り:

- JSX で文字列と数を並べると、サーバーで描いた HTML に区切りのコメントが入る（発見の 3）。画面の文言を HTML の文字列で確かめる
  基準では、文言を 1 つの文字列で組み立てるか、ブラウザに表示された文字で読むと決めておくと、確かめ方の食い違いを防げる。
- 画面の入力の解釈をどの層に置くかは、設計の正本の層の表に書かれていなかった。設計レビューで処理の流れの層に決め、
  実装レビューで設計の正本の文にも反映した。
- 範囲外として残したこと: 起動の手順を、リポジトリの外の作業ディレクトリからも使える形にすること（発見の 4）。
