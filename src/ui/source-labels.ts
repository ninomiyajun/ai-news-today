// 表示の部品の層。情報源ごとの表示名と点数の単位、それを使った画面の文言を置く。
// 文言は 1 つの文字列を返す関数で組み立てる。JSX で文字列と数を並べると、サーバーで描いた HTML に区切りのコメント
// （<!-- -->）が入り、HTML の文字列の検索で文言が見つからなくなるためである。

import type { NewsSourceId } from "@/domain/news";

/** 情報源ごとの表示名と点数の単位。NewsSourceId に値を足すと、Record の型によりここで型の検査が失敗する。 */
export const SOURCE_LABELS: Readonly<Record<NewsSourceId, { name: string; unit: string }>> = {
  "hacker-news": { name: "Hacker News", unit: "点" },
  "hatena-bookmark": { name: "はてなブックマーク", unit: "ブックマーク" },
};

/** 節の見出しの文言（例: 「Hacker News（3 件）」。括弧は全角）。 */
export function sectionHeadingText(source: NewsSourceId, count: number): string {
  return `${SOURCE_LABELS[source].name}（${count} 件）`;
}

/** 記事の点数の文言（例: 「412 点」「156 ブックマーク」）。 */
export function scoreText(source: NewsSourceId, score: number): string {
  return `${score} ${SOURCE_LABELS[source].unit}`;
}
