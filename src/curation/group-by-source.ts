// 整形・選別の層。記事を情報源ごとの節に分け、節の中を並べ替える純粋な関数だけを置く。

import type { NewsItem, NewsSection, NewsSourceId } from "@/domain/news";

/**
 * 節の順（画面の上から下）。NewsSourceId のすべての値をちょうど 1 回ずつ含める（試験で確かめる）。
 * 情報源を足すときは、src/domain/news.ts の NewsSourceId、この配列、src/ui/source-labels.ts の SOURCE_LABELS を直す。
 */
export const NEWS_SOURCE_ORDER: readonly NewsSourceId[] = ["hacker-news", "hatena-bookmark"];

/**
 * 節の中の並べ替えの比較。点数の高い順、点数が同じなら公開日時の新しい順。公開日時が null の記事は、公開日時のある
 * 記事より後に置く。どちらも null、または公開日時が同じなら 0 を返す（Array.prototype.sort は安定なので、渡した順が残る）。
 */
export function compareInSection(a: NewsItem, b: NewsItem): number {
  if (a.score !== b.score) return b.score - a.score;
  if (a.publishedAt === null && b.publishedAt === null) return 0;
  if (a.publishedAt === null) return 1;
  if (b.publishedAt === null) return -1;
  return b.publishedAt.getTime() - a.publishedAt.getTime();
}

/**
 * 記事を、NEWS_SOURCE_ORDER の順の節に分ける。節の中は compareInSection の順に並べる。
 * 記事が 0 件の情報源の節は返さない。渡した配列は変えない。
 */
export function groupBySource(items: readonly NewsItem[]): NewsSection[] {
  return NEWS_SOURCE_ORDER.map((source) => ({
    source,
    items: items.filter((item) => item.source === source).sort(compareInSection),
  })).filter((section) => section.items.length > 0);
}
