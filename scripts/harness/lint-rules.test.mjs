// ESLint の規則（eslint.config.mjs）が、区画（files ごとの設定）ごとに実際に働いていることを確かめる試験。
// 手元と CI で同じコマンドを使う: npm run test:harness（check-docs.test.sh と notify.test.sh の後に動く）
//
// 確かめること: ARCHITECTURE.md の不変条件 1、2、5 に当たる規則（通信のための大域の名前、現在時刻、通信のための
// モジュールの import・require()・import()、next/script の import・require()・import()、JSX の script 要素）について、
// 3 つの区画（通常の src/ の下、src/ports/ の下、src/ui/XPostEmbed.tsx）のそれぞれで、効くはずの規則が違反の見本を
// 検出し、対象外のはずの規則が検出しないこと。あわせて、外から受け取った HTML を文字列のまま画面に入れる書き方
// （JSX の属性 dangerouslySetInnerHTML と srcDoc、オブジェクトに書いた dangerouslySetInnerHTML と srcDoc という名前の
// プロパティ、innerHTML、outerHTML、srcdoc への代入、insertAdjacentHTML、setHTMLUnsafe、createContextualFragment の呼び出し、
// document.write と document.writeln の呼び出し。
// ARCHITECTURE.md の「将来の作りの注意」の、oEmbed の応答の html の項）を、3 つの区画のすべてで拒否すること。
//
// この試験がある理由: ESLint の設定は、同じ規則を別の区画に足すと、後の設定が前の設定を置き換える。前からある規則が
// 知らせなしに無効になっても、npm run lint は通ってしまう（由来は docs/harness-log.md）。
//
// あわせて、eslint.config.mjs で対象の 4 つの規則（TARGET_RULES）を持つ区画の一覧（files、ignores、規則の名前）が、
// この試験の見込み（EXPECTED_BLOCKS）と一致することを確かめる。見本のファイルの名前が当たらない場所を指す区画
// （例: src/sources/** だけの区画）を足されると、その場所で規則が消えても、見本の確認だけでは気づけないためである。
//
// この試験が守れる範囲: 下の SAMPLES と EXPECTED_BLOCKS に書いた形だけである。次の形は守れない。
// - 別名を経由した書き方（const g = globalThis; g.fetch(...)、モジュールの名前を変数で組み立てた import()、
//   React.createElement("script")、{...props} の展開で dangerouslySetInnerHTML を渡す形、const d = document; d.write(...)、
//   名前を変数で組み立てたプロパティ（el[key] = ...）、Object.assign での書き込み、DOMParser などの別の入口など）。ESLint の規則が検出しないので、この試験でも守れない。ARCHITECTURE.md の
//   不変条件に書いたとおり、レビューで人が確かめる。
// - 後の区画で制限を並べ直すときに、一部の項目だけを落とす誤り。検出できるのは、見本にある項目だけである
//   （通信のためのモジュール 13 個のうち、見本は node:http、https、undici、node:https、net の 5 個。globalThis.、window.、
//   self. を付けた大域の名前 12 組のうち、見本は 3 組）。見本に無い項目は、設定を変えるレビューで人が確かめる。
// - eslint.config.mjs の対象の拡張子を増やしたとき。この試験の拡張子の一覧（EXTENSIONS）に、手で足す必要がある
//   （files の文字列が変わるので、区画の一覧の確認は失敗して知らせるが、新しい拡張子の見本は自動では増えない）。
// - 区画の一覧に現れない方法で、規則を外す形。全体の ignores（globalIgnores）に src/ の下を足す、ファイルの中に
//   ESLint の無効化のコメントを書く、npm run lint のコマンドの引数で設定を変える、など。
// - 対象の 4 つの規則と違う名前の規則（プラグインの同じ働きの規則など）に置き換える形のうち、名前の末尾が
//   対象の規則と同じでないもの。
//
// 作り:
// - 見本のコードは、この試験の中に文字列で持つ。src/ の下の実際のファイルの中身は読まない（ESLint の lintText に、
//   区画を決めるためのファイルの名前だけを渡す）。
// - 判定は、規則の名前（ruleId）と、メッセージに含まれる目印の文字列の両方で絞る。Next.js の規則など、対象の規則の
//   外の検出で結果が変わらないようにするためである。
// - 試験そのものの試験として、現在の設定で確認が通ること（通る見本）と、規則を知らせなしに無効にする設定や、
//   対象外の区画へ広げる設定を重ねると、確認が失敗を返すこと（失敗する見本）を確かめる。
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { ESLint } from "eslint";
import eslintConfig from "../../eslint.config.mjs";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../..");

// 対象の規則と、その規則を持つ区画の見込み（eslint.config.mjs に書いた順）。
// 区画を足す・変えるときは、ここに足して、下の ZONES と SAMPLES に、その区画での見込みを書く。
// eslint-config-next の側の設定は、対象の規則を 1 つも持たない（2026-10-14 に、設定の配列を読んで確かめた）。
// 持つようになったら、この確認が「見込みに無い区画」として知らせるので、その区画をここに足して見込みを書く。
const TARGET_RULES = ["no-restricted-globals", "no-restricted-properties", "no-restricted-imports", "no-restricted-syntax"];
const SRC_GLOB = "src/**/*.{ts,tsx,js,jsx,mjs,cjs,mts,cts}";
const EXPECTED_BLOCKS = [
  { files: [SRC_GLOB], ignores: ["src/ports/**"], rules: [...TARGET_RULES].sort() },
  { files: ["src/ui/XPostEmbed.tsx"], ignores: [], rules: ["no-restricted-imports"] },
  { files: ["src/ports/**/*.{ts,tsx,js,jsx,mjs,cjs,mts,cts}"], ignores: [], rules: ["no-restricted-imports", "no-restricted-syntax"] },
];

// 区画。file は、JSX を含まない見本に使うファイルの名前、jsxFile は、JSX を含む見本に使うファイルの名前。
// どちらも区画を決めるためだけの名前で、src/ui/XPostEmbed.tsx の他は実在しなくてよい。
const ZONES = {
  general: {
    label: "通常の src/ の下（src/ports/ と src/ui/XPostEmbed.tsx の他）",
    file: "src/services/lint-rules-sample.ts",
    jsxFile: "src/app/lint-rules-sample.tsx",
  },
  ports: {
    label: "src/ports/ の下",
    file: "src/ports/lint-rules-sample.ts",
    jsxFile: "src/ports/lint-rules-sample.tsx",
  },
  owner: {
    label: "src/ui/XPostEmbed.tsx（外部のスクリプトを読み込んでよい、ただ 1 つのファイル）",
    file: "src/ui/XPostEmbed.tsx",
    jsxFile: "src/ui/XPostEmbed.tsx",
  },
};

// メッセージの目印。eslint.config.mjs のメッセージのうち、不変条件 1、2 のものは「src/ports/ の HttpClient と Clock を…」を、
// 不変条件 5 のものは「不変条件 5」を含む。
const PORTS_MARK = "src/ports/";
const SCRIPT_MARK = "不変条件 5";
// HTML の制限のメッセージは「oEmbed の応答の html の項」を含む。
const HTML_MARK = "oEmbed の応答の html の項";

// 区画ごとの見込み。true は「検出するはず」、false は「検出しないはず」。
const PORTS_ONLY = { general: true, ports: false, owner: true }; // 不変条件 1、2: src/ports/ の外でだけ拒否する
const SCRIPT_IMPORT = { general: true, ports: true, owner: false }; // 不変条件 5: 持ち主のファイルでだけ import を許す
const EVERYWHERE = { general: true, ports: true, owner: true }; // 不変条件 5: src/ の下のすべてで拒否する
const NOWHERE = { general: false, ports: false, owner: false }; // 規則の対象でない書き方

const sample = (name, code, ruleId, mark, expected, jsx = false) => ({ name, code, ruleId, mark, expected, jsx });

const SAMPLES = [
  // 不変条件 1: 通信のための大域の名前
  sample("fetch の呼び出し", 'export const r = fetch("https://example.com/");', "no-restricted-globals", PORTS_MARK, PORTS_ONLY),
  sample("WebSocket の生成", 'export const r = new WebSocket("wss://example.com/");', "no-restricted-globals", PORTS_MARK, PORTS_ONLY),
  sample("XMLHttpRequest の生成", "export const r = new XMLHttpRequest();", "no-restricted-globals", PORTS_MARK, PORTS_ONLY),
  sample("EventSource の生成", 'export const r = new EventSource("https://example.com/");', "no-restricted-globals", PORTS_MARK, PORTS_ONLY),
  sample("globalThis.fetch の呼び出し", 'export const r = globalThis.fetch("https://example.com/");', "no-restricted-properties", PORTS_MARK, PORTS_ONLY),
  sample("window.WebSocket の生成", 'export const r = new window.WebSocket("wss://example.com/");', "no-restricted-properties", PORTS_MARK, PORTS_ONLY),
  sample("self.EventSource の生成", 'export const r = new self.EventSource("https://example.com/");', "no-restricted-properties", PORTS_MARK, PORTS_ONLY),
  // 不変条件 1: 現在時刻
  sample("Date.now() の呼び出し", "export const r = Date.now();", "no-restricted-properties", PORTS_MARK, PORTS_ONLY),
  sample("Temporal.Now の利用", "export const r = Temporal.Now.instant();", "no-restricted-properties", PORTS_MARK, PORTS_ONLY),
  sample("引数の無い new Date()", "export const r = new Date();", "no-restricted-syntax", PORTS_MARK, PORTS_ONLY),
  sample("new を付けない Date()", "export const r = Date();", "no-restricted-syntax", PORTS_MARK, PORTS_ONLY),
  sample("引数のある new Date(0)（現在時刻ではない）", "export const r = new Date(0);", "no-restricted-syntax", PORTS_MARK, NOWHERE),
  sample("new Date(undefined)（現在時刻ではない）", "export const r = new Date(undefined);", "no-restricted-syntax", PORTS_MARK, NOWHERE),
  sample("performance.now()（現在時刻ではない）", "export const r = performance.now();", "no-restricted-properties", PORTS_MARK, NOWHERE),
  // 不変条件 2: 通信のためのモジュール
  sample("通信のモジュールの import（node:http）", 'import http from "node:http";\nexport const r = http;', "no-restricted-imports", PORTS_MARK, PORTS_ONLY),
  sample("通信のモジュールの import（https）", 'import https from "https";\nexport const r = https;', "no-restricted-imports", PORTS_MARK, PORTS_ONLY),
  sample("通信のモジュールの import（undici）", 'import { request } from "undici";\nexport const r = request;', "no-restricted-imports", PORTS_MARK, PORTS_ONLY),
  sample("通信のモジュールの require()（node:https）", 'export const r = require("node:https");', "no-restricted-syntax", PORTS_MARK, PORTS_ONLY),
  sample("通信のモジュールの import()（net）", 'export const r = () => import("net");', "no-restricted-syntax", PORTS_MARK, PORTS_ONLY),
  sample("通信のモジュールでない import（node:path）", 'import path from "node:path";\nexport const r = path;', "no-restricted-imports", PORTS_MARK, NOWHERE),
  // 不変条件 5: 外部のスクリプト
  sample("next/script の import", 'import Script from "next/script";\nexport const r = Script;', "no-restricted-imports", SCRIPT_MARK, SCRIPT_IMPORT),
  sample("next/script の require()", 'export const r = require("next/script");', "no-restricted-syntax", SCRIPT_MARK, EVERYWHERE),
  sample("next/script の import()", 'export const r = () => import("next/script");', "no-restricted-syntax", SCRIPT_MARK, EVERYWHERE),
  sample("JSX の script 要素", 'export const r = <script src="https://example.com/a.js" />;', "no-restricted-syntax", SCRIPT_MARK, EVERYWHERE, true),
  sample("JSX の script でない要素", "export const r = <div />;", "no-restricted-syntax", SCRIPT_MARK, NOWHERE, true),
  // 外から受け取った HTML を文字列のまま画面に入れる書き方（ARCHITECTURE.md の「将来の作りの注意」）
  sample("JSX の属性 dangerouslySetInnerHTML", 'export const r = (html: string) => <div dangerouslySetInnerHTML={{ __html: html }} />;', "no-restricted-syntax", HTML_MARK, EVERYWHERE, true),
  sample("オブジェクトのプロパティ dangerouslySetInnerHTML", 'export const r = { dangerouslySetInnerHTML: { __html: "<b>x</b>" } };', "no-restricted-syntax", HTML_MARK, EVERYWHERE),
  sample("文字列の名前のプロパティ \"dangerouslySetInnerHTML\"", 'export const r = { "dangerouslySetInnerHTML": { __html: "<b>x</b>" } };', "no-restricted-syntax", HTML_MARK, EVERYWHERE),
  sample("innerHTML への代入", 'export const r = (el: HTMLElement) => { el.innerHTML = "<b>x</b>"; };', "no-restricted-syntax", HTML_MARK, EVERYWHERE),
  sample("innerHTML への += の代入", 'export const r = (el: HTMLElement) => { el.innerHTML += "<b>x</b>"; };', "no-restricted-syntax", HTML_MARK, EVERYWHERE),
  sample("outerHTML への代入", 'export const r = (el: HTMLElement) => { el.outerHTML = "<b>x</b>"; };', "no-restricted-syntax", HTML_MARK, EVERYWHERE),
  sample("el[\"innerHTML\"] への代入", 'export const r = (el: HTMLElement) => { el["innerHTML"] = "<b>x</b>"; };', "no-restricted-syntax", HTML_MARK, EVERYWHERE),
  sample("insertAdjacentHTML の呼び出し", 'export const r = (el: HTMLElement) => el.insertAdjacentHTML("beforeend", "<b>x</b>");', "no-restricted-syntax", HTML_MARK, EVERYWHERE),
  sample("document.write の呼び出し", 'export const r = () => document.write("<b>x</b>");', "no-restricted-syntax", HTML_MARK, EVERYWHERE),
  sample("document.writeln の呼び出し", 'export const r = () => document.writeln("<b>x</b>");', "no-restricted-syntax", HTML_MARK, EVERYWHERE),
  sample("名前を文字列で書いた el[\"insertAdjacentHTML\"] の呼び出し", 'export const r = (el: HTMLElement) => el["insertAdjacentHTML"]("beforeend", "<b>x</b>");', "no-restricted-syntax", HTML_MARK, EVERYWHERE),
  sample("setHTMLUnsafe の呼び出し", 'export const r = (el: HTMLElement) => el.setHTMLUnsafe("<b>x</b>");', "no-restricted-syntax", HTML_MARK, EVERYWHERE),
  sample("createContextualFragment の呼び出し", 'export const r = (range: Range) => range.createContextualFragment("<b>x</b>");', "no-restricted-syntax", HTML_MARK, EVERYWHERE),
  sample("名前を文字列で書いた document[\"write\"] の呼び出し", 'export const r = () => document["write"]("<b>x</b>");', "no-restricted-syntax", HTML_MARK, EVERYWHERE),
  sample("window.document.write の呼び出し", 'export const r = () => window.document.write("<b>x</b>");', "no-restricted-syntax", HTML_MARK, EVERYWHERE),
  sample("globalThis.document.writeln の呼び出し", 'export const r = () => globalThis.document.writeln("<b>x</b>");', "no-restricted-syntax", HTML_MARK, EVERYWHERE),
  sample("self.document.write の呼び出し", 'export const r = () => self.document.write("<b>x</b>");', "no-restricted-syntax", HTML_MARK, EVERYWHERE),
  sample("window[\"document\"].write の呼び出し", 'export const r = () => window["document"].write("<b>x</b>");', "no-restricted-syntax", HTML_MARK, EVERYWHERE),
  sample("JSX の属性 srcDoc（iframe）", "export const r = (html: string) => <iframe srcDoc={html} />;", "no-restricted-syntax", HTML_MARK, EVERYWHERE, true),
  sample("オブジェクトのプロパティ srcDoc", "export const r = (html: string) => ({ srcDoc: html });", "no-restricted-syntax", HTML_MARK, EVERYWHERE),
  sample("文字列の名前のプロパティ \"srcDoc\"", 'export const r = (html: string) => ({ "srcDoc": html });', "no-restricted-syntax", HTML_MARK, EVERYWHERE),
  sample("srcdoc への代入", "export const r = (f: HTMLIFrameElement, html: string) => { f.srcdoc = html; };", "no-restricted-syntax", HTML_MARK, EVERYWHERE),
  sample("f[\"srcdoc\"] への代入", 'export const r = (f: HTMLIFrameElement, html: string) => { f["srcdoc"] = html; };', "no-restricted-syntax", HTML_MARK, EVERYWHERE),
  sample("JSX の属性 srcdoc（小文字で書いた形）", "export const r = (html: string) => <iframe srcdoc={html} />;", "no-restricted-syntax", HTML_MARK, EVERYWHERE, true),
  sample("innerHTML の読み取り（画面に入れない）", "export const r = (el: HTMLElement) => el.innerHTML;", "no-restricted-syntax", HTML_MARK, NOWHERE),
  sample("textContent への代入（文字として入れる）", 'export const r = (el: HTMLElement) => { el.textContent = "<b>x</b>"; };', "no-restricted-syntax", HTML_MARK, NOWHERE),
  sample("insertAdjacentText の呼び出し（文字として入れる）", 'export const r = (el: HTMLElement) => el.insertAdjacentText("beforeend", "x");', "no-restricted-syntax", HTML_MARK, NOWHERE),
  sample("dangerouslySetInnerHTML の分割代入での読み取り", "export const r = ({ dangerouslySetInnerHTML }: { dangerouslySetInnerHTML?: unknown }) => dangerouslySetInnerHTML === undefined;", "no-restricted-syntax", HTML_MARK, NOWHERE),
  sample("document でないオブジェクトの write の呼び出し", 'export const r = (w: { write: (s: string) => void }) => w.write("x");', "no-restricted-syntax", HTML_MARK, NOWHERE),
  sample("srcdoc の読み取り（画面に入れない）", "export const r = (f: HTMLIFrameElement) => f.srcdoc;", "no-restricted-syntax", HTML_MARK, NOWHERE),
  sample("JSX の iframe の src 属性", 'export const r = <iframe src="https://example.com/" />;', "no-restricted-syntax", HTML_MARK, NOWHERE, true),
  sample("JSX の子に文字列を入れる", 'export const r = (text: string) => <div title="x">{text}</div>;', "no-restricted-syntax", HTML_MARK, NOWHERE, true),
];

// 規則の対象の拡張子（eslint.config.mjs の SRC_FILES）。拡張子ごとに、通常の区画と src/ports/ の区画で 1 つずつ確かめる。
const EXTENSIONS = ["ts", "tsx", "js", "jsx", "mjs", "cjs", "mts", "cts"];
const EXTENSION_CASES = EXTENSIONS.flatMap((ext) => [
  {
    zoneLabel: `${ZONES.general.label}。拡張子 ${ext}`,
    file: `src/services/lint-rules-sample.${ext}`,
    ...sample("fetch の呼び出し", 'fetch("https://example.com/");', "no-restricted-globals", PORTS_MARK),
    expected: true,
  },
  {
    zoneLabel: `${ZONES.ports.label}。拡張子 ${ext}`,
    file: `src/ports/lint-rules-sample.${ext}`,
    ...sample("next/script の require()", 'require("next/script");', "no-restricted-syntax", SCRIPT_MARK),
    expected: true,
  },
]);

const ALL_CASES = [
  ...SAMPLES.flatMap((s) =>
    Object.entries(ZONES).map(([zone, z]) => ({
      ...s,
      zone,
      zoneLabel: z.label,
      file: s.jsx ? z.jsxFile : z.file,
      expected: s.expected[zone],
    })),
  ),
  ...EXTENSION_CASES.map((c) => ({ ...c, zone: "extension" })),
];

const HOW_TO_FIX_MISSING =
  "eslint.config.mjs で、この区画に当たる設定のうち最後に書いたものが、この規則の設定の全体になる（同じ規則を別の区画に足すと、" +
  "後の設定が前の設定を置き換える）。規則を足すときは同じ区画にまとめるか、後の区画で、前の区画の制限も並べ直す。" +
  "メッセージの文面を変えただけのときは、この試験の目印（PORTS_MARK、SCRIPT_MARK、HTML_MARK）を合わせて直す。";
const HOW_TO_FIX_EXTRA =
  "eslint.config.mjs で、この区画に当たる files と ignores の範囲を見直す（src/ports/ は不変条件 1、2 の対象外で、" +
  "next/script の import は src/ui/XPostEmbed.tsx でだけ許す）。不変条件そのものを変えるときは、ARCHITECTURE.md と、" +
  "この試験の見込み（SAMPLES）を同じ変更で直す。";
const HOW_TO_FIX_BROKEN = "この試験の見本のコード（SAMPLES）を、ESLint が解析できる形に直す。";
const BASIS =
  "ARCHITECTURE.md の「不変条件」の 1、2、5 と、「将来の作りの注意」の、oEmbed の応答の html の項。この試験の由来は docs/harness-log.md。";

// 設定を 1 つ受け取り、すべての見本を確かめて、見込みと違うものを返す（空の配列なら、確認は通った）。
async function runChecks(eslint) {
  const problems = [];
  for (const c of ALL_CASES) {
    const [result] = await eslint.lintText(c.code, { filePath: resolve(ROOT, c.file) });
    const messages = result?.messages ?? [];
    const fatal = messages.find((m) => m.fatal);
    const base = { zone: c.zone, zoneLabel: c.zoneLabel, file: c.file, name: c.name, ruleId: c.ruleId };
    if (!result || fatal) {
      problems.push({
        ...base,
        kind: "broken",
        what: `見本を解析できなかった（${fatal ? fatal.message : "ESLint が、このファイルの名前を対象外にした"}）。`,
        fix: HOW_TO_FIX_BROKEN,
      });
      continue;
    }
    const detected = messages.some((m) => m.ruleId === c.ruleId && m.severity === 2 && m.message.includes(c.mark));
    if (c.expected && !detected) {
      problems.push({
        ...base,
        kind: "missing",
        what: `規則 ${c.ruleId} が効いていない（この区画で検出するはずの見本を、エラーとして検出しなかった。メッセージの目印は「${c.mark}」）。`,
        fix: HOW_TO_FIX_MISSING,
      });
    } else if (!c.expected && detected) {
      problems.push({
        ...base,
        kind: "extra",
        what: `規則 ${c.ruleId} が、効いてはいけない区画で効いている（この区画で検出しないはずの見本を検出した。メッセージの目印は「${c.mark}」）。`,
        fix: HOW_TO_FIX_EXTRA,
      });
    }
  }
  return problems;
}

function formatProblem(p) {
  return [
    `  - 区画: ${p.zoneLabel}（ファイルの名前 ${p.file}）／見本: ${p.name}`,
    `    何が違反か: ${p.what}`,
    `    どう直すか: ${p.fix}`,
    `    根拠: ${BASIS}`,
  ].join("\n");
}

const has = (problems, kind, zone, name) => problems.some((p) => p.kind === kind && p.zone === zone && p.name === name);

// 設定の配列を受け取り、対象の規則を持つ区画の一覧が見込み（EXPECTED_BLOCKS）と違えば、失敗の表示の文字列を返す
// （空の配列なら、確認は通った）。規則の名前は、プラグインの接頭辞が付いたもの（末尾が対象の規則の名前）も数える。
const isTargetRule = (name) => TARGET_RULES.some((r) => name === r || name.endsWith(`/${r}`));
const describeBlock = (b) => `files=${JSON.stringify(b.files)} ignores=${JSON.stringify(b.ignores)} 規則=${JSON.stringify(b.rules)}`;
function checkBlocks(config) {
  const fix =
    "区画を足した・変えたのなら、scripts/harness/lint-rules.test.mjs の EXPECTED_BLOCKS にその区画を書き、ZONES と SAMPLES に、" +
    "その区画に当たるファイルの名前と、効くはずの規則・対象外のはずの規則の見込みを足す。同じ規則を別の区画に足すと、" +
    "後の設定が前の設定を置き換えるので、区画を増やさずに済むなら、eslint.config.mjs の、前からある区画にまとめる。";
  const format = (what) => [`  - 区画の一覧（eslint.config.mjs で、対象の規則を持つ設定）`, `    何が違反か: ${what}`, `    どう直すか: ${fix}`, `    根拠: ${BASIS}`].join("\n");
  if (!Array.isArray(config)) {
    return [format("eslint.config.mjs の既定の export が、設定の配列でないので、区画を集められない。")];
  }
  const actual = config
    .flat(Infinity)
    .filter((e) => e && typeof e === "object" && Object.keys(e.rules ?? {}).some(isTargetRule))
    .map((e) => ({ files: e.files ?? null, ignores: e.ignores ?? [], rules: Object.keys(e.rules).filter(isTargetRule).sort() }));
  const key = (b) => JSON.stringify(b);
  if (JSON.stringify(actual) === JSON.stringify(EXPECTED_BLOCKS)) return [];
  const count = (list, b) => list.filter((x) => key(x) === key(b)).length;
  const added = actual.filter((b) => count(actual, b) > count(EXPECTED_BLOCKS, b));
  const removed = EXPECTED_BLOCKS.filter((b) => count(EXPECTED_BLOCKS, b) > count(actual, b));
  const parts = [];
  if (added.length > 0) parts.push(`この試験の見込みに無い区画がある（この区画に当たるファイルでは、規則が働いているかを確かめられていない）: ${added.map(describeBlock).join(" ／ ")}`);
  if (removed.length > 0) parts.push(`この試験の見込みにある区画が無い: ${removed.map(describeBlock).join(" ／ ")}`);
  if (parts.length === 0) parts.push(`区画の順が、この試験の見込みと違う（後の設定が前の設定を置き換えるので、順で結果が変わる）: ${actual.map(describeBlock).join(" ／ ")}`);
  return [format(`${parts.join("。")}。`)];
}

// 失敗する見本（区画の一覧）: 現在の設定の配列を変えたものと、その名前。
const EXTRA_SYNTAX_ONLY = { "no-restricted-syntax": ["error", { selector: "WithStatement", message: "見本の規則" }] };
const BROKEN_BLOCK_LISTS = [
  {
    name: "失敗する見本 6: 見本のファイルの名前が当たらない場所（src/sources/**）に、no-restricted-syntax の別の項目だけの区画を足す（元の指摘の形）",
    config: [...eslintConfig, { files: ["src/sources/**"], rules: EXTRA_SYNTAX_ONLY }],
    expectText: 'files=["src/sources/**"]',
  },
  {
    name: "失敗する見本 7: 見本に無い 1 つのファイル（src/ui/NewsList.tsx）に、no-restricted-imports を置き換える区画を足す（元の指摘の形）",
    config: [...eslintConfig, { files: ["src/ui/NewsList.tsx"], rules: { "no-restricted-imports": ["error", { paths: [] }] } }],
    expectText: 'files=["src/ui/NewsList.tsx"]',
  },
  {
    name: "失敗する見本 8: files の無い設定（すべてのファイルに当たる）が、対象の規則を持つ",
    config: [...eslintConfig, { rules: EXTRA_SYNTAX_ONLY }],
    expectText: "files=null",
  },
  {
    name: "失敗する見本 9: 見込みにある区画（src/ports/ の下）が無くなる",
    config: eslintConfig.filter((e) => !(e.files ?? []).some((f) => typeof f === "string" && f.startsWith("src/ports/"))),
    expectText: "この試験の見込みにある区画が無い",
  },
];

// 失敗する見本: 現在の設定の後ろに重ねる設定と、確認が返すはずの失敗。
const BROKEN_CONFIGS = [
  {
    name: "失敗する見本 1: 後の区画が no-restricted-imports を置き換え、XPostEmbed.tsx で通信のモジュールの import の制限が消える（元の指摘の形）",
    overrideConfig: [{ files: ["src/ui/XPostEmbed.tsx"], rules: { "no-restricted-imports": ["error", { paths: [] }] } }],
    expectProblems: [["missing", "owner", "通信のモジュールの import（node:http）"]],
    expectNoProblems: [["missing", "general", "通信のモジュールの import（node:http）"]],
  },
  {
    name: "失敗する見本 2: 後の区画が no-restricted-syntax に別の項目だけを足し、前からある現在時刻と script 要素の制限が消える（元の指摘の形）",
    overrideConfig: [
      {
        files: [SRC_GLOB],
        rules: { "no-restricted-syntax": ["error", { selector: "WithStatement", message: "見本の規則" }] },
      },
    ],
    expectProblems: [
      ["missing", "general", "引数の無い new Date()"],
      ["missing", "general", "通信のモジュールの require()（node:https）"],
      ["missing", "ports", "JSX の script 要素"],
      ["missing", "owner", "next/script の import()"],
    ],
    expectNoProblems: [["missing", "general", "fetch の呼び出し"]],
  },
  {
    name: "失敗する見本 3: 規則を無効にする設定が後ろにあり、通信のための大域の名前の制限が消える",
    overrideConfig: [{ files: [SRC_GLOB], rules: { "no-restricted-globals": "off", "no-restricted-properties": "off" } }],
    expectProblems: [
      ["missing", "general", "fetch の呼び出し"],
      ["missing", "owner", "Date.now() の呼び出し"],
      ["missing", "extension", "fetch の呼び出し"],
    ],
    expectNoProblems: [],
  },
  {
    name: "失敗する見本 4: 後の区画が制限を対象外の区画へ広げる（src/ports/ で fetch を、XPostEmbed.tsx で next/script の import を拒否する）",
    overrideConfig: [
      {
        files: [SRC_GLOB],
        rules: {
          "no-restricted-globals": ["error", { name: "fetch", message: `見本の規則（${PORTS_MARK}）` }],
          "no-restricted-imports": [
            "error",
            {
              paths: [
                { name: "next/script", message: `見本の規則（${SCRIPT_MARK}）` },
                { name: "node:http", message: `見本の規則（${PORTS_MARK}）` },
              ],
            },
          ],
        },
      },
    ],
    expectProblems: [
      ["extra", "ports", "fetch の呼び出し"],
      ["extra", "ports", "通信のモジュールの import（node:http）"],
      ["extra", "owner", "next/script の import"],
    ],
    expectNoProblems: [],
  },
  {
    name: "失敗する見本 5: 規則がエラーでなく警告になっている（npm run lint は通ってしまう）",
    overrideConfig: [{ files: [SRC_GLOB], rules: { "no-restricted-globals": ["warn", { name: "fetch", message: `見本の規則（${PORTS_MARK}）` }] } }],
    expectProblems: [["missing", "general", "fetch の呼び出し"]],
    expectNoProblems: [],
  },
  {
    name: "失敗する見本 10: src/ports/ の区画で no-restricted-syntax を並べ直すときに、HTML の制限（htmlSyntax）を落とす",
    overrideConfig: [
      {
        files: ["src/ports/**/*.{ts,tsx,js,jsx,mjs,cjs,mts,cts}"],
        rules: {
          "no-restricted-syntax": ["error", { selector: "JSXOpeningElement[name.name='script']", message: `見本の規則（${SCRIPT_MARK}）` }],
        },
      },
    ],
    expectProblems: [
      ["missing", "ports", "JSX の属性 dangerouslySetInnerHTML"],
      ["missing", "ports", "innerHTML への代入"],
      ["missing", "ports", "document.write の呼び出し"],
    ],
    expectNoProblems: [
      ["missing", "ports", "JSX の script 要素"],
      ["missing", "general", "JSX の属性 dangerouslySetInnerHTML"],
      ["missing", "owner", "innerHTML への代入"],
    ],
  },
  {
    name: "失敗する見本 11: 規則を広げすぎて、innerHTML の読み取りまで拒否する",
    overrideConfig: [
      {
        files: [SRC_GLOB],
        rules: { "no-restricted-syntax": ["error", { selector: "MemberExpression[property.name='innerHTML']", message: `見本の規則（${HTML_MARK}）` }] },
      },
    ],
    expectProblems: [
      ["extra", "general", "innerHTML の読み取り（画面に入れない）"],
      ["extra", "ports", "innerHTML の読み取り（画面に入れない）"],
      ["extra", "owner", "innerHTML の読み取り（画面に入れない）"],
    ],
    expectNoProblems: [],
  },
];

let passed = 0;
let failed = 0;
const ok = (name) => {
  passed += 1;
  console.log(`ok: ${name}`);
};
const ng = (name, detail) => {
  failed += 1;
  console.error(`NG: ${name}\n${detail}`);
};

// 通る見本（区画の一覧）: 現在の eslint.config.mjs で、対象の規則を持つ区画が、見込みの一覧と一致する。
{
  const name = `通る見本: 現在の eslint.config.mjs で、対象の規則を持つ区画が、見込みの ${EXPECTED_BLOCKS.length} 組と一致する`;
  const problems = checkBlocks(eslintConfig);
  if (problems.length === 0) ok(name);
  else ng(name, problems.join("\n"));
}

// 失敗する見本（区画の一覧）: 区画を足した・消した設定の配列では、確認が失敗を返す。
for (const b of BROKEN_BLOCK_LISTS) {
  const text = checkBlocks(b.config).join("\n");
  const textOk = [b.expectText, "何が違反か: ", "どう直すか: ", "ARCHITECTURE.md", "docs/harness-log.md"].every((s) => text.includes(s));
  if (textOk) ok(b.name);
  else {
    ng(
      b.name,
      [
        "  何が違反か: この試験の区画の一覧の確認（checkBlocks）が、区画を足した・消した設定を見逃したか、失敗の表示に、違反、直し方、根拠のどれかが無い。",
        `    表示にあるはずの文字列: ${b.expectText}`,
        `    実際の表示: ${text === "" ? "（失敗を返さなかった）" : text}`,
        "  どう直すか: scripts/harness/lint-rules.test.mjs の checkBlocks の、区画の集め方と見込みとの比べ方を見直す。",
        `  根拠: ${BASIS}`,
      ].join("\n"),
    );
  }
}

// 通る見本: 現在の eslint.config.mjs では、すべての区画のすべての見本が、見込みのとおりになる。
{
  const name = `通る見本: 現在の eslint.config.mjs で、${ALL_CASES.length} 件の確認（区画と見本の組）がすべて見込みのとおり`;
  const problems = await runChecks(new ESLint({ cwd: ROOT }));
  if (problems.length === 0) ok(name);
  else ng(name, `${problems.length} 件が見込みと違います。\n${problems.map(formatProblem).join("\n")}`);
}

// 失敗する見本: 設定を重ねると、確認が、見込んだ失敗を返す。
for (const b of BROKEN_CONFIGS) {
  const problems = await runChecks(new ESLint({ cwd: ROOT, overrideConfig: b.overrideConfig }));
  const notFound = b.expectProblems.filter(([kind, zone, n]) => !has(problems, kind, zone, n));
  const unexpected = b.expectNoProblems.filter(([kind, zone, n]) => has(problems, kind, zone, n));
  const text = problems.map(formatProblem).join("\n");
  const textOk = problems.length > 0 && ["何が違反か: ", "どう直すか: ", "ARCHITECTURE.md", "docs/harness-log.md"].every((s) => text.includes(s));
  if (notFound.length === 0 && unexpected.length === 0 && textOk) {
    ok(`${b.name}（確認が ${problems.length} 件の失敗を返した）`);
  } else {
    ng(
      b.name,
      [
        "  何が違反か: この試験の確認（runChecks）が、規則を壊した設定を見逃したか、関係の無い見本まで失敗にした。",
        `    返すはずなのに返さなかった失敗: ${JSON.stringify(notFound)}`,
        `    返さないはずなのに返した失敗: ${JSON.stringify(unexpected)}`,
        `    失敗の表示に、違反、直し方、根拠の 3 つがあるか: ${textOk ? "ある" : "無い"}`,
        "  どう直すか: scripts/harness/lint-rules.test.mjs の runChecks の判定（規則の名前とメッセージの目印）と、SAMPLES の見込みを見直す。",
        `  根拠: ${BASIS}`,
      ].join("\n"),
    );
  }
}

const total = passed + failed;
if (failed > 0) {
  console.error(`lint-rules.test: ${total} 件中 ${failed} 件が期待と違います`);
  process.exit(1);
}
console.log(`lint-rules.test: ${total} 件中 ${total} 件が期待どおり`);
