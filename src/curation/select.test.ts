import { describe, expect, it } from "vitest";
import type { NewsItem } from "@/domain/news";
import { selectRecent } from "@/curation/select";

const base: Omit<NewsItem, "id" | "score" | "publishedAt"> = {
  title: "t",
  url: "https://example.com/",
  source: "hacker-news",
};

describe("selectRecent", () => {
  const now = new Date("2026-10-03T12:00:00Z");

  it("公開日時が範囲内の記事だけを、score の高い順に返す", () => {
    const items: NewsItem[] = [
      { ...base, id: "a", score: 10, publishedAt: new Date("2026-10-03T11:00:00Z") },
      { ...base, id: "b", score: 50, publishedAt: new Date("2026-10-03T01:00:00Z") },
      { ...base, id: "old", score: 99, publishedAt: new Date("2026-10-01T12:00:00Z") },
      { ...base, id: "future", score: 99, publishedAt: new Date("2026-10-03T13:00:00Z") },
      { ...base, id: "unknown", score: 99, publishedAt: null },
    ];
    expect(selectRecent(items, now, 24).map((i) => i.id)).toEqual(["b", "a"]);
  });
});
