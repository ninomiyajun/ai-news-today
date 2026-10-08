import { describe, expect, it } from "vitest";
import { scoreText, sectionHeadingText, SOURCE_LABELS } from "@/ui/source-labels";

describe("SOURCE_LABELS", () => {
  it("情報源ごとの表示名と単位を持つ", () => {
    expect(SOURCE_LABELS).toEqual({
      "hacker-news": { name: "Hacker News", unit: "点" },
      "hatena-bookmark": { name: "はてなブックマーク", unit: "ブックマーク" },
    });
  });
});

describe("sectionHeadingText", () => {
  it.each([
    ["hacker-news", 3, "Hacker News（3 件）"],
    ["hatena-bookmark", 1, "はてなブックマーク（1 件）"],
  ] as const)("%s の %s 件の見出しは %j", (source, count, expected) => {
    expect(sectionHeadingText(source, count)).toBe(expected);
  });
});

describe("scoreText", () => {
  it.each([
    ["hacker-news", 412, "412 点"],
    ["hatena-bookmark", 156, "156 ブックマーク"],
  ] as const)("%s の点数 %s の文言は %j", (source, score, expected) => {
    expect(scoreText(source, score)).toBe(expected);
  });
});
