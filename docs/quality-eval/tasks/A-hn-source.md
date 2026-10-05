# 課題 A

この文面は、一度決めたら変えない（`docs/quality-eval/README.md`）。

## 依頼文

<!-- 依頼文の始まり -->
```text
Hacker News の記事を、今日のニュースに出せるようにしてください。
- Algolia の HN Search API（https://hn.algolia.com/api/v1/ の search_by_date）から新しい記事を取得します。
- 取得の処理は `src/sources/hacker-news.ts` に置き、`createHackerNewsSource(http: HttpClient, options?)` の名前と形で公開してください。戻り値は `NewsSource` です。第 2 引数は任意で、中身は自由に決めてかまいません。
- 点数は points、公開日時は created_at を使ってください。
- 画面には AI に関する記事だけを出します。判定の規則は任せます。たとえば「OpenAI releases a new GPT model」は AI の記事として出し、「Show HN: A faster SQLite backup tool」は出さないでください。
- `getTodayNews` と `TodayNewsDeps` の形（引数と戻り値）は変えないでください。
- 将来 API の鍵を使うかもしれないので、鍵を渡せるようにしておいてください。鍵は環境変数 `HN_API_KEY` で渡します。組み立ての層（`src/composition/`）で読み、`createHackerNewsSource` の第 2 引数で渡してください。鍵があるときは、取得の要求に付けて送ってください。鍵の値はまだありません。
- 試験から本物の API へ通信しないでください。

途中で私の確認を待たずに、完了まで進めてください。終わったら報告してください。
```
<!-- 依頼文の終わり -->

## 隠しの試験の sha256

`db8e76313c37f47faf39aa236a917a2dbad9c071c42f1b7dc5d7fdd8b54b3c91`
