# 検査の由来の記録

レビューなどの指摘から作った検査について、どの指摘から作り、文書のどの記述を置き換えたかを書き留める記録。検査を
直すときや外すときに、その検査がある理由を確かめられるようにするためである。

## 使い方

- 指摘を検査にした変更で、下の表に 1 行足す。検査、試験、置き換えた文書の記述の直しと同じ変更に含める。
- この記録を始める前からある検査の由来は、さかのぼって書かない。
- 検査を外す変更では、その行の「外した変更」の列を埋め、置き換えた文書の記述を元に戻す。行は消さない。外した理由を
  残して、同じ指摘が、もう一度検査の候補に挙がったときに確かめられるようにするためである。
- 出どころが 2 件に満たない候補（同じ種類の指摘が、別々の変更で 2 回出る、という目安に満たない候補）を、利用者が
  承知で選んだときは、ある分の出どころと、目安に満たないが利用者が選んだことを、「元の指摘の出どころ」の列に書く。

表の列は次のとおり。

- 検査: 実行するコマンド（`AGENTS.md` の「検査のコマンド」のもの）と、規則の名前。
- 元の指摘の出どころ: その検査の元になった指摘のある場所。計画のファイル名（ディレクトリを付けない）と節か、PR の番号で
  書く。計画は、閉じると置き場が変わるためである。2 件以上を書く（目安に満たない候補を、利用者が承知で選んだときは、
  上の「使い方」のとおりに書く）。
- 置き換えた文書の記述: 検査に変えたことで、人が確かめる決まりから機械が確かめる決まりに書き直した文書の場所。
  検査が検出できない書き方が残るときは、文書に残した記述の場所も書く。
- 入れた変更: その検査を入れた PR の番号。
- 外した変更: その検査を外した PR の番号と、外した理由。検査がいまもあるときは、空にする。

## 記録

| 検査 | 元の指摘の出どころ | 置き換えた文書の記述 | 入れた変更 | 外した変更 |
|---|---|---|---|---|
| `npm run test:harness` の `scripts/harness/lint-rules.test.mjs`（ESLint の規則が、区画ごとに働くことの試験。対象は `no-restricted-globals`、`no-restricted-properties`、`no-restricted-imports`、`no-restricted-syntax`） | PR #12 の計画 `2026-10-06-x-post-embed.md` の「進捗」（手順 8 と、実装レビューの指摘 2 件を直した行。人が一時的な違反を足して確かめた記録）と「結果と振り返り」（同じ規則を別の区画に足すと、前の区画の設定が置き換わって消えること）。出どころは 1 つの変更だけで、目安（別々の変更で 2 回）に満たないが、利用者が承知で選んだ | 置き換えた記述は無い（人が一時的な違反で確かめる、という決まりは、文書に無かった）。残した記述: `ARCHITECTURE.md` の不変条件 2 と 5、`docs/adr/0003-x-post-embed.md` の、別名を経由した書き方などは ESLint では止められず、レビューで人が確かめる、という記述（この試験でも守れないため）。ほかに試験が守れない形（並べ直しで見本に無い項目だけを落とす誤り、拡張子を足したときの見本の足し忘れ、全体の ignores や無効化のコメントで規則を外す形）は、試験の冒頭の注釈に書いた | `feat/promoted-checks` | |
| `npm run lint` の `no-restricted-syntax`（`eslint.config.mjs` の `htmlSyntax`。JSX の属性 `dangerouslySetInnerHTML` と `srcDoc`、オブジェクトに書いた `dangerouslySetInnerHTML` と `srcDoc` という名前のプロパティ、`innerHTML`、`outerHTML`、`srcdoc` への代入、`insertAdjacentHTML`、`setHTMLUnsafe`、`createContextualFragment`、`document.write`、`document.writeln` の呼び出しを、`src/` の下のすべてで拒否する）。試験は `npm run test:harness` の `scripts/harness/lint-rules.test.mjs` | PR #12 の設計の時の決定（レビューの指摘ではない）: `ARCHITECTURE.md` の「将来の作りの注意」の oEmbed の応答の `html` の項、`docs/adr/0003-x-post-embed.md` の「判断」、計画 `2026-10-06-x-post-embed.md` の「検証（完了の条件）」の 12（`grep` による人の確認）。出どころは 1 つの変更だけで、目安（別々の変更で 2 回）に満たないが、利用者が承知で選んだ | `ARCHITECTURE.md` の「将来の作りの注意」の oEmbed の応答の `html` の項（括弧書きの「`dangerouslySetInnerHTML` を使わない」を、ESLint が拒否する書き方の一覧に書き換えた）。残した記述: 同じ項の、`{...props}` の展開、名前を変数で組み立てたプロパティ、別名を経由した書き方、`Object.assign` などでの書き込み、`DOMParser` や `Document.parseHTMLUnsafe` などの別の入口は止められず、レビューで人が確かめる、という記述 | `feat/promoted-checks` | |
| `npm run lint` の `no-restricted-globals`、`no-restricted-properties`、`no-restricted-imports`、`no-restricted-syntax`（`eslint.config.mjs` の通常の区画の対象に、`templates/` の下の ts、tsx、js、jsx、mjs、cjs、mts、cts を足した。`src/` の下の通常の区画と同じ規則がかかる）。試験は `npm run test:harness` の `scripts/harness/lint-rules.test.mjs`（`templates/` の区画の見本と、失敗する見本 12、13） | PR #27 のレビューの指摘（計画 `2026-10-13-harness-maintenance-base.md` で見つけ、`docs/exec-plans/tech-debt-tracker.md` に TD-1 として記録した。この変更で行を消した）。出どころは 1 つの変更だけで、目安（別々の変更で 2 回）に満たないが、利用者が承知で選んだ | `ARCHITECTURE.md` の「層と責務」の `templates/` の段落（ひな形にかかる ESLint の規則を足した）、不変条件 1 と 5 と「将来の作りの注意」の HTML の項の対象（`src/` の下 → `src/` と `templates/` の下）、`templates/module/README.md` の「守る決まり」。残した記述: ひな形を `templates/` の外に置く形は規則の対象外である、という `ARCHITECTURE.md` の同じ段落の記述と、試験の冒頭の注釈 | `feat/promoted-checks` | |
| `npm run check:arch` の `templates-not-to-src` と `src-not-to-templates`（`.dependency-cruiser.cjs`。`templates/` と `src/` の間の依存を、どちらの向きも拒否する。`scripts/harness/check-arch.sh` の対象に `templates` を足した）。試験は `npm run test:harness` の `scripts/harness/check-arch.test.sh` | `templates/` から `src/` への向き: PR #27 のレビューの指摘（計画 `2026-10-13-harness-maintenance-base.md` で見つけ、`docs/exec-plans/tech-debt-tracker.md` に TD-2 として記録した。この変更で行を消した）。`src/` から `templates/` への向き: `ARCHITECTURE.md` の「層と責務」の決まり（出どころは調べていない）。出どころは 1 つの変更だけで、目安（別々の変更で 2 回）に満たないが、利用者が承知で選んだ | `ARCHITECTURE.md` の「層と責務」の `templates/` の段落と、`templates/module/README.md` の「守る決まり」（文書に書いただけの決まりを、`npm run check:arch` が確かめる記述に書き換えた）。残した記述: 同じ 2 か所の、モジュールの名前を変数で組み立てた `import()` や `require()` と、`vi.mock("@/...")` などの引数の文字列で書いたパスは検出できず、レビューで人が確かめる、という記述と、`ARCHITECTURE.md` の同じ段落の、ひな形を `templates/` の外に置くと検査がかからない、という記述 | `feat/promoted-checks` | |
