import { describe, expect, it } from "vitest";
import type { NewsItem, NewsSection, NewsSourceId } from "@/domain/news";
import { compareInSection, groupBySource, NEWS_SOURCE_ORDER } from "@/curation/group-by-source";

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

/** 節ごとの [情報源, 記事の id の並び] */
function shapeOf(sections: readonly NewsSection[]): Array<[NewsSourceId, string[]]> {
  return sections.map((s) => [s.source, s.items.map((i) => i.id)]);
}

/** 渡した配列が呼ぶ前と後で変わらないことを確かめるための写し（記事の参照の並び） */
function snapshot(items: readonly NewsItem[]): NewsItem[] {
  return [...items];
}

describe("groupBySource（計画の V5）", () => {
  it("(a) 空の配列には空の配列を返す", () => {
    const items: NewsItem[] = [];
    expect(groupBySource(items)).toEqual([]);
    expect(items).toEqual([]);
  });

  it("(b) 点数が同じで、公開日時の一方が null の 2 件では、公開日時のある記事が先に並ぶ", () => {
    const items = [item("null", "hacker-news", 10, null), item("dated", "hacker-news", 10, "2026-10-07T01:00:00Z")];
    const before = snapshot(items);
    expect(shapeOf(groupBySource(items))).toEqual([["hacker-news", ["dated", "null"]]]);
    expect(items).toEqual(before);
  });

  it("(c) 点数も公開日時も同じ 2 件は、渡した順のまま並ぶ", () => {
    const items = [
      item("first", "hatena-bookmark", 10, "2026-10-07T01:00:00Z"),
      item("second", "hatena-bookmark", 10, "2026-10-07T01:00:00Z"),
    ];
    const before = snapshot(items);
    expect(shapeOf(groupBySource(items))).toEqual([["hatena-bookmark", ["first", "second"]]]);
    expect(items).toEqual(before);
  });

  it("(c') 点数が同じで、公開日時がどちらも null の 2 件も、渡した順のまま並ぶ", () => {
    const items = [item("first", "hacker-news", 10, null), item("second", "hacker-news", 10, null)];
    expect(shapeOf(groupBySource(items))).toEqual([["hacker-news", ["first", "second"]]]);
  });

  it("(d) はてなブックマークの記事を先に並べても、節は Hacker News、はてなブックマークの順になる", () => {
    const items = [
      item("hb1", "hatena-bookmark", 156, "2026-10-07T01:00:00Z"),
      item("hb2", "hatena-bookmark", 37, "2026-10-07T01:00:00Z"),
      item("hn1", "hacker-news", 12, "2026-10-07T01:00:00Z"),
    ];
    const before = snapshot(items);
    expect(shapeOf(groupBySource(items))).toEqual([
      ["hacker-news", ["hn1"]],
      ["hatena-bookmark", ["hb1", "hb2"]],
    ]);
    expect(items).toEqual(before);
  });

  it("(e) 点数 88、412、37 の順で渡した同じ情報源の 3 件は、節の中で 412、88、37 の順に並ぶ", () => {
    const items = [88, 412, 37].map((score) => item(`hn:${score}`, "hacker-news", score, "2026-10-07T01:00:00Z"));
    const before = snapshot(items);
    const sections = groupBySource(items);
    expect(sections).toHaveLength(1);
    expect(sections[0].items.map((i) => i.score)).toEqual([412, 88, 37]);
    expect(items).toEqual(before);
    expect(items.map((i) => i.score)).toEqual([88, 412, 37]);
  });

  it("(f) NEWS_SOURCE_ORDER は NewsSourceId のすべての値を、ちょうど 1 回ずつ含む", () => {
    // NewsSourceId に値を足すと、Record の型によりこの表が型の検査で失敗する。表を直したときに、
    // NEWS_SOURCE_ORDER の直し漏れ（と重複）がこの試験で分かる。
    const ALL_SOURCES: Record<NewsSourceId, true> = { "hacker-news": true, "hatena-bookmark": true };
    expect([...NEWS_SOURCE_ORDER].sort()).toEqual(Object.keys(ALL_SOURCES).sort());
  });
});

describe("groupBySource（仕様の前提の記事での節の並び）", () => {
  it("SRC-3: 取得の順が点数の高い順でなくても、節の中は点数の高い順に並ぶ", () => {
    const items = [
      item("hn88", "hacker-news", 88, "2026-10-07T01:00:00Z"),
      item("hn412", "hacker-news", 412, "2026-10-07T01:00:00Z"),
      item("hn37", "hacker-news", 37, "2026-10-07T01:00:00Z"),
      item("hb37", "hatena-bookmark", 37, "2026-10-07T01:00:00Z"),
      item("hb156", "hatena-bookmark", 156, "2026-10-07T01:00:00Z"),
    ];
    expect(shapeOf(groupBySource(items))).toEqual([
      ["hacker-news", ["hn412", "hn88", "hn37"]],
      ["hatena-bookmark", ["hb156", "hb37"]],
    ]);
  });

  it("SRC-5: はてなブックマークの側で件数や点数が多くても、Hacker News の節が先に出る", () => {
    const items = [
      item("hb156", "hatena-bookmark", 156, "2026-10-07T01:00:00Z"),
      item("hb88", "hatena-bookmark", 88, "2026-10-07T01:00:00Z"),
      item("hb37", "hatena-bookmark", 37, "2026-10-07T01:00:00Z"),
      item("hn12", "hacker-news", 12, "2026-10-07T01:00:00Z"),
    ];
    expect(groupBySource(items).map((s) => s.source)).toEqual(["hacker-news", "hatena-bookmark"]);
  });

  it("SRC-6: 記事が 0 件の情報源の節は返さない", () => {
    const items = [
      item("hn412", "hacker-news", 412, "2026-10-07T01:00:00Z"),
      item("hn88", "hacker-news", 88, "2026-10-07T01:00:00Z"),
    ];
    expect(shapeOf(groupBySource(items))).toEqual([["hacker-news", ["hn412", "hn88"]]]);
  });

  it("SRC-12: 同じ節で点数が同じ記事は、公開日時の新しい順に並ぶ", () => {
    const items = [
      item("88-9h", "hacker-news", 88, "2026-10-07T00:00:00Z"),
      item("88-11h", "hacker-news", 88, "2026-10-07T02:00:00Z"),
      item("412-8h", "hacker-news", 412, "2026-10-06T23:00:00Z"),
    ];
    expect(shapeOf(groupBySource(items))).toEqual([["hacker-news", ["412-8h", "88-11h", "88-9h"]]]);
  });
});

describe("compareInSection", () => {
  it("点数が違えば点数の高い方を先にする", () => {
    expect(compareInSection(item("a", "hacker-news", 1, null), item("b", "hacker-news", 2, null))).toBeGreaterThan(0);
  });

  it("点数も公開日時も同じなら 0 を返す", () => {
    const a = item("a", "hacker-news", 1, "2026-10-07T01:00:00Z");
    const b = item("b", "hacker-news", 1, "2026-10-07T01:00:00Z");
    expect(compareInSection(a, b)).toBe(0);
  });
});
