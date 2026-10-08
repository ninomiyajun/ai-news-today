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
  /**
   * 情報源が一覧の取得のときに記事に添えて渡す短い文章（Hacker News の投稿の本文など）。
   * HTML の実体参照を解いた平文。HTML から平文にするのは情報源の責務。
   */
  text?: string;
};

/**
 * 1 つの情報源の記事だけを集めた、画面の区画（節）。節を作るのは整形・選別の層で、表示するのは表示の部品の層なので、
 * 両方から使える型の層に置く。
 */
export type NewsSection = {
  source: NewsSourceId;
  items: NewsItem[];
};

/** X の投稿の埋め込みの情報。oEmbed の応答から取り出した値だけを持ち、応答の HTML は持たない。 */
export type XPostEmbed = {
  /** 投稿の URL の正規の形（https://x.com/<利用者名>/status/<id>） */
  postUrl: string;
  /** 投稿者の名前（oEmbed の author_name） */
  authorName: string;
};
