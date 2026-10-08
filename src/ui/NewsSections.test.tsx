import { renderToStaticMarkup } from "react-dom/server";
import { beforeEach, describe, expect, it, vi } from "vitest";
import type { NewsItem, NewsSection, XPostEmbed } from "@/domain/news";
import { NewsSections } from "@/ui/NewsSections";
import { WIDGETS_JS_URL } from "@/ui/XPostEmbed";

// next/script の Script を、受け取った引数を記録するだけの部品に差し替える（src/ui/NewsList.test.tsx の基準 10 と同じ形）。
const scriptCalls = vi.hoisted(() => [] as Array<Record<string, unknown>>);
vi.mock("next/script", () => ({
  default: (props: Record<string, unknown>) => {
    scriptCalls.push(props);
    return null;
  },
}));

const HN1: NewsItem = {
  id: "hn:1",
  title: "hn1",
  url: "https://example.com/hn1",
  source: "hacker-news",
  score: 412,
  publishedAt: new Date("2026-10-07T01:00:00Z"),
};
const HN2: NewsItem = { ...HN1, id: "hn:2", title: "hn2", url: "https://example.com/hn2", score: 88 };
const HB1: NewsItem = {
  id: "hatena:1",
  title: "hb1",
  url: "https://example.com/hb1",
  source: "hatena-bookmark",
  score: 156,
  publishedAt: new Date("2026-10-07T01:00:00Z"),
};
const HB2: NewsItem = { ...HB1, id: "hatena:2", title: "hb2", url: "https://example.com/hb2", score: 37 };

const TWO_SECTIONS: NewsSection[] = [
  { source: "hacker-news", items: [HN1, HN2] },
  { source: "hatena-bookmark", items: [HB1, HB2] },
];

function embed(n: number): XPostEmbed {
  return { postUrl: `https://x.com/a/status/${n}`, authorName: "A" };
}

beforeEach(() => {
  scriptCalls.length = 0;
});

describe("NewsSections の外部のスクリプト（計画の V7 と、NewsList から移した基準 10 の試験）", () => {
  it("V7 (a) 2 つの節で、埋め込みが 0 件なら Script を描かない", () => {
    renderToStaticMarkup(<NewsSections sections={TWO_SECTIONS} xPosts={{ "hn:1": [], "hatena:1": [] }} />);
    expect(scriptCalls).toHaveLength(0);
  });

  it("V7 (b) 2 つの節で、Hacker News の記事に 1 件、はてなブックマークの記事に 2 件の埋め込みがあっても、Script を 1 回だけ描く", () => {
    renderToStaticMarkup(
      <NewsSections sections={TWO_SECTIONS} xPosts={{ "hn:1": [embed(1)], "hatena:2": [embed(2), embed(3)] }} />,
    );
    expect(scriptCalls).toHaveLength(1);
    expect(scriptCalls[0].src).toBe(WIDGETS_JS_URL);
  });

  it("基準 10 (a) 埋め込みが 0 件なら Script を描かない", () => {
    renderToStaticMarkup(
      <NewsSections sections={[{ source: "hacker-news", items: [HN1, HN2] }]} xPosts={{ "hn:1": [], "hn:2": [] }} />,
    );
    expect(scriptCalls).toHaveLength(0);
  });

  it("基準 10 (b) 埋め込みが 1 件なら Script を 1 回だけ、定数の src で描く", () => {
    renderToStaticMarkup(
      <NewsSections sections={[{ source: "hacker-news", items: [HN1] }]} xPosts={{ "hn:1": [embed(1)] }} />,
    );
    expect(scriptCalls).toHaveLength(1);
    expect(scriptCalls[0].src).toBe(WIDGETS_JS_URL);
  });

  it("基準 10 (c) 埋め込みが 3 件（2 つの節の記事に分かれる）でも Script は 1 回だけ描く", () => {
    renderToStaticMarkup(
      <NewsSections sections={TWO_SECTIONS} xPosts={{ "hn:1": [embed(1), embed(2)], "hatena:1": [embed(3)] }} />,
    );
    expect(scriptCalls).toHaveLength(1);
    expect(scriptCalls[0].src).toBe(WIDGETS_JS_URL);
  });
});

describe("NewsSections の節の描画", () => {
  it("節が空なら「表示できる記事はまだありません。」だけを描き、節を描かない", () => {
    const html = renderToStaticMarkup(<NewsSections sections={[]} />);
    expect(html).toBe("<p>表示できる記事はまだありません。</p>");
    expect(html).not.toContain("<section");
    expect(scriptCalls).toHaveLength(0);
  });

  it("節ごとに、見出しの id と aria-labelledby を対応させ、見出しに情報源の名前と件数を出す", () => {
    const html = renderToStaticMarkup(
      <NewsSections sections={[TWO_SECTIONS[0], { source: "hatena-bookmark", items: [HB1] }]} />,
    );
    expect(html).toContain(
      '<section aria-labelledby="news-section-hacker-news"><h2 id="news-section-hacker-news">Hacker News（2 件）</h2>',
    );
    expect(html).toContain(
      '<section aria-labelledby="news-section-hatena-bookmark"><h2 id="news-section-hatena-bookmark">はてなブックマーク（1 件）</h2>',
    );
    expect(html.indexOf("news-section-hacker-news")).toBeLessThan(html.indexOf("news-section-hatena-bookmark"));
    expect(html).not.toContain("表示できる記事はまだありません。");
  });

  it("受け取った節と記事を、受け取った順のまま描く（並べ替えない）", () => {
    const html = renderToStaticMarkup(
      <NewsSections
        sections={[
          { source: "hatena-bookmark", items: [HB2, HB1] },
          { source: "hacker-news", items: [HN2, HN1] },
        ]}
      />,
    );
    const titles = [...html.matchAll(/rel="noopener noreferrer">([^<]+)<\/a>/g)].map((m) => m[1]);
    expect(titles).toEqual(["hb2", "hb1", "hn2", "hn1"]);
  });
});
