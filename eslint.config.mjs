import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";

// 外部への通信と現在時刻は src/ports/ からだけ得る（ARCHITECTURE.md の不変条件 1 と 2）。
// 試験のときに決まったデータと時刻へ差し替えられるようにするためである。
// performance.now() と new Date(undefined) は現在時刻を返さない（経過時間と不正な日付）ので対象にしない。
// 別名を経由した書き方（const g = globalThis; g.fetch() など）は ESLint では止められない（ARCHITECTURE.md の不変条件）。
const portsOnly = "src/ports/ の HttpClient と Clock を引数で受け取って使ってください（ARCHITECTURE.md の不変条件）。";
// 通信のためのモジュール。fetch を禁じても、これらを使えば外部へ通信できるため、src/ports/ の外で import を禁じる。
// npm run check:docs（scripts/harness/checks.d/network-names.sh）は、NETWORK_MODULE_BASES、NETWORK_MODULES、NETWORK_GLOBALS の
// 3 つの行を文字列として読み取り、ARCHITECTURE.md の不変条件 1 と 2 の名前と照合する。各行の 1 行の形（const 名前 = [ … ];）と、
// NETWORK_MODULES の flatMap での組み立て方を変えるときは、scripts/harness/checks.d/network-names.sh も同じ変更で直す。
const NETWORK_MODULE_BASES = ["http", "https", "http2", "net", "tls", "dgram"];
const NETWORK_MODULES = [...NETWORK_MODULE_BASES.flatMap((m) => [`node:${m}`, m]), "undici"];
const networkModulePattern = `/^(${NETWORK_MODULES.join("|")})$/`;
// 通信のための大域の名前。npm run check:docs（scripts/harness/checks.d/network-names.sh）が読み取る（上の注記のとおり、1 行の形を保つ）。
const NETWORK_GLOBALS = ["fetch", "WebSocket", "XMLHttpRequest", "EventSource"];
const globalMessage = (name) => `${name} を直接使わないでください。${portsOnly}`;
const networkMessage = `通信のためのモジュール（${NETWORK_MODULES.join("、")}）を src/ports/ の外で使わないでください。${portsOnly}`;

// ブラウザに読み込ませる外部のスクリプトは src/ui/XPostEmbed.tsx の WIDGETS_JS_URL だけにする（ARCHITECTURE.md の不変条件 5）。
// そのため next/script の import をこのファイルの外で拒否し、JSX の script 要素を src/ と templates/ の下のすべてで拒否する。
const SRC_FILES = "src/**/*.{ts,tsx,js,jsx,mjs,cjs,mts,cts}";
// モジュールのひな形（templates/ の下）にも、src/ の下の通常の区画と同じ規則をかける。ひな形は src/ の下へ写して使うので、
// 写した直後に lint で落ちる形になっていないことを、写す前から確かめるためである（ARCHITECTURE.md の「層と責務」）。
const TEMPLATE_FILES = "templates/**/*.{ts,tsx,js,jsx,mjs,cjs,mts,cts}";
const SCRIPT_OWNER = "src/ui/XPostEmbed.tsx";
const externalScriptMessage =
  "外部のスクリプトは src/ui/XPostEmbed.tsx の WIDGETS_JS_URL からだけ読み込んでください（ARCHITECTURE.md の不変条件 5）。";
const nextScriptImport = { name: "next/script", message: externalScriptMessage };
// require() と import() で next/script を読み込む形も拒否する。静的な import は no-restricted-imports で拒否する。
// src/ui/XPostEmbed.tsx も静的な import だけを使うので、この 2 つはそのファイルでも拒否してよい。
const externalScriptSyntax = [
  {
    selector: "JSXOpeningElement[name.name='script']",
    message: `JSX の script 要素を使わないでください。${externalScriptMessage}`,
  },
  {
    selector: "CallExpression[callee.name='require'] > Literal.arguments[value='next/script']",
    message: externalScriptMessage,
  },
  {
    selector: "ImportExpression > Literal.source[value='next/script']",
    message: externalScriptMessage,
  },
];

// 外から受け取った HTML を、文字列のまま画面に入れる書き方を、src/ と templates/ の下のすべてで拒否する
// （ARCHITECTURE.md の「将来の作りの注意」の、oEmbed の応答の html の項）。
// オブジェクトのプロパティは、オブジェクトを書く形（{ dangerouslySetInnerHTML: ... }、{ srcDoc: ... }）だけを拒否し、
// 分割代入で読む形は拒否しない。
// 書いた名前の形だけを見るので、{...props} の展開で渡す形、名前を変数で組み立てたプロパティ、別名を経由した
// document.write、DOMParser などの別の入口は止められない（ARCHITECTURE.md の同じ項）。
const htmlMessage = (what) =>
  `${what} で、HTML の文字列を画面に入れないでください。外から受け取った HTML を入れると、中身しだいで任意のスクリプトが` +
  "動きうるためです。React の要素（JSX）で組み立て、文字列は JSX の子や textContent で文字として入れてください" +
  "（ARCHITECTURE.md の「将来の作りの注意」の、oEmbed の応答の html の項）。";
// 代入すると HTML の文字列が画面に入るプロパティ（srcdoc は iframe の中身の HTML）。
const HTML_PROPERTIES = "/^(innerHTML|outerHTML|src[dD]oc)$/";
// オブジェクトに書くと、React の要素の属性として HTML の文字列が画面に入るプロパティ（createElement に渡す形など）。
const HTML_PROPS = "/^(dangerouslySetInnerHTML|src[dD]oc)$/";
// HTML の文字列を受け取って DOM に入れる（または DOM の断片にする）メソッド。名前を文字列で書いた el["…"](…) の形も拒否する。
const HTML_METHODS = "/^(insertAdjacentHTML|setHTMLUnsafe|createContextualFragment)$/";
// document.write と document.writeln。window.、globalThis.、self. を付けた形と、名前を文字列で書いた形も拒否する。
const DOCUMENT_WRITE = "/^(write|writeln)$/";
const GLOBAL_OBJECTS = "/^(window|globalThis|self)$/";
const htmlSyntax = [
  {
    selector: "JSXAttribute[name.name='dangerouslySetInnerHTML']",
    message: htmlMessage("JSX の属性 dangerouslySetInnerHTML"),
  },
  {
    selector: `ObjectExpression > Property[key.name=${HTML_PROPS}], ObjectExpression > Property[key.value=${HTML_PROPS}]`,
    message: htmlMessage("オブジェクトのプロパティ dangerouslySetInnerHTML、srcDoc"),
  },
  {
    selector: `AssignmentExpression > MemberExpression.left[property.name=${HTML_PROPERTIES}], AssignmentExpression > MemberExpression.left[property.value=${HTML_PROPERTIES}]`,
    message: htmlMessage("innerHTML、outerHTML、srcdoc への代入"),
  },
  {
    selector: "JSXAttribute[name.name=/^src[dD]oc$/]",
    message: htmlMessage("JSX の属性 srcDoc（iframe に HTML の文字列を入れる）"),
  },
  {
    selector: `CallExpression > MemberExpression.callee:matches([property.name=${HTML_METHODS}], [property.value=${HTML_METHODS}])`,
    message: htmlMessage("insertAdjacentHTML、setHTMLUnsafe、createContextualFragment の呼び出し"),
  },
  {
    selector:
      `CallExpression > MemberExpression.callee:matches([property.name=${DOCUMENT_WRITE}], [property.value=${DOCUMENT_WRITE}])` +
      `:matches([object.name='document'], [object.object.name=${GLOBAL_OBJECTS}][object.property.name='document'], ` +
      `[object.object.name=${GLOBAL_OBJECTS}][object.property.value='document'])`,
    message: htmlMessage("document.write、document.writeln の呼び出し"),
  },
];
const networkImports = NETWORK_MODULES.map((name) => ({ name, message: networkMessage }));
const portsSyntax = [
  {
    selector: "NewExpression[callee.name='Date'][arguments.length=0]",
    message: `引数の無い new Date() で現在時刻を得ないでください。${portsOnly}`,
  },
  {
    selector: "CallExpression[callee.name='Date']",
    message: `Date() で現在時刻を得ないでください（new を付けない呼び出しは現在時刻の文字列を返す）。${portsOnly}`,
  },
  {
    selector: `CallExpression[callee.name='require'] > Literal.arguments[value=${networkModulePattern}]`,
    message: networkMessage,
  },
  {
    selector: `ImportExpression > Literal.source[value=${networkModulePattern}]`,
    message: networkMessage,
  },
];

const eslintConfig = defineConfig([
  ...nextVitals,
  ...nextTs,
  {
    files: [SRC_FILES, TEMPLATE_FILES],
    ignores: ["src/ports/**"],
    rules: {
      "no-restricted-globals": ["error", ...NETWORK_GLOBALS.map((name) => ({ name, message: globalMessage(name) }))],
      "no-restricted-properties": [
        "error",
        { object: "Date", property: "now", message: `Date.now() を直接呼ばないでください。${portsOnly}` },
        { object: "Temporal", property: "Now", message: `Temporal.Now を直接使わないでください。${portsOnly}` },
        ...["globalThis", "window", "self"].flatMap((object) =>
          NETWORK_GLOBALS.map((property) => ({ object, property, message: globalMessage(`${object}.${property}`) })),
        ),
      ],
      "no-restricted-imports": ["error", { paths: [...networkImports, nextScriptImport] }],
      "no-restricted-syntax": ["error", ...portsSyntax, ...externalScriptSyntax, ...htmlSyntax],
    },
  },
  // 不変条件 5 の例外: next/script の import は src/ui/XPostEmbed.tsx でだけ許す。
  // 同じ規則の設定は後のものが前のものを置き換えるので、不変条件 1、2 の import の制限はここでも並べ直す。
  {
    files: [SCRIPT_OWNER],
    rules: {
      "no-restricted-imports": ["error", { paths: networkImports }],
    },
  },
  // src/ports/ は不変条件 1、2 の対象外だが、不変条件 5 と HTML の制限（htmlSyntax）は適用する。
  {
    files: ["src/ports/**/*.{ts,tsx,js,jsx,mjs,cjs,mts,cts}"],
    rules: {
      "no-restricted-imports": ["error", { paths: [nextScriptImport] }],
      "no-restricted-syntax": ["error", ...externalScriptSyntax, ...htmlSyntax],
    },
  },
  // Override default ignores of eslint-config-next.
  globalIgnores([
    // Default ignores of eslint-config-next:
    ".next/**",
    "out/**",
    "build/**",
    "next-env.d.ts",
  ]),
]);

export default eslintConfig;
