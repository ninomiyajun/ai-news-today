import { renderToStaticMarkup } from "react-dom/server";
import { beforeEach, describe, expect, it, vi } from "vitest";
import type { NewsItem, XPostEmbed } from "@/domain/news";
import { NewsList } from "@/ui/NewsList";
import { WIDGETS_JS_URL } from "@/ui/XPostEmbed";

// next/script の Script を、受け取った引数を記録するだけの部品に差し替える（基準 10）。
const scriptCalls = vi.hoisted(() => [] as Array<Record<string, unknown>>);
vi.mock("next/script", () => ({
  default: (props: Record<string, unknown>) => {
    scriptCalls.push(props);
    return null;
  },
}));

const ITEM: NewsItem = {
  id: "1",
  title: "t",
  url: "https://example.com/1",
  source: "hacker-news",
  score: 3,
  publishedAt: new Date("2026-10-06T00:00:00Z"),
};

function embed(n: number): XPostEmbed {
  return { postUrl: `https://x.com/a/status/${n}`, authorName: "A" };
}

beforeEach(() => {
  scriptCalls.length = 0;
});

describe("NewsList（基準 9）", () => {
  it("(a) 埋め込みの情報を渡さないと、変更前と同じ出力になる", () => {
    // 期待値は、NewsList を変える前に同じ入力で得た出力（計画の手順 7）
    expect(renderToStaticMarkup(<NewsList items={[ITEM]} />)).toBe(
      '<ul><li><a href="https://example.com/1" target="_blank" rel="noopener noreferrer">t</a> <small>(3)</small></li></ul>',
    );
  });

  it("(b) 埋め込みの情報を渡すと、代替の表示を持つ blockquote を出す", () => {
    const html = renderToStaticMarkup(<NewsList items={[ITEM]} xPosts={{ "1": [embed(1)] }} />);
    const blockquote = html.match(/<blockquote[^>]*>.*?<\/blockquote>/)?.[0] ?? "";
    expect(blockquote).toMatch(/^<blockquote class="twitter-tweet" data-dnt="true">/);
    expect(blockquote).toContain("<span>A</span>");
    expect(blockquote).toContain(
      '<a href="https://x.com/a/status/1" target="_blank" rel="noopener noreferrer">X で見る</a>',
    );
  });
});

describe("NewsList の外部のスクリプト（基準 10）", () => {
  const ITEM2: NewsItem = { ...ITEM, id: "2", url: "https://example.com/2" };

  it("スクリプトの定数は widgets.js の URL である", () => {
    expect(WIDGETS_JS_URL).toBe("https://platform.twitter.com/widgets.js");
  });

  it("(a) 埋め込みが 0 件なら Script を描かない", () => {
    renderToStaticMarkup(<NewsList items={[ITEM, ITEM2]} xPosts={{ "1": [], "2": [] }} />);
    expect(scriptCalls).toHaveLength(0);
  });

  it("(b) 埋め込みが 1 件なら Script を 1 回だけ、定数の src で描く", () => {
    renderToStaticMarkup(<NewsList items={[ITEM]} xPosts={{ "1": [embed(1)] }} />);
    expect(scriptCalls).toHaveLength(1);
    expect(scriptCalls[0].src).toBe(WIDGETS_JS_URL);
  });

  it("(c) 埋め込みが 3 件（記事 2 件に分かれる）でも Script は 1 回だけ描く", () => {
    renderToStaticMarkup(<NewsList items={[ITEM, ITEM2]} xPosts={{ "1": [embed(1), embed(2)], "2": [embed(3)] }} />);
    expect(scriptCalls).toHaveLength(1);
    expect(scriptCalls[0].src).toBe(WIDGETS_JS_URL);
  });
});
