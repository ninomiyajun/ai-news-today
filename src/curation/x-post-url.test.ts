import { describe, expect, it } from "vitest";
import { extractXPostUrls, xPostUrlsOfItem } from "@/curation/x-post-url";
import type { NewsItem } from "@/domain/news";

describe("extractXPostUrls（基準 1、2）", () => {
  it("基準 1: 別名のホスト、クエリ、断片を落とした正規の形を、出てきた順で返す", () => {
    const text =
      "見て https://twitter.com/example_user/status/1234567890123456789?s=20 と https://x.com/Other_1/status/42#m";
    expect(extractXPostUrls(text)).toEqual([
      "https://x.com/example_user/status/1234567890123456789",
      "https://x.com/Other_1/status/42",
    ]);
  });

  it.each([
    ["(a) mobile.twitter.com", "https://mobile.twitter.com/a/status/1", ["https://x.com/a/status/1"]],
    ["(b) www.x.com", "https://www.x.com/a/status/2", ["https://x.com/a/status/2"]],
    ["(c) mobile.x.com", "https://mobile.x.com/a/status/3", ["https://x.com/a/status/3"]],
    ["(d) http: の twitter.com", "http://twitter.com/a/status/4", ["https://x.com/a/status/4"]],
    ["(e) 日本語に続けて書いた URL", "見てhttps://x.com/a/status/5です", ["https://x.com/a/status/5"]],
    ["(f) /status/<id> の後ろの道", "https://x.com/a/status/6/photo/1", ["https://x.com/a/status/6"]],
    ["(g) 利用者のページ", "https://x.com/a", []],
    ["(h) x.com/i/status", "https://x.com/i/status/7", []],
    ["(i) x.com/i/web/status", "https://x.com/i/web/status/8", []],
    ["(j) 別のホストの道の中", "https://example.com/x.com/a/status/9", []],
    ["(k) javascript:", "javascript:alert(1)//x.com/a/status/10", []],
    ["(l) id が数字だけでない", "https://x.com/a/status/12abc", []],
  ])("基準 2 %s", (_label, input, expected) => {
    expect(extractXPostUrls(input)).toEqual(expected);
  });

  it("文の中の閉じ括弧と句読点を URL に含めない", () => {
    expect(extractXPostUrls("(https://x.com/a/status/1)、https://x.com/b/status/2.")).toEqual([
      "https://x.com/a/status/1",
      "https://x.com/b/status/2",
    ]);
  });

  it("利用者の情報を含む形で別のホストを指す URL を通さない", () => {
    expect(extractXPostUrls("https://x.com@example.com/a/status/1")).toEqual([]);
  });
});

describe("xPostUrlsOfItem（基準 3）", () => {
  const base: NewsItem = {
    id: "hn:1",
    title: "t",
    url: "https://example.com/1",
    source: "hacker-news",
    score: 1,
    publishedAt: null,
  };

  it("記事の URL を先に見て、同じ正規の形を 1 回だけ数え、先頭の 3 件を返す", () => {
    const item: NewsItem = {
      ...base,
      url: "https://twitter.com/a/status/1",
      text: "https://x.com/a/status/1 https://x.com/b/status/2 https://x.com/c/status/3 https://x.com/d/status/4",
    };
    expect(xPostUrlsOfItem(item)).toEqual([
      "https://x.com/a/status/1",
      "https://x.com/b/status/2",
      "https://x.com/c/status/3",
    ]);
  });

  it("利用者名の大文字と小文字だけが違う同じ投稿は 1 件と数え、最初に出てきた URL を残す", () => {
    const item: NewsItem = {
      ...base,
      url: "https://x.com/Foo/status/1",
      text: "https://twitter.com/foo/status/1 https://x.com/b/status/2",
    };
    expect(xPostUrlsOfItem(item)).toEqual(["https://x.com/Foo/status/1", "https://x.com/b/status/2"]);
  });

  it("添えた文章が無い記事でも動く", () => {
    expect(xPostUrlsOfItem(base)).toEqual([]);
  });
});
