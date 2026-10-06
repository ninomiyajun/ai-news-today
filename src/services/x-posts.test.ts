import { afterEach, describe, expect, it, vi } from "vitest";
import type { NewsItem } from "@/domain/news";
import { withTimeout, type HttpClient, type HttpResponse } from "@/ports/http";
import { xOEmbedRequestUrl } from "@/sources/x-oembed";
import { getXPostsByItem } from "@/services/x-posts";

function item(id: string, text?: string): NewsItem {
  return { id, title: id, url: `https://example.com/${id}`, source: "hacker-news", score: 1, publishedAt: null, text };
}

function ok(author: string): HttpResponse {
  return { status: 200, body: JSON.stringify({ type: "rich", author_name: author, html: "" }) };
}

/** 呼び出しを記録し、notFound に含む投稿は 404、それ以外は成功を返す HttpClient */
function recordingClient(notFound: readonly string[] = []) {
  const calls: string[] = [];
  const http: HttpClient = {
    get: async (url) => {
      calls.push(url);
      return notFound.some((post) => xOEmbedRequestUrl(post) === url) ? { status: 404, body: "" } : ok("A");
    },
  };
  return { http, calls };
}

describe("getXPostsByItem（基準 6）", () => {
  it("(a) X の URL を含まない記事の配列は空で、get は呼ばれない", async () => {
    const { http, calls } = recordingClient();
    expect(await getXPostsByItem([item("p", "no links")], { http })).toEqual({ p: [] });
    expect(calls).toEqual([]);
  });

  it("(b) 成功 1 件と 404 の 1 件を含む記事は、成功した 1 件だけを持つ", async () => {
    const { http } = recordingClient(["https://x.com/b/status/2"]);
    const result = await getXPostsByItem([item("p", "https://x.com/a/status/1 https://x.com/b/status/2")], { http });
    expect(result).toEqual({ p: [{ postUrl: "https://x.com/a/status/1", authorName: "A" }] });
  });

  it("(c) 2 つの記事に同じ投稿があると、要求は 1 回で、両方に同じ情報が入る", async () => {
    const { http, calls } = recordingClient();
    const result = await getXPostsByItem([item("p", "https://x.com/a/status/1"), item("q", "https://x.com/a/status/1")], {
      http,
    });
    expect(calls).toEqual([xOEmbedRequestUrl("https://x.com/a/status/1")]);
    const embed = { postUrl: "https://x.com/a/status/1", authorName: "A" };
    expect(result).toEqual({ p: [embed], q: [embed] });
  });

  it("(d) 12 件の異なる投稿のうち、記事の順の先頭 10 件だけを要求する", async () => {
    const { http, calls } = recordingClient();
    const posts = Array.from({ length: 12 }, (_, i) => `https://x.com/u${i}/status/${i + 1}`);
    const items = [0, 1, 2, 3].map((n) => item(`n${n}`, posts.slice(n * 3, n * 3 + 3).join(" ")));
    const result = await getXPostsByItem(items, { http });
    expect(calls).toEqual(posts.slice(0, 10).map(xOEmbedRequestUrl));
    expect(result.n3).toEqual([{ postUrl: posts[9], authorName: "A" }]);
    expect(result.n2).toHaveLength(3);
  });

  it("記事をまたいで利用者名の大文字と小文字だけが違う同じ投稿は、最初に出てきた URL で 1 回だけ要求する", async () => {
    const { http, calls } = recordingClient();
    const result = await getXPostsByItem(
      [item("p", "https://x.com/Foo/status/1"), item("q", "https://twitter.com/foo/status/1")],
      { http },
    );
    expect(calls).toEqual([xOEmbedRequestUrl("https://x.com/Foo/status/1")]);
    const embed = { postUrl: "https://x.com/Foo/status/1", authorName: "A" };
    expect(result).toEqual({ p: [embed], q: [embed] });
  });

  it("(e) 2 つの記事が同じ 3 件を持つと、要求は 3 回で、全体の上限でも 3 件と数える", async () => {
    const { http, calls } = recordingClient();
    const three = "https://x.com/a/status/1 https://x.com/b/status/2 https://x.com/c/status/3";
    const result = await getXPostsByItem([item("p", three), item("q", three)], { http });
    expect(calls).toHaveLength(3);
    expect(result.p).toHaveLength(3);
    expect(result.q).toEqual(result.p);
  });
});

describe("getXPostsByItem と時間切れ（基準 7 の (b)）", () => {
  afterEach(() => {
    vi.useRealTimers();
  });

  it("応答が返らないまま 5000 ミリ秒たつと、例外を出さずに解決し、記事の配列は空になる", async () => {
    vi.useFakeTimers();
    const never: HttpClient = { get: () => new Promise<HttpResponse>(() => {}) };
    const result = getXPostsByItem([item("p", "https://x.com/a/status/1")], { http: withTimeout(never, 5000) });
    await vi.advanceTimersByTimeAsync(5000);
    await expect(result).resolves.toEqual({ p: [] });
  });
});
