// 取得の層。情報源ごとの取得を NewsSource の形にそろえる。
// P1 では、決まったデータを返す情報源だけを置く。Hacker News とはてなブックマークの取得は、
// 機能を作るときに ports/http.ts の HttpClient を受け取る形で足す。

import type { NewsItem } from "@/domain/news";

export type NewsSource = {
  name: string;
  fetchItems: () => Promise<NewsItem[]>;
};

/** 決まった記事を返す情報源。試験と、取得を作る前の画面の確認に使う。 */
export function staticSource(name: string, items: readonly NewsItem[]): NewsSource {
  return {
    name,
    fetchItems: async () => items.map((item) => ({ ...item })),
  };
}
