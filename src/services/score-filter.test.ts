import { describe, expect, it } from "vitest";
import type { NewsItem } from "@/domain/news";
import { applyMinScore, MIN_SCORE_QUERY_NAME, parseMinScore } from "@/services/score-filter";

describe("parseMinScore", () => {
  it.each([
    ["100", 100],
    ["0", 0],
    ["88", 88],
    ["088", 88],
  ] as const)("%j を下限 %s として受け取る", (raw, expected) => {
    expect(parseMinScore(raw)).toBe(expected);
  });

  it.each([
    undefined,
    "",
    "abc",
    "-5",
    "1.5",
    " 100",
    "100 ",
    "+5",
    "1e2",
    "0x10",
    "１００",
    "99999999999999999999",
    ["100", "200"],
  ])("不正な値 %j では null を返す", (raw) => {
    expect(parseMinScore(raw)).toBeNull();
  });
});

describe("applyMinScore", () => {
  const items: NewsItem[] = [412, 156, 88, 37].map((score) => ({
    id: `hn:${score}`,
    title: "t",
    url: "https://example.com/",
    source: "hacker-news",
    score,
    publishedAt: new Date("2026-10-07T01:00:00Z"),
  }));

  it("クエリの名前は min である", () => {
    expect(MIN_SCORE_QUERY_NAME).toBe("min");
  });

  it("正しい値では、下限以上の記事と下限を返す", () => {
    const result = applyMinScore(items, "100");
    expect(result.items.map((i) => i.score)).toEqual([412, 156]);
    expect(result.minScore).toBe(100);
  });

  it("不正な値では、全件と null を返す", () => {
    const result = applyMinScore(items, "abc");
    expect(result.items.map((i) => i.score)).toEqual([412, 156, 88, 37]);
    expect(result.minScore).toBeNull();
  });
});
