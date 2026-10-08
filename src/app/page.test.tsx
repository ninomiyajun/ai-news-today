import { renderToStaticMarkup } from "react-dom/server";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import Home from "@/app/page";

// 画面の全体（組み立て、処理の流れ、表示の部品）を通して、確認用のデータの文言と記事が、確認用のデータのときだけ
// 出ることを確かめる。外部へ通信していないことは、大域の fetch を失敗させて確かめる。
const fetchCalls = vi.hoisted(() => [] as string[]);

beforeEach(() => {
  fetchCalls.length = 0;
  vi.stubGlobal("fetch", async (url: unknown) => {
    fetchCalls.push(String(url));
    throw new Error(`試験の中で fetch を呼びました: ${String(url)}`);
  });
});

afterEach(() => {
  vi.unstubAllGlobals();
  vi.unstubAllEnvs();
});

async function renderHome(): Promise<string> {
  return renderToStaticMarkup(await Home());
}

/** 出力の点数を、表示の順（Hacker News の節、はてなブックマークの節の順）に読み取る。 */
function scoresOf(html: string): number[] {
  return [...html.matchAll(/<small>(\d+) (?:点|ブックマーク)<\/small>/g)].map((m) => Number(m[1]));
}

describe("画面（確認用のデータ）", () => {
  it("AI_NEWS_FIXTURE=sample のとき、文言と決まった記事を節ごとに点数の高い順に出し、外部へ通信しない", async () => {
    vi.stubEnv("AI_NEWS_FIXTURE", "sample");
    const html = await renderHome();
    expect(html).toContain("確認用のデータで表示中");
    expect(scoresOf(html)).toEqual([412, 88, 156, 37]);
    expect(html).not.toContain("表示されない");
    expect(fetchCalls).toEqual([]);
  });

  it("AI_NEWS_FIXTURE が無いとき、文言を出さず、記事も出さない", async () => {
    vi.stubEnv("AI_NEWS_FIXTURE", undefined);
    const html = await renderHome();
    expect(html).not.toContain("確認用のデータで表示中");
    expect(html).toContain("表示できる記事はまだありません。");
  });

  it.each([
    ["(a)", { min: "100" }, [412, 156], "点数 100 以上を表示中"],
    ["(b)", { min: "88" }, [412, 88, 156], "点数 88 以上を表示中"],
    ["(c)", { min: "abc" }, [412, 88, 156, 37], null],
    ["(d)", {}, [412, 88, 156, 37], null],
    ["(f)", { min: "0" }, [412, 88, 156, 37], "点数 0 以上を表示中"],
    ["(g)", { min: "088" }, [412, 88, 156], "点数 88 以上を表示中"],
  ] as const)("%s クエリ %j で、点数 %j の記事と下限の文言を出し、外部へ通信しない", async (_label, query, expected, notice) => {
    vi.stubEnv("AI_NEWS_FIXTURE", "sample");
    const html = renderToStaticMarkup(await Home({ searchParams: Promise.resolve(query) }));
    expect(scoresOf(html)).toEqual(expected);
    if (notice === null) {
      expect(html).not.toContain("以上を表示中");
    } else {
      expect(html).toContain(notice);
    }
    expect(fetchCalls).toEqual([]);
  });

  it("(e) 引数なしで呼ぶと、4 件を出し、下限の文言を出さない", async () => {
    vi.stubEnv("AI_NEWS_FIXTURE", "sample");
    const html = await renderHome();
    expect(scoresOf(html)).toEqual([412, 88, 156, 37]);
    expect(html).not.toContain("以上を表示中");
    expect(fetchCalls).toEqual([]);
  });

  it("NODE_ENV=production のときは、AI_NEWS_FIXTURE=sample でも文言を出さない", async () => {
    vi.stubEnv("AI_NEWS_FIXTURE", "sample");
    vi.stubEnv("NODE_ENV", "production");
    const html = await renderHome();
    expect(html).not.toContain("確認用のデータで表示中");
    expect(html).not.toContain("[確認用]");
  });
});
