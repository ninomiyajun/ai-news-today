// 処理の流れの層。記事を情報源ごとの節に分ける整形・選別の関数につなぐ。
// 画面の層は整形・選別の層を import できないので、この層が入口になる（ARCHITECTURE.md の「層と責務」）。

import { groupBySource } from "@/curation/group-by-source";
import type { NewsItem, NewsSection } from "@/domain/news";

/**
 * 記事を情報源ごとの節に分け、節と、各節の記事を表示の順（節の順、節の中の順）につないだ記事の配列を返す。
 * 表示の順の記事は、X の投稿の埋め込みを画面の上の記事から問い合わせるために使う。渡した配列は変えない。
 */
export function buildNewsSections(items: readonly NewsItem[]): { sections: NewsSection[]; items: NewsItem[] } {
  const sections = groupBySource(items);
  return { sections, items: sections.flatMap((section) => section.items) };
}
