import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { MinScoreNotice } from "@/ui/MinScoreNotice";

describe("MinScoreNotice（点数の下限の表示）", () => {
  it("下限が無いときは何も出さない", () => {
    expect(renderToStaticMarkup(<MinScoreNotice minScore={null} />)).toBe("");
  });

  it("下限が 100 のときは「点数 100 以上を表示中」を出す", () => {
    expect(renderToStaticMarkup(<MinScoreNotice minScore={100} />)).toContain("点数 100 以上を表示中");
  });

  it("下限が 0 のときも「点数 0 以上を表示中」を出す", () => {
    expect(renderToStaticMarkup(<MinScoreNotice minScore={0} />)).toContain("点数 0 以上を表示中");
  });
});
