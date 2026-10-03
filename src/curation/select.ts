// 整形・選別の層。純粋な関数だけを置き、取得や現在時刻の取得はしない（時刻は引数で受け取る）。
// P1 の仮置きの最小の選別で、AI に関する記事の判定やニュース性の判定は機能を作るときに足す。

import type { NewsItem } from "@/domain/news";

/** 公開日時が now から maxAgeHours 以内の記事だけを、score の高い順に返す。公開日時の無い記事は除く。 */
export function selectRecent(items: readonly NewsItem[], now: Date, maxAgeHours: number): NewsItem[] {
  const oldest = now.getTime() - maxAgeHours * 60 * 60 * 1000;
  return items
    .filter((item) => item.publishedAt !== null)
    .filter((item) => {
      const t = (item.publishedAt as Date).getTime();
      return t >= oldest && t <= now.getTime();
    })
    .sort((a, b) => b.score - a.score);
}

// CI が違反で失敗することを確かめるための、わざと入れた違反（マージしない）。
export const deliberateViolation = Date.now();
