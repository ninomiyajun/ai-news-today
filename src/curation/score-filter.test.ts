import { describe, expect, it } from "vitest";
import type { NewsItem } from "@/domain/news";
import { filterByMinScore } from "@/curation/score-filter";

const base: Omit<NewsItem, "id" | "score"> = {
  title: "t",
  url: "https://example.com/",
  source: "hacker-news",
  publishedAt: new Date("2026-10-07T01:00:00Z"),
};

const items: NewsItem[] = [412, 156, 88, 37].map((score) => ({ ...base, id: `hn:${score}`, score }));

describe("filterByMinScore", () => {
  it.each([
    [88, [412, 156, 88]],
    [89, [412, 156]],
    [0, [412, 156, 88, 37]],
    [1000, []],
    [null, [412, 156, 88, 37]],
  ] as const)("下限 %s では点数 %j の記事を、元の順のまま返す", (minScore, expected) => {
    expect(filterByMinScore(items, minScore).map((i) => i.score)).toEqual(expected);
  });

  it("渡した配列を変えない", () => {
    const before = items.map((i) => i.id);
    filterByMinScore(items, 100);
    filterByMinScore(items, null);
    expect(items.map((i) => i.id)).toEqual(before);
  });
});
