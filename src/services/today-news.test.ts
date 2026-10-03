import { describe, expect, it } from "vitest";
import { fixedClock } from "@/ports/clock";
import { staticSource } from "@/sources/source";
import { getTodayNews } from "@/services/today-news";

describe("getTodayNews", () => {
  it("決まった時計と決まった情報源で、結果が決まる", async () => {
    const source = staticSource("fixture", [
      {
        id: "1",
        title: "fresh",
        url: "https://example.com/1",
        source: "hatena-bookmark",
        score: 3,
        publishedAt: new Date("2026-10-03T08:00:00Z"),
      },
      {
        id: "2",
        title: "stale",
        url: "https://example.com/2",
        source: "hacker-news",
        score: 300,
        publishedAt: new Date("2026-09-30T08:00:00Z"),
      },
    ]);
    const items = await getTodayNews({ sources: [source], clock: fixedClock("2026-10-03T12:00:00Z") });
    expect(items.map((i) => i.title)).toEqual(["fresh"]);
  });
});
