import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
// src/ の下へ写したら、既存の試験と同じ "@/<層の名前>/<ファイルの名前>" の形に直す（templates/module/README.md）
import { ExampleLabel } from "./ExampleLabel";

describe("ExampleLabel（表示の部品のひな形）", () => {
  it("受け取った文字を表示する", () => {
    expect(renderToStaticMarkup(<ExampleLabel text="見本" />)).toBe("<p>見本</p>");
  });
});
