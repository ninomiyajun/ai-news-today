import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";

// 外部への通信と現在時刻は src/ports/ からだけ得る（ARCHITECTURE.md の不変条件 1 と 2）。
// 試験のときに決まったデータと時刻へ差し替えられるようにするためである。
// performance.now() と new Date(undefined) は現在時刻を返さない（経過時間と不正な日付）ので対象にしない。
// 別名を経由した書き方（const g = globalThis; g.fetch() など）は ESLint では止められない（ARCHITECTURE.md の不変条件）。
const portsOnly = "src/ports/ の HttpClient と Clock を引数で受け取って使ってください（ARCHITECTURE.md の不変条件）。";
// 通信のためのモジュール。fetch を禁じても、これらを使えば外部へ通信できるため、src/ports/ の外で import を禁じる。
const NETWORK_MODULE_BASES = ["http", "https", "http2", "net", "tls", "dgram"];
const NETWORK_MODULES = [...NETWORK_MODULE_BASES.flatMap((m) => [`node:${m}`, m]), "undici"];
const networkModulePattern = `/^(${NETWORK_MODULES.join("|")})$/`;
// 通信のための大域の名前。
const NETWORK_GLOBALS = ["fetch", "WebSocket", "XMLHttpRequest", "EventSource"];
const globalMessage = (name) => `${name} を直接使わないでください。${portsOnly}`;
const networkMessage = `通信のためのモジュール（${NETWORK_MODULES.join("、")}）を src/ports/ の外で使わないでください。${portsOnly}`;

const eslintConfig = defineConfig([
  ...nextVitals,
  ...nextTs,
  {
    files: ["src/**/*.{ts,tsx,js,jsx,mjs,cjs,mts,cts}"],
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
      "no-restricted-imports": [
        "error",
        { paths: NETWORK_MODULES.map((name) => ({ name, message: networkMessage })) },
      ],
      "no-restricted-syntax": [
        "error",
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
      ],
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
