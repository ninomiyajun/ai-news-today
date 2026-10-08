import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { systemClock } from "@/ports/clock";
import { createRuntimeDeps, createXPostDeps, isFixtureMode } from "@/composition/runtime";
import { getTodayNews } from "@/services/today-news";
import { getXPostsByItem } from "@/services/x-posts";
import { xOEmbedRequestUrl } from "@/sources/x-oembed";
import { FIXTURE_NOW } from "@/sources/fixture";

// 本物の HTTP の入口（fetchHttpClient）を、呼ぶと失敗する差し替えにする。確認用のデータのときに外部へ HTTP を
// 出さないことを、この差し替えが一度も呼ばれないことで確かめる。
const realHttpCalls = vi.hoisted(() => [] as string[]);
vi.mock("@/ports/http", async (importOriginal) => {
  const original = await importOriginal<typeof import("@/ports/http")>();
  return {
    ...original,
    fetchHttpClient: {
      get: async (url: string) => {
        realHttpCalls.push(url);
        throw new Error(`試験の中で外部へ HTTP を出そうとしました: ${url}`);
      },
    },
  };
});

const FIXTURE_DEV = { AI_NEWS_FIXTURE: "sample", NODE_ENV: "development" };

beforeEach(() => {
  realHttpCalls.length = 0;
  // fetch を直接呼ぶ経路が増えても気づけるよう、大域の fetch も失敗させる。
  vi.stubGlobal("fetch", async (url: unknown) => {
    realHttpCalls.push(String(url));
    throw new Error(`試験の中で fetch を呼びました: ${String(url)}`);
  });
});

afterEach(() => {
  vi.unstubAllGlobals();
  vi.unstubAllEnvs();
});

describe("isFixtureMode（確認用のデータの判定）", () => {
  it("AI_NEWS_FIXTURE=sample で NODE_ENV=development なら真", () => {
    expect(isFixtureMode(FIXTURE_DEV)).toBe(true);
  });

  it("AI_NEWS_FIXTURE=sample でも NODE_ENV=production なら偽", () => {
    expect(isFixtureMode({ AI_NEWS_FIXTURE: "sample", NODE_ENV: "production" })).toBe(false);
  });

  it("AI_NEWS_FIXTURE が無ければ偽", () => {
    expect(isFixtureMode({ NODE_ENV: "development" })).toBe(false);
  });

  it("AI_NEWS_FIXTURE が sample 以外の値なら偽", () => {
    expect(isFixtureMode({ AI_NEWS_FIXTURE: "1", NODE_ENV: "development" })).toBe(false);
  });

  // 直接の参照 process.env.NODE_ENV は、本番の build ではビルドの時点の production に固定される。
  // ここでは、その値が production のときを stubEnv で作り、引数の NODE_ENV が development でも偽になることを確かめる
  // （本番の build を NODE_ENV=development を付けて next start した場合に当たる）。
  it("引数の NODE_ENV が development でも、直接の参照の NODE_ENV が production なら偽", () => {
    vi.stubEnv("NODE_ENV", "production");
    expect(isFixtureMode(FIXTURE_DEV)).toBe(false);
  });

  it("直接の参照の NODE_ENV が production でなく、引数も条件を満たすなら真", () => {
    vi.stubEnv("NODE_ENV", "development");
    expect(isFixtureMode(FIXTURE_DEV)).toBe(true);
  });
});

describe("確認用のデータのとき", () => {
  it("決まった時刻を使う", () => {
    expect(createRuntimeDeps(FIXTURE_DEV).clock.now().toISOString()).toBe(new Date(FIXTURE_NOW).toISOString());
  });

  it("getTodayNews は決まった記事を点数の高い順に返し、選別で落ちる記事を含めない", async () => {
    const items = await getTodayNews(createRuntimeDeps(FIXTURE_DEV));
    expect(items.map((i) => i.score)).toEqual([412, 156, 88, 37]);
    expect(new Set(items.map((i) => i.source))).toEqual(new Set(["hacker-news", "hatena-bookmark"]));
  });

  it("getTodayNews と getXPostsByItem が外部へ HTTP を出さない", async () => {
    const items = await getTodayNews(createRuntimeDeps(FIXTURE_DEV));
    const xDeps = createXPostDeps(FIXTURE_DEV);
    const requested: string[] = [];
    const xPosts = await getXPostsByItem(items, {
      http: {
        get: (url) => {
          requested.push(url);
          return xDeps.http.get(url);
        },
      },
    });
    // 確認用の記事には X の投稿の URL が無いので、oEmbed への要求そのものが無い
    expect(requested).toEqual([]);
    expect(Object.values(xPosts).flat()).toEqual([]);
    expect(realHttpCalls).toEqual([]);
  });

  it("X の埋め込みの依存は、来た要求に外へ出ずに失敗の応答を返す", async () => {
    const res = await createXPostDeps(FIXTURE_DEV).http.get(xOEmbedRequestUrl("https://x.com/a/status/1"));
    expect(res.status).toBe(404);
    expect(realHttpCalls).toEqual([]);
  });
});

describe("確認用のデータでないとき", () => {
  // 通常の経路に情報源を足すと、この試験が落ちる。期待値を直す前に、確認用のデータの経路（src/sources/fixture.ts と
  // createRuntimeDeps の確認用の分岐）にも、足した情報源への対応を足す（docs/adr/0004-fixture-data-for-acceptance.md）。
  it("情報源は空で、本物の時計を使う（情報源を足したら、確認用の経路にも対応を足す）", () => {
    const deps = createRuntimeDeps({ NODE_ENV: "production", AI_NEWS_FIXTURE: "sample" });
    expect(deps.sources).toEqual([]);
    expect(deps.clock).toBe(systemClock);
  });

  it("X の埋め込みの依存は本物の HTTP の入口を使う", async () => {
    await expect(
      createXPostDeps({ NODE_ENV: "development" }).http.get(xOEmbedRequestUrl("https://x.com/a/status/1")),
    ).rejects.toThrow("外部へ HTTP を出そうとしました");
    expect(realHttpCalls).toHaveLength(1);
  });
});
