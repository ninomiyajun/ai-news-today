import { describe, expect, it } from "vitest";
import { fixtureHttpClient, type HttpClient, type HttpResponse } from "@/ports/http";
import { fetchXPostEmbed } from "@/sources/x-oembed";

const POST_URL = "https://x.com/a/status/1";
// 手順 1 で決めた要求の URL の形（計画の基準 4。判断の記録の 11、12）
const REQUEST_URL = "https://publish.x.com/oembed?url=https%3A%2F%2Fx.com%2Fa%2Fstatus%2F1";

function respondWith(res: HttpResponse): HttpClient {
  return fixtureHttpClient({ [REQUEST_URL]: res });
}

function json(value: unknown): HttpResponse {
  return { status: 200, body: JSON.stringify(value) };
}

describe("fetchXPostEmbed", () => {
  it("基準 4: 決めた形の URL に要求し、埋め込みの情報を返す", async () => {
    const http = respondWith(json({ type: "rich", author_name: "A", html: "<blockquote>...</blockquote>" }));
    expect(await fetchXPostEmbed(http, POST_URL)).toEqual({ postUrl: POST_URL, authorName: "A" });
  });

  it.each<[string, HttpResponse]>([
    ["(a) 状態 404", { status: 404, body: "" }],
    ["(b) 状態 403", { status: 403, body: "" }],
    ["(c) JSON でない本文", { status: 200, body: "<html>not json</html>" }],
    ["(d) type が video", json({ type: "video", author_name: "A", html: "" })],
    ["(e) type が無い", json({ author_name: "A", html: "" })],
    ["(f) author_name が数値", json({ type: "rich", author_name: 1, html: "" })],
    ["(g) author_name が無い", json({ type: "rich", html: "" })],
    ["(h) author_name が空の文字列", json({ type: "rich", author_name: "", html: "" })],
    ["author_name が空白だけ", json({ type: "rich", author_name: "   ", html: "" })],
  ])("基準 5 %s は null を返す", async (_label, res) => {
    expect(await fetchXPostEmbed(respondWith(res), POST_URL)).toBeNull();
  });

  it("基準 5 (i) get が例外を投げても null を返す", async () => {
    const http: HttpClient = {
      get: async () => {
        throw new Error("network");
      },
    };
    expect(await fetchXPostEmbed(http, POST_URL)).toBeNull();
  });

  it("author_name の前後の空白を落として返す", async () => {
    const http = respondWith(json({ type: "rich", author_name: "  A ", html: "" }));
    expect(await fetchXPostEmbed(http, POST_URL)).toEqual({ postUrl: POST_URL, authorName: "A" });
  });

  it("JSON の null や配列でも例外を投げない", async () => {
    expect(await fetchXPostEmbed(respondWith({ status: 200, body: "null" }), POST_URL)).toBeNull();
    expect(await fetchXPostEmbed(respondWith({ status: 200, body: "[]" }), POST_URL)).toBeNull();
  });
});
