import { describe, expect, it } from "vitest";
import type { NewsItem, NewsSourceId } from "@/domain/news";
import { buildNewsSections } from "@/services/news-sections";

function item(id: string, source: NewsSourceId, score: number, publishedAt: string | null): NewsItem {
  return {
    id,
    title: id,
    url: `https://example.com/${id}`,
    source,
    score,
    publishedAt: publishedAt === null ? null : new Date(publishedAt),
  };
}

describe("buildNewsSections（計画の V5）", () => {
  it("(a) 空の配列には、節も記事も空で返す", () => {
    const items: NewsItem[] = [];
    expect(buildNewsSections(items)).toEqual({ sections: [], items: [] });
    expect(items).toEqual([]);
  });

  it("(b) 点数が同じで、公開日時の一方が null の 2 件では、公開日時のある記事が先に並ぶ", () => {
    const items = [item("null", "hacker-news", 10, null), item("dated", "hacker-news", 10, "2026-10-07T01:00:00Z")];
    const before = [...items];
    expect(buildNewsSections(items).items.map((i) => i.id)).toEqual(["dated", "null"]);
    expect(items).toEqual(before);
  });

  it("(c) 点数も公開日時も同じ 2 件は、渡した順のまま並ぶ", () => {
    const items = [
      item("first", "hatena-bookmark", 10, "2026-10-07T01:00:00Z"),
      item("second", "hatena-bookmark", 10, "2026-10-07T01:00:00Z"),
    ];
    const before = [...items];
    expect(buildNewsSections(items).items.map((i) => i.id)).toEqual(["first", "second"]);
    expect(items).toEqual(before);
  });

  it("(d) はてなブックマークの記事を先に並べても、節と表示の順の記事は Hacker News が先になる", () => {
    const items = [
      item("hb37", "hatena-bookmark", 37, "2026-10-07T01:00:00Z"),
      item("hb156", "hatena-bookmark", 156, "2026-10-07T01:00:00Z"),
      item("hn88", "hacker-news", 88, "2026-10-07T01:00:00Z"),
      item("hn412", "hacker-news", 412, "2026-10-07T01:00:00Z"),
    ];
    const before = [...items];
    const result = buildNewsSections(items);
    expect(result.sections.map((s) => s.source)).toEqual(["hacker-news", "hatena-bookmark"]);
    expect(result.items.map((i) => i.id)).toEqual(["hn412", "hn88", "hb156", "hb37"]);
    expect(items).toEqual(before);
  });

  it("(e) 点数 88、412、37 の順で渡した同じ情報源の 3 件は、412、88、37 の順に並ぶ", () => {
    const items = [88, 412, 37].map((score) => item(`hn:${score}`, "hacker-news", score, "2026-10-07T01:00:00Z"));
    const before = [...items];
    const result = buildNewsSections(items);
    expect(result.sections[0].items.map((i) => i.score)).toEqual([412, 88, 37]);
    expect(result.items.map((i) => i.score)).toEqual([412, 88, 37]);
    expect(items).toEqual(before);
  });
});
