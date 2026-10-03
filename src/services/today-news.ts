// 処理の流れの層。取得と整形・選別を束ねる。依存（情報源と時計）は引数で受け取り、自分では作らない。

import { selectRecent } from "@/curation/select";
import type { NewsItem } from "@/domain/news";
import type { Clock } from "@/ports/clock";
import type { NewsSource } from "@/sources/source";

export type TodayNewsDeps = {
  sources: readonly NewsSource[];
  clock: Clock;
};

/** 「今日のニュース」の仮の定義: 直近 24 時間に公開された記事（P1 の仮置き） */
export const TODAY_WINDOW_HOURS = 24;

export async function getTodayNews(deps: TodayNewsDeps): Promise<NewsItem[]> {
  const lists = await Promise.all(deps.sources.map((source) => source.fetchItems()));
  return selectRecent(lists.flat(), deps.clock.now(), TODAY_WINDOW_HOURS);
}
