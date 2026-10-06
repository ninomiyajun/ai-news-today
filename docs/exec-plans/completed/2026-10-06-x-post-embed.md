# X の投稿を、記事に添えて埋め込みで表示する

## 目的

今日のニュースの各記事について、記事の URL と、情報源が記事に添えて渡す文章の中に X（旧 Twitter）の投稿の URL が
含まれていれば、その投稿を X の公式の埋め込みの表示で、記事の下に出す。記事の話題について X で何が言われているかを、
X を開かずに画面の中で見られるようにするためである。

利用者が決めた方針（会話で合意済み）:

- X の API と X のログイン情報は使わない。X を自動で収集しない（`AGENTS.md` の「コードから推測できない決定」）。
- 投稿の存在と公開の可否は、X の oEmbed の入口（`https://publish.twitter.com/oembed`）に問い合わせて確かめる。
- 将来は Hacker News とはてなブックマークに出てくる X の URL を拾う想定だが、この計画の時点でこの 2 つの情報源は
  未実装で、`src/composition/runtime.ts` の情報源は空の配列である。そのため、情報源に依存しない形にする。
  つまり「`NewsItem` の URL か、`NewsItem` に添えた文章に X の投稿の URL があれば表示する」処理だけを作る。
- 秘匿値は扱わない。環境変数も足さない。

**仮定（手順 1 で確かめるまで事実として扱わない）**: oEmbed の入口は、認証も鍵も要らずに使える。手順 1 で公式の文書と
実際の応答を確かめ、この仮定が成り立たないと分かったら、手順 2 以降に進まず、計画の担当（まとめ役）へ返す。
手順 1 を終えることが、実装を始める条件である。

前提として読む文書:

- 製品の仕様: 無い（このプロジェクトに仕様の文書はまだ無い）。完了の条件は、この計画の「検証（完了の条件）」に直接書く。
- `ARCHITECTURE.md` の「層と責務」（`src/sources/` の責務に「X の oEmbed」が既に書かれている）、「依存の向き」、
  「不変条件」の 1（外部への通信は `src/ports/` からだけ）、「将来の作りの注意」（外から来る URL は `http:` と `https:` だけを通す）。
- ADR: `docs/adr/0001-layers-and-checks.md`（層の構成と依存の向き）。X の表示についての ADR はまだ無い（手順 9 で 0003 を書く）。

この計画で使う用語:

- **投稿の URL**: `https://x.com/<利用者名>/status/<数字の id>` の形の URL。ホストが `twitter.com` などの別名の形も含む
  （手順 3 で一覧にする）。利用者名が `i` の形（`x.com/i/status/<id>`、`x.com/i/web/status/<id>`）は今回は対象にしない
  （判断の記録の 5）。
- **正規の形**: 投稿の URL を、`https:`、ホスト `x.com`、道を `/<利用者名>/status/<id>` だけにし、クエリと断片を落とした形
  （例: `https://x.com/example_user/status/1234567890123456789`）。`/status/<id>` の後ろの道（`/photo/1` など）も落とす。
- **添えた文章**: 情報源が一覧の取得のときに記事と一緒に渡す短い文章（Hacker News の投稿の本文、はてなブックマークの
  RSS の説明文など）。**HTML の実体参照を解いた平文**とし、HTML から平文にするのは情報源の責務とする（判断の記録の 7）。
  記事を開いたときに取得する本文（`AGENTS.md`。未実装）とは別のもので、この計画では本文を扱わない。
- **埋め込みの情報**: oEmbed の応答から取り出して画面に渡す値。正規の形の URL（`postUrl`）と投稿者の名前（`authorName`）の 2 つだけ。
- **代替の表示**: X のスクリプト（`widgets.js`）が動かないときにも出る表示。投稿者の名前と、正規の形の URL への
  「X で見る」の文言のリンクからなる（判断の記録の 6）。

## 検証（完了の条件）

各基準の確かめ方の「自動テスト」は、`npm run test`（vitest）で通ることを指す。試験は `fixtureHttpClient` か、試験の中で
作る `HttpClient` だけを使い、本物の X へ通信しない。

1. **URL の抜き出し（基本の形）**
   - 前提: `src/curation/x-post-url.ts` に、文字列から投稿の URL を抜き出す純粋な関数がある（以下「抜き出しの関数」）。
   - 操作: 次の文字列を渡す。
     `見て https://twitter.com/example_user/status/1234567890123456789?s=20 と https://x.com/Other_1/status/42#m`
   - 期待する結果: `["https://x.com/example_user/status/1234567890123456789", "https://x.com/Other_1/status/42"]` を、出てきた順で返す。
   - 確かめ方: 自動テスト。
2. **URL の抜き出し（別名のホスト、続きのある URL、対象外の形）**
   - 前提: 基準 1 と同じ。
   - 操作と期待する結果（入力 → 出力）:
     - (a) `https://mobile.twitter.com/a/status/1` → `["https://x.com/a/status/1"]`
     - (b) `https://www.x.com/a/status/2` → `["https://x.com/a/status/2"]`
     - (c) `https://mobile.x.com/a/status/3` → `["https://x.com/a/status/3"]`
     - (d) `http://twitter.com/a/status/4` → `["https://x.com/a/status/4"]`
     - (e) `見てhttps://x.com/a/status/5です`（日本語に続けて書いた URL）→ `["https://x.com/a/status/5"]`
     - (f) `https://x.com/a/status/6/photo/1` → `["https://x.com/a/status/6"]`
     - (g) `https://x.com/a`（投稿でない利用者のページ）→ `[]`
     - (h) `https://x.com/i/status/7` → `[]`
     - (i) `https://x.com/i/web/status/8` → `[]`
     - (j) `https://example.com/x.com/a/status/9`（別のホストの道の中に現れる形）→ `[]`
     - (k) `javascript:alert(1)//x.com/a/status/10` → `[]`
     - (l) `https://x.com/a/status/12abc`（id が数字だけでない）→ `[]`
   - 確かめ方: 自動テスト。
3. **1 記事の中の重複の除去と、1 記事あたりの上限**
   - 前提: 抜き出しの関数を使って、`NewsItem` の URL と添えた文章から投稿の URL を得る関数がある（以下「記事ごとの関数」）。
     1 記事あたりの上限は 3 件（判断の記録の 4）。
   - 操作: 記事の URL に `https://twitter.com/a/status/1` を、添えた文章に `https://x.com/a/status/1 https://x.com/b/status/2
     https://x.com/c/status/3 https://x.com/d/status/4` を持つ `NewsItem` を渡す。
   - 期待する結果: `["https://x.com/a/status/1", "https://x.com/b/status/2", "https://x.com/c/status/3"]`
     （記事の URL を先に見る。同じ正規の形は 1 回だけ数える）。
   - 確かめ方: 自動テスト。
4. **oEmbed の取得（成功と、要求の URL）**
   - 前提: `src/sources/x-oembed.ts` に、`HttpClient` と正規の形の URL を受け取り、埋め込みの情報か `null` を返す関数がある
     （以下「oEmbed の関数」）。`fixtureHttpClient` に、手順 1 で決めた要求の URL への応答として、状態 200 と、`type` が `"rich"`、
     `author_name` が `"A"`、`html` が文字列の JSON を登録する。要求の URL の例（手順 1 の結果で `omit_script`、`dnt`、`lang` の
     有無と値を決め、決めた形をこの基準と試験に書く）。手順 1 の結果、要求の URL は次の形に決めた（判断の記録の 3、11、12）:
     `https://publish.x.com/oembed?url=https%3A%2F%2Fx.com%2Fa%2Fstatus%2F1`
   - 操作: oEmbed の関数に `https://x.com/a/status/1` を渡す。
   - 期待する結果: `{ postUrl: "https://x.com/a/status/1", authorName: "A" }` を返す。要求した URL が、手順 1 で決めた形と
     1 文字も違わない（違えば `fixtureHttpClient` が 404 を返して結果が `null` になり、試験が落ちる）。したがって `lang` などの
     引数の採否も、この試験で確かめられる。
   - 確かめ方: 自動テスト。
5. **oEmbed の取得（失敗と異常な応答は、表示しないだけにする）**
   - 前提: 基準 4 と同じ関数。
   - 操作: 応答を次のそれぞれにする。(a) 状態 404（投稿の削除）、(b) 状態 403（非公開の投稿者）、(c) 状態 200 で本文が
     JSON でない文字列、(d) 状態 200 で `type` が `"video"`（`"rich"` でない）、(e) 状態 200 で `type` が無い、
     (f) 状態 200 で `author_name` が数値の `1`、(g) 状態 200 で `author_name` が無い、(h) 状態 200 で `author_name` が空の文字列、
     (i) `HttpClient` の `get` が例外を投げる。
   - 期待する結果: どれも例外を投げず `null` を返す。
   - 確かめ方: 自動テスト。
6. **記事の一覧と埋め込みの情報の束ね（複数の記事、重複、全体の上限）**
   - 前提: `src/services/x-posts.ts` に、`NewsItem` の配列と `{ http: HttpClient }` を受け取り、記事の id から埋め込みの情報の
     配列への対応を返す関数がある（以下「束ねの関数」）。上限は、取得する一意の正規の形の URL の数で数え、1 記事あたり 3 件、
     全体で 10 件（判断の記録の 4、8）。試験では、`get` の呼び出しの回数と、渡された URL を記録する `HttpClient` を使う。
   - 操作と期待する結果:
     - (a) X の URL を含まない記事 1 件 → その記事の配列は空。`get` は呼ばれない。
     - (b) 成功する投稿 1 件と 404 の投稿 1 件を含む記事 1 件 → その記事の配列は成功した 1 件だけ。例外は出ない。
     - (c) 記事 P と記事 Q の両方に `https://x.com/a/status/1` がある → oEmbed への要求は 1 回だけで、P と Q の両方の配列に
       同じ埋め込みの情報が入る。
     - (d) 合計で 12 件の異なる投稿の URL を、記事 4 件（各 3 件）に含む → `get` の呼び出しは 10 回で、記事の順、記事の中では
       出てきた順の先頭 10 件の URL だけを要求する。4 件目の記事の配列は、先頭の 1 件だけになる。
     - (e) 記事 P に 3 件、記事 Q に P と同じ 3 件を含む → 要求は 3 回で、全体の上限の数え方でも 3 件と数える。
   - 確かめ方: 自動テスト。
7. **時間切れ**
   - 前提: `src/ports/http.ts` に、`HttpClient` を包んで時間切れを付ける関数（以下「時間切れの関数」。例:
     `withTimeout(client, timeoutMs)`）がある。X の埋め込みで使う時間は 5000 ミリ秒（判断の記録の 9）。
   - 操作: (a) `get` が解決しない `HttpClient` を時間切れの関数で 5000 ミリ秒の設定で包み、`get` を呼んで vitest の偽のタイマーで
     5000 ミリ秒進める。(b) 同じ包んだ `HttpClient` を、投稿の URL を 1 件含む記事 1 件とともに束ねの関数へ渡し、偽のタイマーで
     5000 ミリ秒進める。(c) 4999 ミリ秒で応答を返す `HttpClient` を包んで呼ぶ。
   - 期待する結果: (a) `get` が時間切れの例外で失敗する。(b) 束ねの関数が例外を出さずに解決し、その記事の配列は空になる。
     (c) 応答がそのまま返る。
   - 確かめ方: 自動テスト（`src/ports/http.test.ts` と `src/services/x-posts.test.ts`）。
8. **既存の形を変えていない**
   - 前提: 実装の後。
   - 操作: `git -C <worktree の絶対パス> diff origin/main -- src/services/today-news.ts src/services/today-news.test.ts` を実行する。
     `npm run typecheck` と `npm run test` を走らせる。
   - 期待する結果: 差分が空。型の検査と試験が通る。`NewsItem` に足す `text` は省略できる形（`?` 付き）で、既存の試験の記事の値
     （`text` を書かない書き方）が型の検査を通る。
   - 確かめ方: コマンドの結果。
9. **表示の部品の出力**
   - 前提: `NewsList` が、記事の id から埋め込みの情報の配列への対応を、省略できる引数として受け取る。
   - 操作: `react-dom/server` の `renderToStaticMarkup` で、次の 2 つを文字列にする。記事は
     `{ id: "1", title: "t", url: "https://example.com/1", source: "hacker-news", score: 3, publishedAt: <任意の日時> }`。
     (a) 埋め込みの情報を渡さない。(b) 記事 `"1"` に `{ postUrl: "https://x.com/a/status/1", authorName: "A" }` を渡す。
   - 期待する結果:
     - (a) 変更前の `NewsList` の出力と同じ文字列。比べる相手として、**手順 7 で `NewsList` を変える前に**、同じ入力での
       出力を試験の期待値の固定の文字列として書く（見込みは
       `<ul><li><a href="https://example.com/1" target="_blank" rel="noopener noreferrer">t</a> <small>(3)</small></li></ul>`。
       実際の出力がこれと違ったら、実際の出力を期待値にして「発見」に書く）。
     - (b) `class="twitter-tweet"` を持つ `blockquote` を含み、その中に文字列 `A` と、
       `<a href="https://x.com/a/status/1" target="_blank" rel="noopener noreferrer">X で見る</a>` を含む（代替の表示）。
       手順 1 の結果で `data-dnt` を付けると決めた場合は、`blockquote` に `data-dnt="true"` を含む。
   - 確かめ方: 自動テスト（`src/ui/NewsList.test.tsx`。vitest の環境は `node` のままで足りる）。
10. **外部のスクリプトの読み込みの条件**
    - 前提: `src/ui/XPostEmbed.tsx` に、読み込む外部のスクリプトの URL の定数（以下「スクリプトの定数」。例: `WIDGETS_JS_URL`）を
      1 か所だけ置き、`next/script` の `Script` の `src` にはこの定数だけを渡す。試験では `vi.mock("next/script")` で `Script` を、
      受け取った引数を記録する部品に差し替える。
    - 操作: 埋め込みの情報が (a) 0 件、(b) 1 件、(c) 3 件（記事 2 件に分かれる）の `NewsList` を描く。
    - 期待する結果: (a) `Script` は描かれない。(b) と (c) は `Script` が 1 回だけ描かれ、`src` がスクリプトの定数と等しく、
      スクリプトの定数が `"https://platform.twitter.com/widgets.js"` と等しい。
    - 確かめ方: 自動テスト。
11. **外部のスクリプトを他の場所から読み込めない（不変条件 5 の検査）**
    - 前提: `eslint.config.mjs` に次の 2 つの規則がある（手順 8）。(1) `next/script` の import を、`src/ui/XPostEmbed.tsx` の外で
      拒否する。(2) `src/` の下で JSX の `script` 要素（小文字の `<script>`）を拒否する。
    - 操作: 一時的に、`src/ui/NewsList.tsx` に `import Script from "next/script";` を足して `npm run lint` を走らせる。次に、
      一時的に `src/app/page.tsx` に `<script src="https://example.com/a.js" />` を足して `npm run lint` を走らせる。
      確かめた後、2 つの一時的な変更を戻す。
    - 期待する結果: どちらも `npm run lint` が失敗し、メッセージが不変条件 5 を指す。戻した後は通る。
    - 確かめ方: 人がコマンドの結果を確かめ、「進捗」に書く。
12. **外から受け取った HTML を画面に入れない**
    - 前提: 実装の後。
    - 操作: `grep -rn "dangerouslySetInnerHTML\|innerHTML" <worktree の絶対パス>/src` を実行する。
    - 期待する結果: 出力が空（oEmbed の応答の `html` を画面に入れない。判断の記録の 2）。
    - 確かめ方: 人がコマンドの結果を確かめる。
13. **画面での表示（人が確認）**
    - 前提: `npm run dev` で起動している。情報源は空なので、確認のときだけ `src/composition/runtime.ts` の情報源に、URL が公開の
      X の投稿の URL である記事を 1 件持つ `staticSource` を一時的に入れる（公開日時は確認の時刻の 1 時間前）。投稿の URL は、
      利用者が確認のときに指定する。その URL は、計画を含むコミットする文書に書かない。一時的な変更はコミットせず、確認の後に戻す。
    - 操作:
      - (a) Chrome で `http://127.0.0.1:3000` を開く。
      - (b) DevTools を開き（macOS では Command + Option + I）、Network タブの右上の「︙」から「More tools」の「Network request blocking」を
        開き、「Enable network request blocking」にチェックを入れ、「+」で `platform.twitter.com` を足す。ページを再読み込みする。
    - 期待する結果: (a) 記事の下に、X の埋め込みの表示（投稿の本文、投稿者、日時を持つカード）が出る。(b) 記事の下に、投稿者の
      名前と「X で見る」のリンク（代替の表示）が出る。リンクを押すと、新しいタブで投稿の頁が開く。画面の他の部分は壊れない。
    - 確かめ方: 人が確認し、(a) と (b) の画面写しを PR の説明に貼る（投稿の URL が写る箇所は写さない）。
    - 結果: 2026-10-06 に利用者が確認し、(a) と (b) の両方を確かめた（「進捗」を参照）。
14. **検査がすべて通る**
    - 前提: 実装の後。
    - 操作: `npm run check` を走らせる。
    - 期待する結果: 終了コード 0（lint、型、試験、文書、層の向き、秘匿値のすべて）。
    - 確かめ方: コマンドの結果。

## 手順

順序の依存があるので、上から順に進める。

1. **公式の文書と実際の応答で、前提を確かめる（実装を始める条件）**。確かめた結果と、読んだ文書の URL を「発見」に書く。
   - X の開発者向けの文書の oEmbed の頁で、次を確かめる: 認証や鍵が要らないこと（目的の節の仮定）、引数 `url`、`omit_script`、
     `dnt`、`lang` の意味、応答の項目（`type`、`author_name`、`html` など）、`x.com` の形の URL を受け付けること。
   - 公開の投稿 1 件（利用者が指定する。文書には書かない）について、ブラウザで oEmbed の要求の URL を開き、実際の応答を見る。
   - `widgets.js`（`https://platform.twitter.com/widgets.js`）が `class="twitter-tweet"` の `blockquote` を埋め込みの表示へ置き換える
     こと、`blockquote` の `data-dnt` 属性の意味、`widgets.js` がほかにどのホストから読み込むかを確かめる。
   - 決めたことを「判断の記録」に書く: oEmbed の要求に `omit_script`、`dnt`、`lang` を付けるか（付けるなら値）、`blockquote` に
     `data-dnt="true"` を付けるか。決めた要求の URL の形で、基準 4 の例を直す。
   - 認証が要る、または `x.com` の形を受け付けないなど、仮定と違うと分かったら、手順 2 以降に進まず、まとめ役へ返す。
   - `npm ci` の後、`node_modules/next/dist/docs/` の中の `Script`（`next/script`）の文書を読み、Next.js 16 で外部のスクリプトを
     読み込む書き方と、サーバーのコンポーネントから使えるかを確かめる（`AGENTS.md` の「落とし穴」）。
2. **型を足す**（`src/domain/news.ts`）。
   - `NewsItem` に、添えた文章を表す省略できる項目 `text?: string` を足す。型のコメントに「HTML の実体参照を解いた平文。HTML から
     平文にするのは情報源の責務」と書く。
   - 埋め込みの情報の型 `XPostEmbed = { postUrl: string; authorName: string }` を足す。
3. **抜き出しの関数と記事ごとの関数を作る**（`src/curation/x-post-url.ts` と試験）。
   - 候補の切り出し: 文字列の中から、`http://` か `https://` で始まり、ASCII の URL に使える文字（英数字と `-._~:/?#[]@!$&'()*+,;=%`）が
     続く範囲を、正規表現で拾う。日本語などの ASCII でない文字と空白で範囲が終わる。
   - 候補ごとに `URL` のクラスで解析し、次をすべて満たすものだけを通す: `protocol` が `http:` か `https:`。ホストが `x.com`、`www.x.com`、
     `mobile.x.com`、`twitter.com`、`www.twitter.com`、`mobile.twitter.com` のどれか。道の 1 つ目が利用者名（英数字と下線の 1〜15 文字で、
     大文字と小文字を区別せず `i` でない）、2 つ目が `status`、3 つ目が数字だけの id。通ったものを正規の形にする。
   - 記事ごとの関数: 記事の URL、添えた文章の順に抜き出し、同じ正規の形を 1 回だけ数え、先頭の 3 件を返す。
   - 基準 1〜3 の試験を書く。
4. **時間切れの関数を作る**（`src/ports/http.ts` と `src/ports/http.test.ts`）。
   - `withTimeout(client: HttpClient, timeoutMs: number): HttpClient` を足す。`get` の Promise と、`timeoutMs` の後に例外で失敗する
     Promise のうち、先に決まったほうを返す。待ちが終わったらタイマーを解除する。`fetchHttpClient` は変えない。
   - 基準 7 の (a) と (c) の試験を書く。
5. **oEmbed の関数を作る**（`src/sources/x-oembed.ts` と試験）。
   - `HttpClient` を引数で受け取り、手順 1 で決めた要求の URL に `get` する。状態が 200 でない、JSON として読めない、`type` が `"rich"` で
     ない、`author_name` が空でない文字列でない、のどれかなら `null` を返す。`get` の例外（時間切れを含む）も捕まえて `null` を返す。
     応答の `html` は使わない（判断の記録の 2）。
   - 基準 4、5 の試験を書く。
6. **束ねの関数を作る**（`src/services/x-posts.ts` と試験）。
   - 記事の順に記事ごとの関数で URL を得る。一意の正規の形の URL を、記事の順、記事の中では出てきた順に並べ、先頭の 10 件だけを
     取得の対象にする。取得の対象の URL ごとに oEmbed の関数を 1 回だけ呼び（並べて呼ぶ）、結果を、その URL を含む各記事へ対応付ける。
     `null` の結果は対応付けない。`getTodayNews` と `TodayNewsDeps` は変えない。
   - 基準 6 と基準 7 の (b) の試験を書く。
7. **表示の部品を直す**（`src/ui/NewsList.tsx`、新しい部品 `src/ui/XPostEmbed.tsx`、試験 `src/ui/NewsList.test.tsx`）。
   - 先に、変更前の `NewsList` の出力を基準 9 の (a) の期待値として試験に書き、通ることを確かめる。
   - 埋め込みの情報ごとに、`<blockquote className="twitter-tweet">` の中に投稿者の名前と、正規の形の URL への「X で見る」のリンク
     （`target="_blank"`、`rel="noopener noreferrer"`）を出す（代替の表示）。手順 1 で決めた場合は `data-dnt="true"` を付ける。
     React の要素で組み立て、HTML の文字列は使わない。
   - `src/ui/XPostEmbed.tsx` にスクリプトの定数を置き、`next/script` の `Script` で読み込む（書き方と `strategy` は手順 1 で読んだ
     Next.js 16 の文書に従う）。埋め込みの情報が 1 件も無いときは描かない。1 件以上あるときは 1 回だけ描く。
   - 基準 9、10 の試験を書く。
8. **検査の規則を足す**（`eslint.config.mjs`）。
   - `no-restricted-imports` で、`next/script` の import を `src/ui/XPostEmbed.tsx` の外で拒否する。`no-restricted-syntax` で、`src/` の下の
     JSX の `script` 要素を拒否する。メッセージに不変条件 5 を書く。基準 11 を確かめる。
9. **組み立てと画面をつなぎ、文書を直す**。
   - `src/composition/runtime.ts`: 束ねの関数に渡す依存を返す関数 `createXPostDeps()` を足す。中身は
     `{ http: withTimeout(fetchHttpClient, 5000) }`。既存の `createRuntimeDeps` は変えない。
   - `src/app/page.tsx`: `getTodayNews` の結果を束ねの関数に渡し、結果を `NewsList` に渡す。取得や選別の処理は書かない。
   - `ARCHITECTURE.md`: 「不変条件」に 5 を新しく立てる。内容は、ブラウザに読み込ませる外部のスクリプトは
     `https://platform.twitter.com/widgets.js` だけ（それが自分で読み込む X のリソースを含む）、URL は `src/ui/XPostEmbed.tsx` の
     定数 1 か所に置く、ESLint の 2 つの規則（手順 8）で検査する、の 3 点。不変条件 1 の文面は変えない。「将来の作りの注意」に、
     X の URL の正規の形、oEmbed の `html` を画面に入れないこと、同じ origin で第三者のスクリプト（`widgets.js`）が動くので、状態を
     変える入口（ブックマークレットの登録、翻訳の実行など）を作るときはそれを前提に設計すること、を足す。
   - `AGENTS.md`: 「このアプリ」の「X の投稿の表示は未実装」を、実装した範囲（ブックマークレットは未実装）に合わせて直す。
   - `docs/adr/0003-x-post-embed.md` を書き、`docs/adr/README.md` の目録に行を足す。内容は判断の記録の 2、3、6、9（不変条件を
     変える判断なので、この変更の中で書く）。
10. **検証する**。基準 1〜14 を確かめ、結果を「進捗」に書く。
11. **計画を閉じる**。「結果と振り返り」を書き、手順 9 で書いた ADR を作業の結果に合わせて直してから、この計画を
    `docs/exec-plans/completed/` へ移す。

## 範囲外

この計画では扱わない。必要になったら別の計画にする。

- **利用者がブックマークレットで X の URL を登録する仕組み**。登録を受け付ける入口（手元のサーバーへの書き込みの経路）と、
  登録した URL を保存する場所と形式を新たに決める必要があり、どちらも未決である。また、書き込みの入口は、他のサイトから
  勝手に登録される問題と、同じ origin で動く `widgets.js` から呼ばれる問題（判断の記録の 3）への対策を設計に含める必要がある。
  今回は「記事に含まれる URL を表示する」処理だけで完結するため、分けて扱う。`AGENTS.md` の方針（ブックマークレットで登録した
  URL も表示する）は変えない。
- **Hacker News とはてなブックマークの情報源の実装**と、情報源が `text` を埋める処理（HTML を平文にする処理を含む）。
- **記事を開いたときに取得する本文**の中の X の URL（本文の取得が未実装のため）。
- **利用者名を含まない投稿の URL**（`x.com/i/status/<id>`、`x.com/i/web/status/<id>`）。判断の記録の 5。
- **oEmbed の応答の保存（キャッシュ）**。画面を開くたびに最大 10 回 oEmbed へ要求するが、本人だけが手元で見るので、今は保存しない。
- **`fetchHttpClient` そのものへの時間切れの追加**。今回は X の埋め込みの依存だけを包む（判断の記録の 9）。

## 進捗

- 2026-10-06: 計画を起票した。設計レビュー（2 段）の結果を反映した。手順 1〜11 は未着手。
- 2026-10-06: 手順 1 を終えた。仮定（認証が要らない、`x.com` の形を受け付ける）は成り立った（発見の 1〜3）。
  決めたことは判断の記録の 3、11、12 に追記した。残りは手順 2〜11。
- 2026-10-06: 手順 2〜6 を終えた（`src/domain/news.ts`、`src/curation/x-post-url.ts`、`src/ports/http.ts`、`src/sources/x-oembed.ts`、
  `src/services/x-posts.ts` と、それぞれの試験）。`npm run test` は 39 件すべて通った。残りは手順 7〜11。
- 2026-10-06: 手順 7 を終えた。`NewsList` を変える前に基準 9 の (a) の試験を書き、見込みの文字列のとおりの出力で通ることを
  確かめてから、`src/ui/XPostEmbed.tsx` を足して `NewsList` を直した。`npm run test` は 45 件すべて通った。
- 2026-10-06: 手順 8 を終えた。基準 11 を確かめた: `src/ui/NewsList.tsx` に `import Script from "next/script";` を一時的に足すと
  `npm run lint` が終了コード 1 で失敗し、`no-restricted-imports` が「外部のスクリプトは src/ui/XPostEmbed.tsx の WIDGETS_JS_URL から
  だけ読み込んでください（ARCHITECTURE.md の不変条件 5）」と出した。`src/app/page.tsx` に `<script src="https://example.com/a.js" />` を
  一時的に足すと、`no-restricted-syntax` が同じ不変条件 5 を指すメッセージで失敗した（Next.js の `@next/next/no-sync-scripts` も
  失敗を出した）。2 つの一時的な変更を戻し、`git status` で両ファイルに一時的な変更が残っていないこと、`npm run lint` が終了コード 0
  で通ることを確かめた。残りは手順 9〜11。
- 2026-10-06: 手順 9 を終えた（`src/composition/runtime.ts` に `createXPostDeps`、`src/app/page.tsx` のつなぎ、`ARCHITECTURE.md` の
  不変条件 5 と「将来の作りの注意」、`AGENTS.md` の「このアプリ」、`docs/adr/0003-x-post-embed.md` と目録の行）。
- 2026-10-06: 手順 10 を終えた。基準ごとの結果:
  - 基準 1〜7、9、10: 合格（`npm run test` の 7 ファイル 45 件がすべて通った。基準 7 は `src/ports/http.test.ts` と
    `src/services/x-posts.test.ts`）。
  - 基準 8: 合格（`git diff origin/main -- src/services/today-news.ts src/services/today-news.test.ts` の出力が空。
    `npm run typecheck` と `npm run test` が通った）。
  - 基準 11: 合格（上の手順 8 の行のとおり。一時的な変更は戻した）。
  - 基準 12: 合格（`grep -rn "dangerouslySetInnerHTML\|innerHTML" <worktree>/src` の出力が空で、終了コード 1）。
  - 基準 13: 合格（2026-10-06 に利用者が確認した。下の行を参照）。
  - 基準 14: 合格（`npm run check` が終了コード 0。lint、型、試験、文書、層の向き、秘匿値のすべてが通った）。
  - 基準の外の確認: `npm run build` が終了コード 0 で通った（`Script` を `"use client"` の無い部品から使って組み立てられる）。
- 2026-10-06: 手順 11 は、基準 13 が残るので、「結果と振り返り」を書いたうえで計画を `docs/exec-plans/active/` に置いたままにした。
  残りは、基準 13 の人による確認と、その結果を「進捗」と「結果と振り返り」に追記して、計画を `docs/exec-plans/completed/` へ
  移すこと。
- 2026-10-06: 実装レビューの指摘 2 件を直した。(1) ESLint で `require("next/script")` と `import("next/script")` も拒否するようにした
  （判断の記録の 15 の追記）。`src/ui/NewsList.tsx` に一時的に `require("next/script")` と `import("next/script")` を足すと、
  `npm run lint` が終了コード 1 で、2 か所とも不変条件 5 を指すメッセージで失敗した。`src/ports/clock.ts` に一時的に
  `import("next/script")` を足しても同じく失敗した。どれも戻し、`grep` で一時的な変更が残っていないことを確かめた。
  (2) 同じ投稿の判定を投稿の id にした（発見の 7、判断の記録の 8 の追記）。`npm run check` は終了コード 0 で通った（試験は 47 件）。
- 2026-10-06: 第二レビューの指摘で、空白だけの `author_name` を `null` にした（判断の記録の 16）。`npm run check` は終了コード 0
  （試験は 49 件）。
- 2026-10-06: 基準 13 を利用者が確認し、合格した。(a) 記事の下に X の埋め込みのカードが出た。(b) `platform.twitter.com` を遮断すると、
  投稿者の名前と「X で見る」のリンク（代替の表示）が出た。確認に使った投稿の URL はこの文書に書かない（判断の記録の 10）。
  確認用の `src/composition/runtime.ts` の一時的な書き換えは戻し、`git diff origin/main -- src/composition/runtime.ts` に
  `createXPostDeps` の追加だけが残ることを確かめた。
- 2026-10-06: 手順 11 を終えた。計画を `docs/exec-plans/completed/` へ移した。残っている手順は無い。

## 発見

1. **oEmbed の入口の正式な URL は `https://publish.x.com/oembed` で、認証は要らない。** X の開発者向けの文書
   （`https://docs.x.com/x-for-websites/oembed-api`。旧 URL の `https://developer.x.com/en/docs/x-for-websites/oembed-api` は
   文書の目次へ転送される）の Embedded Tweets の節に、Resource URL が `https://publish.x.com/oembed`、「Requires authentication? No」、
   「Rate limited No」とある。計画が書いていた `https://publish.twitter.com/oembed` は、2026-10-06 の確認で、クエリを保ったまま
   `https://publish.x.com/oembed` へ状態 301 で転送された。
2. **`x.com` の形の投稿の URL を受け付ける。** 文書の例（Embedded Posts の概要の頁 `https://docs.x.com/x-for-websites/embedded-posts/overview`
   と oEmbed の頁の例の投稿の URL）を `x.com`、`twitter.com`、`mobile.twitter.com` の形で `https://publish.x.com/oembed` に渡すと、
   どれも状態 200 で、`type` が `"rich"`、`url` が `https://x.com/...` の形、`author_name` が空でない文字列の JSON が返った。
   応答の項目は `url`、`author_name`、`author_url`、`html`、`width`、`height`、`type`、`cache_age`、`provider_name`、`provider_url`、
   `version`。存在しない id（`/status/1`）は状態 404 だった。`x.com/i/status/<id>` の形も状態 200 を返したが、対象外のまま
   とする（判断の記録の 5）。
3. **引数の意味（oEmbed の頁の表）。** `omit_script`: `true` のとき、応答の `html` に `widgets.js` を読み込む `<script>` を含めない。
   `dnt`: `true` のとき、投稿と埋め込んだ頁を個人に合わせたおすすめや広告に使わない。`lang`: 応答の `html` と描かれた投稿の文言の
   言語（既定は `en`）。実際の応答でも、3 つとも `html` の中身だけを変え（`dnt=true` で `blockquote` に `data-dnt="true"` が付き、
   `lang=ja` で日付が日本語になる）、`url` と `author_name` は変わらなかった。
4. **`widgets.js` の動き。** Embedded Posts の概要の頁に「widget JavaScript は実行のときに DOM を走査し、`blockquote.twitter-tweet` の
   要素を描いた埋め込みの投稿へ変える」とあり、後から足した要素は `twttr.widgets.load()` を呼ばないと変わらない。埋め込みの投稿の
   引数の頁（`https://docs.x.com/x-for-websites/embedded-posts/guides/embedded-tweet-parameter-reference`）に、`blockquote` の
   `data-dnt` 属性（`true` で、個人に合わせたおすすめや広告に使わない）がある。頁全体で止める `<meta name="twitter:dnt" content="on">`
   もある（`https://docs.x.com/x-for-websites/webpage-properties`）。
5. **`widgets.js` の置き場。** 文書の読み込みの例は `https://platform.x.com/widgets.js` だが、2026-10-06 の確認では、この URL は
   状態 302 で `https://platform.twitter.com/widgets.js` へ転送され、本体は `https://platform.twitter.com/widgets.js`（状態 200）にある。
   本体の中に現れる X のホストは `platform.twitter.com`、`syndication.twitter.com`、`cdn.syndication.twimg.com`、`publish.twitter.com`
   だった（文字列の検索による。`localhost.twitter.com` は開発用の値）。埋め込みの表示は `platform.twitter.com` の `iframe` の中で
   描かれ、`iframe` の中の読み込み先は確かめていない。
6. **Next.js 16 の `next/script`**（`node_modules/next/dist/docs/01-app/02-guides/scripts.md` と
   `01-app/03-api-reference/02-components/script.md`）。`Script` は `"use client"` の無い頁や部品でも、`src` と `strategy` だけなら
   使える（文書の例が頁の部品で使っている）。`onLoad` などの関数を渡すときだけ、クライアントの部品にする必要がある。`strategy` の
   既定は `afterInteractive`（水和の後に読み込む）。同じスクリプトは 1 回だけ読み込まれる。
7. **（実装レビューの指摘で分かったこと）X の利用者名は大文字と小文字を区別しないので、`x.com/Foo/status/1` と
   `twitter.com/foo/status/1` は同じ投稿を指す。** 計画の正規の形は利用者名の書き方をそのまま残すので、正規の形の文字列が
   同じでも、同じ投稿かどうかの判定には使えない。投稿の id は投稿ごとに一意なので、重複の判定は id で行う（判断の記録の 8 の追記）。

## 判断の記録

1. **`getTodayNews` と `TodayNewsDeps` の形を変えず、埋め込みは別の関数で束ねる。** 既存の呼び出し元（`src/app/page.tsx`）と
   試験（`src/services/today-news.test.ts`）を変えずに足せる形にするためである。同じ理由で、`NewsItem` に足す項目は省略できる形にする。
2. **oEmbed の応答の `html` を画面に入れず、正規の形の URL から `blockquote` を React の要素で組み立てる。** 外から受け取った HTML を
   `dangerouslySetInnerHTML` で入れると、応答の中身しだいで任意のスクリプトが手元の画面で動きうるためである。oEmbed は、投稿が
   存在して公開されていることの確認と、投稿者の名前の取得に使う。表示は `widgets.js` が `blockquote` を置き換えて行う。
   代わりの案（`html` をそのまま入れる）は、入力の検証をこちらで保証できないので採らない。
3. **ブラウザが `https://platform.twitter.com/widgets.js` を読み込むことを許し、その信頼の範囲を明記する。** X の公式の埋め込みの表示は、
   このスクリプトが行うためである。次の 3 点を受け入れる。
   - `widgets.js` は、このアプリと同じ origin（`http://127.0.0.1:3000`）で制限なしに動く。画面の DOM と、同じ origin の入口を
     呼べる。判断の記録の 2 で外の HTML を入れないのとは別に、X が配信するスクリプトそのものは信頼することになる。今は状態を
     変える入口が無いので受け入れる。将来その入口を作るときの注意を `ARCHITECTURE.md` に書く（手順 9）。
   - ブラウザは X へ、X の Cookie と、Referer（`http://127.0.0.1:3000/`）を送る。X にログインしている本人がいつこの画面を開いたかが
     X に伝わる。本人だけが手元で見るアプリで、Referer から分かるのは手元の起動の事実だけなので受け入れ、
     `<meta name="referrer" content="no-referrer">` などで Referer を抑える設定は今回は入れない。
   - 代わりの案（X の埋め込みを別の origin の `iframe` に閉じ込める）は、手元に別の origin を用意する仕組みが要るので今回は採らない。
     状態を変える入口を作るときに改めて検討する。
   - この許可は、不変条件 1（サーバーのコードの通信を試験で差し替えるための条件）の例外ではなく、別の関心事（ブラウザに読み込ませる
     外部のスクリプトの信頼の範囲）として、新しい不変条件 5 にし、ESLint で検査する（手順 8、9）。
   - oEmbed の `dnt` と `blockquote` の `data-dnt` が追跡の抑止にどう効くかは、手順 1 の確認の結果を得るまで未確認である。付けるか
     どうかは手順 1 の結果で決め、この節に追記する。
   - （手順 1 の後の追記）**oEmbed の要求には `dnt` を付けず、`blockquote` に `data-dnt="true"` を付ける。** oEmbed の `dnt` は、応答の
     `html` の `blockquote` に `data-dnt="true"` を付けるだけで（発見の 3）、`html` は使わない（判断の記録の 2）ので効かない。追跡を
     抑える効き目があるのは、ブラウザで `widgets.js` が読む `blockquote` の `data-dnt` のほうである（発見の 4）。ただし文書が約束するのは
     「個人に合わせたおすすめや広告に使わない」ことだけで、X へ Cookie や Referer が送られること自体は変わらない（上の 2 つ目の点）。
     頁全体の `<meta name="twitter:dnt">` は、埋め込みの無い頁にも効く書き方になり、部品の中で閉じないので使わない。
4. **件数の上限は 1 記事あたり 3 件、画面全体で 10 件とする。** 画面を開くたびに oEmbed へ要求するので、要求の回数を抑えるためである。
   待ち時間の上限は件数では抑えられないので、判断の記録の 9 の時間切れで抑える。数は仮置きで、使ってみて直す。
5. **利用者名を含まない投稿の URL（`x.com/i/status/<id>`、`x.com/i/web/status/<id>`）は、今回は対象にしない。** 情報源がまだ無く、
   oEmbed がこの形を受け付けるかも確かめていないためである。利用者名の規則で `i` を明示的に除き、基準 2 の (h) と (i) で確かめる。
   対象にするときは別の計画にする。
6. **`widgets.js` が動かないときは、投稿者の名前と「X で見る」のリンクを、必ず出す代替の表示とする。** 判断の記録の 2 で `html` を
   使わないので、このとき投稿の本文は出ない。外から受け取った HTML を画面に入れないこととの引き換えとして受け入れる。代替の表示は
   基準 9 で自動で、基準 13 の (b) で人が確かめる。
7. **添えた文章（`text`）は、HTML の実体参照を解いた平文とし、HTML から平文にするのは情報源の責務とする。** HTML のままだと、
   `/` が `&#x2F;` に置き換わった形などで、投稿の URL を抜き出せないためである。整形・選別の層は平文だけを扱う。
8. **同じ投稿が複数の記事に出るときは、同じ正規の形の URL を 1 回だけ取得し、その URL を含む各記事へ対応付ける。** 上限は、取得する
   一意の URL の数で数える。同じ投稿へ重ねて要求しないためと、上限を要求の回数の上限として働かせるためである。基準 6 の (c)、(e) で確かめる。
   - （実装レビューの後の追記）**同じ投稿かどうかは、正規の形の URL の文字列ではなく投稿の id で判定し、最初に出てきた URL を残す。**
     1 記事の中（基準 3 の重複の除去）と、記事をまたぐ束ね（上の対応付けと全体の上限の数え方）の両方に当てはめる。発見の 7 のとおり、
     利用者名の大文字と小文字だけが違う URL は同じ投稿を指すが、文字列で比べると別の投稿として 2 回要求し、上限も 2 件分使うためである。
     試験は `src/curation/x-post-url.test.ts` と `src/services/x-posts.test.ts` に 1 件ずつ足した。
9. **X の埋め込みの取得に、1 回の要求あたり 5000 ミリ秒の時間切れを付ける。** `src/app/page.tsx` は束ねの関数を待ってから画面を描く
   ので、時間切れが無いと、oEmbed の応答が 1 件返らないだけで画面全体の表示が止まるためである。要求は並べて行うので、画面の表示が
   oEmbed のために待つのは、おおむね 5 秒までになる。実装は `src/ports/http.ts` の `withTimeout` で `HttpClient` を包む形にし、
   `src/composition/runtime.ts` の `createXPostDeps` だけで使う。`fetchHttpClient` は変えないので、他の情報源には影響しない。
   時間切れの後も元の要求は中断されず裏で続くが、要求は最大 10 件なので受け入れる。試験は vitest の偽のタイマーで行う（基準 7）。
10. **画面の確認に使う実在の投稿の URL は、利用者が確認のときに指定し、コミットする文書には書かない。** 公開リポジトリに特定の
    投稿を残さないためと、計画の担当が実在の投稿を推測で選ばないためである。
11. **oEmbed の要求に `lang` を付けるかは、手順 1 の調査の後に決め、この節に追記する。** 決めた要求の URL の形は、基準 4 の試験で
    1 文字単位で確かめる。
    - （手順 1 の後の追記）**`lang` も `omit_script` も付けず、要求は `url` だけにする。** 3 つの引数はどれも応答の `html` だけを
      変え、使う項目（`type`、`author_name`）を変えない（発見の 3）。`html` は使わないので、付けても効き目が無い。要求の URL は
      `https://publish.x.com/oembed?url=` に、正規の形の URL を `encodeURIComponent` で符号化して続けた形とする（基準 4）。
12. **（手順 1 の後に追加）oEmbed の入口は `https://publish.x.com/oembed`、`widgets.js` は `https://platform.twitter.com/widgets.js` を
    使う。** どちらも、2026-10-06 の確認で転送されずに本体を返す側の URL である（発見の 1、5）。転送を挟むと、通るホストが 1 つ
    増え、不変条件 5 で信頼するホストの説明も増えるためである。利用者が合意した方針の「`https://publish.twitter.com/oembed` に
    問い合わせる」は、同じ入口の転送前の URL で、問い合わせ先の実体は変わらない。文書の例の `https://platform.x.com/widgets.js` は
    転送で `platform.twitter.com` に行き着くので、基準 10 の定数は計画のとおり `https://platform.twitter.com/widgets.js` とする。
    X がこの転送の向きを変えたときは、この 2 つの URL を見直す。
    （2026-10-06 の追記）問い合わせ先を `publish.x.com` にしたことは、利用者が承認した（「publish.x.com のままにする」）。
13. **（手順 3 で追加）URL の候補の末尾の句読点と閉じ括弧（`.,;:!?)]'*`）を落としてから解析する。また、`HTTPS://` のような
    大文字の書き方も候補として拾う。** 文の中で `(https://x.com/a/status/1)` や `https://x.com/a/status/1.` と書かれると、`1)` や
    `1.` が数字だけの id にならず、投稿を見落とすためである。落とすのは末尾だけなので、基準 2 の (l)（`12abc`）は従来どおり
    対象外になる。どちらも計画の候補の切り出しの規則を広げるだけで、基準 1〜3 の結果は変わらない（試験を足して確かめた）。
14. **（手順 7 で追加）表示の部品は、`src/ui/XPostEmbed.tsx` に `XPostCard`（1 件の `blockquote`）と `XWidgetsScript`（`Script` を
    `strategy="afterInteractive"` で描く）を置き、`NewsList` が埋め込みの 1 件以上あるときだけ `XWidgetsScript` を `ul` の後に 1 回描く。**
    部品の名前を `XPostEmbed` にしないのは、`src/domain/news.ts` の型 `XPostEmbed` と同じ名前になり、読み違えるためである。
    `strategy` は Next.js 16 の文書の既定（`afterInteractive`）を明示した。水和の後に読み込むので、`widgets.js` が DOM を走査する
    ときには `blockquote` が揃っている（発見の 4、6）。代替の表示は `<span>投稿者の名前</span>` と「X で見る」のリンクにした。
15. **（手順 8 で追加）ESLint の規則は、既存の `src/` の区画（`src/ports/` を除く）に `next/script` の import と JSX の `script` 要素の拒否を
    足し、`src/ui/XPostEmbed.tsx` の区画で `no-restricted-imports` を通信のモジュールだけに置き直し、`src/ports/` の区画にも
    不変条件 5 の 2 つを足す形にした。** ESLint の flat config では、同じ規則の設定は後の区画が前の区画を置き換えるので、別の区画に
    同じ規則名を足すと既存の不変条件 1、2 の設定が消えるためである。
    （実装レビューの後の追記）静的な import に加えて、`require("next/script")` と `import("next/script")` も `no-restricted-syntax` で
    拒否するようにした（`src/` の区画と `src/ports/` の区画）。`src/ui/XPostEmbed.tsx` は静的な import だけを使うので、この 2 つが
    そのファイルで効いても支障は無い。`React.createElement("script")` や DOM の操作で読み込む形は、まだ ESLint では止められない
    （`docs/adr/0003-x-post-embed.md` の「結果」と `ARCHITECTURE.md` の不変条件 5 に書いた）。
16. **（第二レビューの後に追加）`author_name` は前後の空白を落とした長さが 0 なら `null` とし、返す値も前後の空白を落とす。** 空白だけの名前は代替の表示で投稿者を示せず、前後の空白は表示に意味が無いためである。

## 未決の点

[NEEDS CLARIFICATION] の点は無い。手順 1 の結果を待って決める点だった、判断の記録の 3（`dnt` と `data-dnt`）と 11（`lang`）、
および基準 4 の要求の URL の形は、手順 1 の後に決めた（判断の記録の 3、11、12 の追記）。

## 結果と振り返り

結果:

- 記事の URL と、記事に添えた文章（`NewsItem` の `text`）に含まれる X の投稿の URL を正規の形にそろえ、oEmbed
  （`https://publish.x.com/oembed`）で存在と公開を確かめ、記事の下に `blockquote class="twitter-tweet"` を React の要素で出す
  処理を作った。`widgets.js` が動けば X の埋め込みの表示に、動かなければ投稿者の名前と「X で見る」のリンクになる。
- 外部のスクリプトの信頼の範囲を不変条件 5 として `ARCHITECTURE.md` に書き、ESLint で検査するようにした。判断の理由は
  `docs/adr/0003-x-post-embed.md` に残した。
- 基準 1〜14 はすべて合格した。基準 13 は利用者が画面で確かめ、埋め込みのカードと、`widgets.js` を遮断したときの代替の表示の
  両方が出た。情報源はまだ空なので、実際の画面に埋め込みが出るのは、情報源を実装した後か、基準 13 のように一時的な情報源を
  入れたときだけである。
- oEmbed の問い合わせ先を、計画の `publish.twitter.com` から `publish.x.com` に変えたことは、利用者が承認した（判断の記録の 12）。

振り返り:

- 計画の時点で書いていた `publish.twitter.com` は、手順 1 の確認で `publish.x.com` への転送になっていた。外部の URL は、
  計画を書くときにも実際の応答で確かめておくと、手順 1 での書き直しが減る。
- ESLint の flat config で同じ規則を別の区画に足すと、前の区画の設定が置き換わって消える。既存の不変条件の検査を
  弱めないため、規則を足すときは同じ区画にまとめる（判断の記録の 15）。
- 計画に無かった判断は、URL の候補の末尾の句読点の扱い（判断の記録の 13）、部品の名前と置き場（14）、ESLint の区画の
  分け方（15）の 3 つで、どれも計画の方針の範囲に収まった。
