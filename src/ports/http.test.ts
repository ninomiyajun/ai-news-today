import { describe, expect, it } from "vitest";
import { fixtureHttpClient } from "@/ports/http";

describe("fixtureHttpClient", () => {
  it("登録した URL には決まった応答を、それ以外には 404 を返す", async () => {
    const http = fixtureHttpClient({ "https://example.com/a": { status: 200, body: "ok" } });
    expect(await http.get("https://example.com/a")).toEqual({ status: 200, body: "ok" });
    expect((await http.get("https://example.com/b")).status).toBe(404);
  });
});
