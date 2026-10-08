import { renderToStaticMarkup } from "react-dom/server";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import Home from "@/app/page";
import type { NewsItem, NewsSourceId } from "@/domain/news";
import type { TodayNewsDeps } from "@/services/today-news";
import type { XPostDeps } from "@/services/x-posts";

// 製品の仕様 docs/product-specs/news-by-source.md の受け入れ基準のうち、確認用のデータに前提の記事が無いもの
// （SRC-2〜SRC-9、SRC-11〜SRC-13）を、画面の全体（Home）を通して確かめる（計画 2026-10-08-news-by-source の検証の節）。
// 組み立ての層だけを差し替え、getTodayNews、selectRecent、点数の下限の絞り込み、節に分ける処理、表示の部品は本物が動く。
// 情報源、時計、HTTP の入口は、型が合うオブジェクトをこのファイルの中に書く（画面の層からは src/sources/ と src/ports/ を
// import できないため）。

/** 試験の決まった時刻（日本時間の 2026-10-07 12 時）。記事の公開日時は、これより前の 24 時間に収める。 */
const NOW = "2026-10-07T03:00:00Z";
/** 仕様の「9 時」「11 時」「8 時」（日本時間） */
const JST_9 = "2026-10-07T00:00:00Z";
const JST_11 = "2026-10-07T02:00:00Z";
const JST_8 = "2026-10-06T23:00:00Z";

const state = vi.hoisted(() => ({ items: [] as NewsItem[], fetchCalls: [] as string[], httpCalls: [] as string[] }));

vi.mock("@/composition/runtime", () => ({
  createRuntimeDeps: (): TodayNewsDeps => ({
    sources: [{ name: "test", fetchItems: async () => state.items.map((item) => ({ ...item })) }],
    clock: { now: () => new Date(NOW) },
  }),
  createXPostDeps: (): XPostDeps => ({
    http: {
      get: async (url: string) => {
        state.httpCalls.push(url);
        return { status: 200, body: '{"type":"rich","author_name":"A"}' };
      },
    },
  }),
  isFixtureMode: () => false,
}));

beforeEach(() => {
  state.items = [];
  state.fetchCalls.length = 0;
  state.httpCalls.length = 0;
  vi.stubGlobal("fetch", async (url: unknown) => {
    state.fetchCalls.push(String(url));
    throw new Error(`試験の中で fetch を呼びました: ${String(url)}`);
  });
});

afterEach(() => {
  vi.unstubAllGlobals();
  expect(state.fetchCalls).toEqual([]);
});

let seq = 0;
function item(source: NewsSourceId, score: number, opts: { title?: string; at?: string; text?: string } = {}): NewsItem {
  seq += 1;
  return {
    id: `${source}:${seq}`,
    title: opts.title ?? `${source}-${score}-${seq}`,
    url: `https://example.com/${seq}`,
    source,
    score,
    publishedAt: new Date(opts.at ?? JST_9),
    ...(opts.text === undefined ? {} : { text: opts.text }),
  };
}

async function render(min?: string): Promise<string> {
  const props = min === undefined ? undefined : { searchParams: Promise.resolve({ min }) };
  return renderToStaticMarkup(await Home(props));
}

type ParsedSection = { heading: string; scores: number[]; titles: string[]; html: string };

/** 出力から、節（<section> から </section> まで）ごとに、見出しの文字列、点数の数、記事の題を、上から順に読み取る。 */
function sectionsOf(html: string): ParsedSection[] {
  return [...html.matchAll(/<section[^>]*>(.*?)<\/section>/g)].map((m) => {
    const body = m[1];
    return {
      heading: body.match(/<h2[^>]*>(.*?)<\/h2>/)?.[1] ?? "",
      scores: [...body.matchAll(/<small>(\d+) [^<]*<\/small>/g)].map((s) => Number(s[1])),
      titles: [...body.matchAll(/<a [^>]*>([^<]*)<\/a> <small>/g)].map((a) => a[1]),
      html: body,
    };
  });
}

function count(html: string, needle: string): number {
  return html.split(needle).length - 1;
}

describe("情報源ごとの節（仕様 news-by-source の自動テストの基準）", () => {
  it("SRC-2 節の見出しは、情報源の名前と記事の件数を出す", async () => {
    state.items = [
      item("hacker-news", 300),
      item("hacker-news", 200),
      item("hacker-news", 100),
      item("hatena-bookmark", 50),
    ];
    const sections = sectionsOf(await render());
    expect(sections.map((s) => s.heading)).toEqual(["Hacker News（3 件）", "はてなブックマーク（1 件）"]);
  });

  it("SRC-3 節の中は点数の高い順に並ぶ", async () => {
    state.items = [
      item("hacker-news", 88),
      item("hacker-news", 412),
      item("hacker-news", 37),
      item("hatena-bookmark", 37),
      item("hatena-bookmark", 156),
    ];
    const sections = sectionsOf(await render());
    expect(sections.map((s) => s.scores)).toEqual([
      [412, 88, 37],
      [156, 37],
    ]);
  });

  it("SRC-4 X の投稿の埋め込みは、節の中でも元の記事の下に出る", async () => {
    state.items = [
      item("hacker-news", 412, { title: "hn" }),
      item("hatena-bookmark", 156, { title: "hb-x", text: "投稿 https://x.com/a/status/1 を参照" }),
      item("hatena-bookmark", 37, { title: "hb-plain" }),
    ];
    const html = await render();
    expect(count(html, '<blockquote class="twitter-tweet"')).toBe(1);
    const [hn, hb] = sectionsOf(html);
    expect(hn.heading).toBe("Hacker News（1 件）");
    expect(hn.html).not.toContain("<blockquote");
    expect(hb.heading).toBe("はてなブックマーク（2 件）");
    const lis = [...hb.html.matchAll(/<li>(.*?)<\/li>/g)].map((m) => m[1]);
    const withEmbed = lis.filter((li) => li.includes('<blockquote class="twitter-tweet"'));
    expect(withEmbed).toHaveLength(1);
    expect(withEmbed[0]).toContain(">hb-x</a>");
    expect(withEmbed[0]).toContain('href="https://x.com/a/status/1"');
  });

  it("SRC-5 Hacker News の節が、はてなブックマークの節より先に出る", async () => {
    state.items = [
      item("hatena-bookmark", 156),
      item("hatena-bookmark", 88),
      item("hatena-bookmark", 37),
      item("hacker-news", 12),
    ];
    const sections = sectionsOf(await render());
    expect(sections.map((s) => s.heading)).toEqual(["Hacker News（1 件）", "はてなブックマーク（3 件）"]);
  });

  it("SRC-6 記事が 0 件の情報源の節は出ない", async () => {
    state.items = [item("hacker-news", 412), item("hacker-news", 88)];
    const html = await render();
    expect(count(html, "<section")).toBe(1);
    expect(sectionsOf(html)[0].heading).toBe("Hacker News（2 件）");
    expect(html).not.toContain("はてなブックマーク");
    expect(html).not.toContain("表示できる記事はまだありません。");
  });

  it("SRC-7 点数の下限で絞り込んだ結果 0 件になった情報源の節は出ない", async () => {
    state.items = [item("hacker-news", 412), item("hacker-news", 88), item("hatena-bookmark", 37)];
    const html = await render("100");
    expect(count(html, "<section")).toBe(1);
    expect(sectionsOf(html).map((s) => s.scores)).toEqual([[412]]);
    expect(html).not.toContain("はてなブックマーク");
    expect(html).not.toContain("表示できる記事はまだありません。");
  });

  it("SRC-8 すべての情報源の記事が 0 件のときは、空の文言の 1 文だけが出る", async () => {
    state.items = [];
    const html = await render();
    expect(count(html, "表示できる記事はまだありません。")).toBe(1);
    expect(html).not.toContain("<section");
    expect(html).not.toContain("<h2");
  });

  it("SRC-9 点数の下限で絞り込んだ結果すべてが 0 件のときも、空の文言の 1 文だけが出る", async () => {
    state.items = [item("hacker-news", 88), item("hatena-bookmark", 37)];
    const html = await render("100");
    expect(count(html, "表示できる記事はまだありません。")).toBe(1);
    expect(html).not.toContain("<section");
    expect(html).not.toContain("<h2");
  });

  it("SRC-11 点数の下限で絞り込んだときの見出しの件数は、絞り込んだ後の記事の数になる", async () => {
    state.items = [
      item("hacker-news", 412),
      item("hacker-news", 150),
      item("hacker-news", 88),
      item("hatena-bookmark", 156),
      item("hatena-bookmark", 37),
    ];
    const sections = sectionsOf(await render("100"));
    expect(sections.map((s) => s.heading)).toEqual(["Hacker News（2 件）", "はてなブックマーク（1 件）"]);
  });

  it("SRC-12 同じ節で点数が同じ記事は、公開日時の新しい順に並ぶ", async () => {
    state.items = [
      item("hacker-news", 88, { title: "88-9時", at: JST_9 }),
      item("hacker-news", 88, { title: "88-11時", at: JST_11 }),
      item("hacker-news", 412, { title: "412-8時", at: JST_8 }),
    ];
    const sections = sectionsOf(await render());
    expect(sections).toHaveLength(1);
    expect(sections[0].titles).toEqual(["412-8時", "88-11時", "88-9時"]);
  });

  it("SRC-13 記事ごとの点数に、情報源に合わせた単位が付く", async () => {
    state.items = [item("hacker-news", 412), item("hatena-bookmark", 156)];
    const html = await render();
    expect(html).toContain("412 点");
    expect(html).toContain("156 ブックマーク");
    expect(html).not.toContain("(412)");
    expect(html).not.toContain("(156)");
  });

  it("V8 X の投稿の問い合わせの上限 10 件は、表示の順（節の順、節の中の順）の先頭の記事から当てる", async () => {
    // 全体の点数の順（はてなブックマークの 6 件が先）と、表示の順（Hacker News の節の 6 件が先）が異なる 12 件。
    // 記事ごとに別々の X の投稿の URL を持たせる。投稿の番号は、その記事の点数と同じにする。
    const hn = [60, 50, 40, 30, 20, 10];
    const hb = [600, 500, 400, 300, 200, 100];
    const post = (n: number) => `https://x.com/a/status/${n}`;
    state.items = [
      ...hn.map((score) => item("hacker-news", score, { text: `投稿 ${post(score)}` })),
      ...hb.map((score) => item("hatena-bookmark", score, { text: `投稿 ${post(score)}` })),
    ];
    const html = await render();
    const asked = state.httpCalls.map((u) => new URL(u).searchParams.get("url"));
    // 表示の順の先頭 10 件（Hacker News の 6 件と、はてなブックマークの上の 4 件）だけを問い合わせる。
    expect([...asked].sort()).toEqual([...hn, 600, 500, 400, 300].map(post).sort());
    // 11 件目以降（はてなブックマークの 200 と 100）は問い合わせない。節に分ける前の記事（全体の点数の順）を渡すと、
    // 代わりに Hacker News の 20 と 10 が外れるので、この試験が落ちる。
    expect(asked).not.toContain(post(200));
    expect(asked).not.toContain(post(100));
    expect(asked).toContain(post(20));
    expect(asked).toContain(post(10));
    expect(count(html, '<blockquote class="twitter-tweet"')).toBe(10);
  });
});
