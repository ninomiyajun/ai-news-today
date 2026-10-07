import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { FIXTURE_NOTICE_TEXT, FixtureNotice } from "@/ui/FixtureNotice";

describe("FixtureNotice（確認用のデータの表示）", () => {
  it("文言は「確認用のデータで表示中」である", () => {
    expect(FIXTURE_NOTICE_TEXT).toBe("確認用のデータで表示中");
  });

  it("確認用のデータのときは文言を出し、環境変数の名前は出さない", () => {
    const html = renderToStaticMarkup(<FixtureNotice active />);
    expect(html).toContain("確認用のデータで表示中");
    expect(html).not.toContain("AI_NEWS_FIXTURE");
  });

  it("確認用のデータでないときは何も出さない", () => {
    expect(renderToStaticMarkup(<FixtureNotice active={false} />)).toBe("");
  });
});
