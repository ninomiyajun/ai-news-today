// 整形・選別の層。点数の下限で記事を絞り込む純粋な関数。クエリの値の解釈は src/services/score-filter.ts で行う。

import type { NewsItem } from "@/domain/news";

/** 点数が minScore 以上の記事だけを、元の順のまま返す。minScore が null なら全件の写しを返す。渡した配列は変えない。 */
export function filterByMinScore(items: readonly NewsItem[], minScore: number | null): NewsItem[] {
  if (minScore === null) return [...items];
  return items.filter((item) => item.score >= minScore);
}
