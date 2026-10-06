# 0003 X の投稿の埋め込みの表示と、外部のスクリプトの信頼の範囲

## 背景

記事の URL と、記事に添えた文章に X の投稿の URL があれば、その投稿を X の公式の埋め込みで記事の下に出すことにした
（`AGENTS.md` の「コードから推測できない決定」）。X の API とログイン情報は使わず、X を自動で収集しない。
X の公式の埋め込みは、X が配信するスクリプト（`widgets.js`）がブラウザで動いて描く。このアプリはそれまで外部の
スクリプトを読み込んでおらず、どこまでを信頼するかを決める必要があった。経緯は
`docs/exec-plans/completed/2026-10-06-x-post-embed.md` にある。

## 判断

- **oEmbed の応答の `html` を画面に入れない。** oEmbed（`https://publish.x.com/oembed`。認証は要らない）は、投稿が存在して
  公開されていることの確認と、投稿者の名前（`author_name`）の取得にだけ使う。画面の `blockquote class="twitter-tweet"` は、
  正規の形の URL から React の要素で組み立てる。外から受け取った HTML を `dangerouslySetInnerHTML` で入れると、応答の
  中身しだいで任意のスクリプトが画面で動きうるためである。要求には `url` だけを付ける。`omit_script`、`dnt`、`lang` は
  応答の `html` だけを変える引数で、`html` を使わないので効き目が無い。
- **ブラウザが `https://platform.twitter.com/widgets.js` を読み込むことを許す。** 許すのはこの 1 つ（それが自分で読み込む
  X のリソースを含む）だけとし、不変条件 5 として `ARCHITECTURE.md` に書き、ESLint の 2 つの規則（`next/script` の import を
  `src/ui/XPostEmbed.tsx` の外で拒否、JSX の `script` 要素と、`require()` と `import()` での `next/script` の読み込みを `src/` の下で
  拒否）で検査する。受け入れることは次の 2 つである。
  - `widgets.js` は、このアプリと同じ origin で制限なしに動き、画面の DOM と同じ origin の入口を呼べる。今は状態を変える
    入口が無いので受け入れる。入口を作るときの注意を `ARCHITECTURE.md` の「将来の作りの注意」に書いた。
  - ブラウザは X へ、X の Cookie と Referer を送る。本人だけが手元で見るアプリで、Referer から分かるのは手元で起動した
    事実だけなので受け入れる。`blockquote` には `data-dnt="true"` を付け、X に個人に合わせたおすすめや広告に使わないよう
    求める（X の文書が約束するのはこの範囲だけで、送信そのものは止まらない）。
- **`widgets.js` が動かないときの代替の表示は、投稿者の名前と、正規の形の URL への「X で見る」のリンクとする。** `html` を
  使わないので、このとき投稿の本文は出ない。外の HTML を入れないこととの引き換えとして受け入れる。
- **oEmbed への 1 回の要求に 5000 ミリ秒の時間切れを付ける。** 画面は埋め込みの情報を待ってから描くので、時間切れが無いと
  1 件の応答が返らないだけで画面全体が止まるためである。`src/ports/http.ts` の `withTimeout` で包み、X の埋め込みの依存
  （`src/composition/runtime.ts` の `createXPostDeps`）にだけ使う。件数は 1 記事あたり 3 件、画面全体で 10 件に抑える。
- 使う URL は、2026-10-06 の確認で転送されずに本体を返す側にした（oEmbed は `publish.x.com`、`widgets.js` は
  `platform.twitter.com`。`publish.twitter.com` は `publish.x.com` へ、`platform.x.com` は `platform.twitter.com` へ転送される）。

## 検討した代わりの案

- oEmbed の `html` をそのまま画面に入れる: 投稿の本文が `widgets.js` なしでも出るが、入力の検証をこちらで保証できないので
  採らない。
- X の埋め込みを別の origin の `iframe` に閉じ込める: `widgets.js` が同じ origin で動かなくなるが、手元に別の origin を
  用意する仕組みが要るので今回は採らない。状態を変える入口を作るときに改めて検討する。
- `<meta name="referrer" content="no-referrer">` などで Referer を抑える: 上のとおり、送られて分かるのが手元の起動の事実
  だけなので今回は入れない。
- 頁全体の `<meta name="twitter:dnt" content="on">`: 埋め込みの無い頁にも書くことになり、部品の中で閉じないので使わず、
  `blockquote` ごとの `data-dnt` にした。

## 結果

- 外部のスクリプトを足すには、不変条件 5 と ESLint の規則と、この ADR を同じ変更で直す必要がある。
- ESLint は、`next/script` を静的な import、`require()`、`import()` で読み込む形と、JSX の `script` 要素を拒否する。
  書いた形だけを見るので、`React.createElement("script", ...)`、`document.createElement("script")` のような DOM の操作、
  モジュールの名前を変数で組み立てた `import()` など、別の書き方で読み込む形は止められない。この形はレビューで人が確かめる。
- 画面を開くたびに、最大 10 回 oEmbed へ要求する（応答は保存しない）。時間切れの後も元の要求は裏で続く。
- X が oEmbed や `widgets.js` の URL の転送の向きを変えたときは、`src/sources/x-oembed.ts` と `src/ui/XPostEmbed.tsx` の
  URL を見直す。
