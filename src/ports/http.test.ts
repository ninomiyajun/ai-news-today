import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { fixtureHttpClient, withTimeout, type HttpClient, type HttpResponse } from "@/ports/http";

describe("fixtureHttpClient", () => {
  it("登録した URL には決まった応答を、それ以外には 404 を返す", async () => {
    const http = fixtureHttpClient({ "https://example.com/a": { status: 200, body: "ok" } });
    expect(await http.get("https://example.com/a")).toEqual({ status: 200, body: "ok" });
    expect((await http.get("https://example.com/b")).status).toBe(404);
  });
});

describe("withTimeout（基準 7 の (a) と (c)）", () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });
  afterEach(() => {
    vi.useRealTimers();
  });

  it("(a) get が決まらないまま 5000 ミリ秒たつと、時間切れの例外で失敗する", async () => {
    const never: HttpClient = { get: () => new Promise<HttpResponse>(() => {}) };
    const result = withTimeout(never, 5000).get("https://example.com/a");
    const assertion = expect(result).rejects.toThrow(/時間切れ/);
    await vi.advanceTimersByTimeAsync(5000);
    await assertion;
  });

  it("(c) 4999 ミリ秒で返る応答は、そのまま返る", async () => {
    const slow: HttpClient = {
      get: () => new Promise<HttpResponse>((resolve) => setTimeout(() => resolve({ status: 200, body: "ok" }), 4999)),
    };
    const result = withTimeout(slow, 5000).get("https://example.com/a");
    await vi.advanceTimersByTimeAsync(4999);
    await expect(result).resolves.toEqual({ status: 200, body: "ok" });
    expect(vi.getTimerCount()).toBe(0);
  });
});
