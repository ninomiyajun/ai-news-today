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

describe("画面（確認用のデータ）", () => {
  it("AI_NEWS_FIXTURE=sample のとき、文言と決まった記事を点数の高い順に出し、外部へ通信しない", async () => {
    vi.stubEnv("AI_NEWS_FIXTURE", "sample");
    const html = await renderHome();
    expect(html).toContain("確認用のデータで表示中");
    const scores = [...html.matchAll(/<small>\((\d+)\)<\/small>/g)].map((m) => Number(m[1]));
    expect(scores).toEqual([412, 156, 88, 37]);
    expect(html).not.toContain("表示されない");
    expect(fetchCalls).toEqual([]);
  });

  it("AI_NEWS_FIXTURE が無いとき、文言を出さず、記事も出さない", async () => {
    vi.stubEnv("AI_NEWS_FIXTURE", undefined);
    const html = await renderHome();
    expect(html).not.toContain("確認用のデータで表示中");
    expect(html).toContain("表示できる記事はまだありません。");
  });

  it("NODE_ENV=production のときは、AI_NEWS_FIXTURE=sample でも文言を出さない", async () => {
    vi.stubEnv("AI_NEWS_FIXTURE", "sample");
    vi.stubEnv("NODE_ENV", "production");
    const html = await renderHome();
    expect(html).not.toContain("確認用のデータで表示中");
    expect(html).not.toContain("[確認用]");
  });
});
