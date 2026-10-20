# ARCHITECTURE

このプロジェクトの現在の設計の正本。層、依存の向き、各層の責務、不変条件を書く。
過去の判断の理由は `docs/adr/` に置く。P1（土台）の時点の仮置きで、機能を作りながら直す。

## 層と責務

コードはすべて `src/` の下に置き、直下のディレクトリを層とする。

| 層 | パス | 責務 |
|---|---|---|
| 画面 | `src/app/` | Next.js の画面とルート。組み立てだけを行い、取得や選別の処理を書かない |
| 表示の部品 | `src/ui/` | 受け取った値を表示する部品。取得も選別もしない |
| 組み立て | `src/composition/` | 実行時の依存（本物の時計、情報源）を選んで束ねる。本物の実装を選ぶのはこの層だけ。確認用のデータを使うかの判定と選択もこの層で行い、データは持たない |
| 処理の流れ | `src/services/` | 取得と整形・選別を束ねる。依存は引数で受け取る。画面から整形・選別の関数を使うときの入口と、そのための画面の入力（URL のクエリ）の解釈も兼ねる |
| 取得 | `src/sources/` | 情報源（Hacker News、はてなブックマーク、X の oEmbed）から取得し、`src/domain/` の型にそろえる。確認用のデータ（決まった記事、基準の時刻、X の oEmbed の決まった応答）は `src/sources/fixture.ts` の 1 ファイルに置く |
| 整形・選別 | `src/curation/` | 純粋な関数だけ。取得も現在時刻の取得もしない（時刻は引数で受け取る） |
| 外部と時刻の入口 | `src/ports/` | 外部への HTTP（`src/ports/http.ts`）と現在時刻（`src/ports/clock.ts`）の型、本物の実装、試験用の決まった実装 |
| 型 | `src/domain/` | 記事などの型。他の層を import しない |

`templates/` は層ではない。新しいモジュールを足すときに写す、ひな形の置き場（`templates/module/`）で、アプリのコードからは
import しない。ひな形は `src/` の何も import せず、それだけで型の検査が通る形に保つ。`src/` の中身が変わっても、ひな形が
壊れないためである。`npm run check:arch` が、`templates/` から `src/` への依存と、`src/` から `templates/` への依存を、
どちらも失敗にする（`.dependency-cruiser.cjs` の `templates-not-to-src` と `src-not-to-templates`。別名 `@/...` で書いた
import と、型だけの import も検出する）。モジュールの名前を変数で組み立てた `import()` や `require()` と、`vi.mock("@/...")`、
`vi.importActual("@/...")` のように引数の文字列で書いたパスは検出できないので、レビューで人が確かめる。ひな形を
`templates/` の外に置くと、この検査も下の ESLint の規則もかからないので、ひな形は `templates/` の下に置く。
ひな形には、`src/` の下の通常の層と同じ ESLint の規則（下の不変条件 1、2、5 と、「将来の作りの
注意」の HTML の項）がかかる。

### 確認用のデータ

環境変数 `AI_NEWS_FIXTURE=sample` を付け、かつ `NODE_ENV` が `production` でない起動（`next dev` など）では、
`src/composition/runtime.ts` が、本物の情報源と時計と HTTP の入口の代わりに、`src/sources/fixture.ts` の決まった記事と
基準の時刻（`fixedClock`）と決まった応答（`fixtureHttpClient`）を選ぶ。外部へは通信しない。画面の層はこの判定を
受け取り、`src/ui/FixtureNotice.tsx` で画面の上に「確認用のデータで表示中」を出す。受け入れ確認でコードを書き換えずに
画面を確かめるための仕組みで、理由は `docs/adr/0004-fixture-data-for-acceptance.md`。

## 依存の向き

各層が import してよい層（自分自身を含む）。この表にない向きの import は、`npm run check:arch`
（dependency-cruiser。規則は `.dependency-cruiser.cjs`）が失敗にし、CI も落ちる。

| 層 | import してよい層 |
|---|---|
| `src/app/` | app、composition、services、ui、domain |
| `src/ui/` | ui、domain |
| `src/composition/` | composition、services、sources、ports、domain |
| `src/services/` | services、sources、curation、ports、domain |
| `src/sources/` | sources、ports、domain |
| `src/curation/` | curation、domain |
| `src/ports/` | ports、domain |
| `src/domain/` | domain |

加えて、循環した依存と、`src/` の直下の上の表に無いディレクトリ・ファイルも失敗にする（後者は何も import しない
ファイルでも、`scripts/harness/check-arch.sh` が一覧を照合して検出する）。型だけの import も依存に数える。

## 不変条件

`npm run check:docs` は、下の 1 の「通信のための大域の名前（」から「。」までの名前と、2 の「通信のためのモジュール（」の
括弧書きの名前（「と、それぞれに `node:` を付けた名前、」の前の名前を `node:` 付きと無しに展開し、後の名前をそのまま足す）を
読み取って、`eslint.config.mjs` の名前の一覧と照合する。この言い回しと、バッククォートで囲んだ名前を「、」で区切る形を
変えるときは、`scripts/harness/check-docs.sh` の検査 13 も直す。

1. 外部への通信と現在時刻は、`src/ports/` からだけ得る。ほかの層は `HttpClient` と `Clock` を引数で受け取る。
   試験のときに、決まったデータ（`fixtureHttpClient`、`staticSource`）と決まった時刻（`fixedClock`）へ差し替えるため
   である。ESLint が、`src/ports/` の外での通信のための大域の名前（`fetch`、`WebSocket`、`XMLHttpRequest`、
   `EventSource`。`globalThis.`、`window.`、`self.` を付けた形を含む）と、`Date.now()`、`Date()`、引数の無い `new Date()`、
   `Temporal.Now` を拒否する（`eslint.config.mjs`。対象は `src/` と `templates/` の下の ts、tsx、js、jsx、mjs、cjs、mts、cts）。
   `performance.now()` と `new Date(undefined)` は現在時刻を返さないので対象にしない。
2. 通信のためのモジュール（`http`、`https`、`http2`、`net`、`tls`、`dgram` と、それぞれに `node:` を付けた名前、`undici`）は、
   `src/ports/` の外で import しない。層の向きの規則（上の表）とは別の不変条件で、`fetch` を禁じても、これらを使えば
   外部へ通信できてしまうためである。ESLint が、`import`、`require()`、`import()` のいずれも拒否する（`eslint.config.mjs`）。
   ESLint は書いた名前の形だけを見るので、1 と 2 のどちらでも、別名を経由した書き方（`const g = globalThis; g.fetch(...)`、
   `const T = Temporal; T.Now`、モジュールの名前を変数で組み立てた `import()` など）は止められない。この形はレビューで
   人が確かめる。
3. 秘匿値は、ブラウザへ渡るコードに置かない。`NEXT_PUBLIC_` で始まる環境変数に鍵を置かない（`AGENTS.md`）。
4. 取得した記事の本文と翻訳は、リポジトリに置かない（`AGENTS.md`）。保存する場所を決めたら、同じ変更で
   `.gitignore` に入れる。
5. ブラウザに読み込ませる外部のスクリプトは、X の埋め込みのスクリプト `https://platform.twitter.com/widgets.js` だけとする
   （それが自分で読み込む X のリソースを含む）。この URL は `src/ui/XPostEmbed.tsx` の定数 `WIDGETS_JS_URL` の 1 か所にだけ置く。
   ESLint が、`next/script` の import を `src/ui/XPostEmbed.tsx` の外で拒否し、JSX の `script` 要素と、`require()` と `import()` での
   `next/script` の読み込みを `src/` と `templates/` の下のすべてで拒否する（`eslint.config.mjs`）。`React.createElement("script")` や DOM の操作など、
   別の書き方で読み込む形は ESLint では止められないので、レビューで人が確かめる。1 とは別の関心事（ブラウザに読み込ませる外部のスクリプトの信頼の範囲）で、理由は
   `docs/adr/0003-x-post-embed.md`。

## 将来の作りの注意（記事の取得を実装するとき）

まだ実装していない。`src/sources/` に情報源を足すときに守る。

- 外部から来る記事の URL は、`http:` と `https:` だけを通し、それ以外（`javascript:`、`data:` など）は記事ごと落とす。
  URL は画面のリンク（`src/ui/NewsList.tsx` の `href`）にそのまま入るためである。
- 記事の id には情報源の名前を含める（例: `hn:12345`、`hatena:...`）。情報源が違うと id が重なりうるうえ、
  id を画面の要素の key に使っているためである。
- X の投稿の URL は、`src/curation/x-post-url.ts` で正規の形（`https://x.com/<利用者名>/status/<id>`。クエリ、断片、
  `/status/<id>` の後ろの道を落とす）にそろえてから扱う。記事に添える文章（`NewsItem` の `text`）は、HTML の実体参照を
  解いた平文で渡す（HTML から平文にするのは情報源の責務）。
- X の oEmbed の応答の `html` は、画面に入れない。外から受け取った HTML を入れると、
  応答の中身しだいで任意のスクリプトが画面で動きうるためである。埋め込みは、正規の形の URL から React の要素で組み立てる。
  ESLint が、HTML の文字列を画面に入れる書き方を `src/` と `templates/` の下のすべてで拒否する（`eslint.config.mjs`）。対象は、JSX の属性
  `dangerouslySetInnerHTML` と `srcDoc`、オブジェクトに書いた `dangerouslySetInnerHTML` と `srcDoc` という名前のプロパティ、
  `innerHTML`、`outerHTML`、`srcdoc` への代入、`insertAdjacentHTML`、`setHTMLUnsafe`、`createContextualFragment`、
  `document.write`、`document.writeln` の呼び出し（名前を文字列で書いた `el["innerHTML"]` の形と、`window.`、`globalThis.`、
  `self.` を付けた `document` を含む）である。書いた名前の形だけを見るので、`{...props}` の展開で渡す形、名前を変数で
  組み立てたプロパティ（`el[key] = ...`）、別名を経由した書き方（`const d = document; d.write(...)`）、`Object.assign` などで
  プロパティを書き込む形、`DOMParser`、`Document.parseHTMLUnsafe` など別の入口は止められない。この形はレビューで人が確かめる。
- `widgets.js`（不変条件 5）は、このアプリと同じ origin で制限なしに動き、画面の DOM と同じ origin の入口を呼べる。
  状態を変える入口（ブックマークレットの登録、翻訳の実行など）を作るときは、このスクリプトから呼ばれうることを前提に設計する。

## 中核的な原則

- 層の向きを変えるときは、この文書、`.dependency-cruiser.cjs`、ADR を同じ変更で直す。
