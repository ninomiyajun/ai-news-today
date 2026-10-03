// 記事を表す型。どの層からも参照される最下層で、他の層を import しない。
// P1（土台）の仮置きの形で、項目は機能を作るときに見直す。

export type NewsSourceId = "hacker-news" | "hatena-bookmark";

export type NewsItem = {
  id: string;
  title: string;
  url: string;
  source: NewsSourceId;
  /** Hacker News の点数、またははてなブックマークのブックマーク数 */
  score: number;
  /** 記事そのものの公開日時。分からない記事は表示しない（AGENTS.md） */
  publishedAt: Date | null;
};
