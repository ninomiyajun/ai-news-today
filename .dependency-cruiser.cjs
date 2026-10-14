// 層の依存の向きの検査（ARCHITECTURE.md の「依存の向き」を機械的に確かめる）。
// 層を足す・向きを変えるときは、ARCHITECTURE.md とこのファイルを同じ変更で直す。

const LAYERS = ["app", "ui", "composition", "services", "sources", "curation", "ports", "domain"];

/** from の層が import してよい層（自分自身を含む）。ARCHITECTURE.md の表と同じ内容にする。 */
const ALLOWED = {
  app: ["app", "composition", "services", "ui", "domain"],
  ui: ["ui", "domain"],
  composition: ["composition", "services", "sources", "ports", "domain"],
  services: ["services", "sources", "curation", "ports", "domain"],
  sources: ["sources", "ports", "domain"],
  curation: ["curation", "domain"],
  ports: ["ports", "domain"],
  domain: ["domain"],
};

const layerRules = Object.entries(ALLOWED).map(([from, allowed]) => ({
  name: `layer-${from}`,
  severity: "error",
  comment:
    `src/${from}/ が import してよいのは ${allowed.map((l) => `src/${l}/`).join("、")} だけです。` +
    "直し方: 依存の向きを ARCHITECTURE.md の表に合わせる（例: 処理を下の層へ移す、型を src/domain/ に置く、依存を引数で受け取る）。" +
    "向きそのものを変えるなら、ARCHITECTURE.md と ADR を先に直してから、このファイルの ALLOWED を直す。",
  from: { path: `^src/${from}/` },
  to: { path: "^src/", pathNot: `^src/(${allowed.join("|")})/` },
}));

/** @type {import('dependency-cruiser').IConfiguration} */
module.exports = {
  forbidden: [
    ...layerRules,
    {
      name: "unregistered-layer",
      severity: "error",
      comment:
        `src/ の直下に置いてよいディレクトリは ${LAYERS.join("、")} だけです。` +
        "直し方: 既存の層に置くか、層を足すなら ARCHITECTURE.md と .dependency-cruiser.cjs を同じ変更で直す。",
      from: { path: "^src/", pathNot: `^src/(${LAYERS.join("|")})/` },
      to: {},
    },
    // モジュールのひな形（templates/）と src/ の間の依存は、どちらの向きも拒否する（ARCHITECTURE.md の「層と責務」）。
    // tsconfig の別名（@/...）も src/ のパスへ解決してから照合するので、別名で書いた import も検出する。
    {
      name: "templates-not-to-src",
      severity: "error",
      comment:
        "templates/ の下のひな形が src/ の下を import しています。ひな形は src/ の何も import せず、それだけで型の検査が通る形に保ちます" +
        "（src/ の中身が変わっても、ひな形が壊れないため）。" +
        "直し方: ひな形の中で要る型や値を、ひな形のディレクトリの中に置くか、ひな形の引数で受け取る形にする（@/... の別名でも src/ を指すので同じ）。" +
        "根拠: ARCHITECTURE.md の「層と責務」の templates/ の段落、templates/module/README.md の「守る決まり」。",
      from: { path: "^templates/" },
      to: { path: "^src/" },
    },
    {
      name: "src-not-to-templates",
      severity: "error",
      comment:
        "src/ の下のコードが templates/ の下のひな形を import しています。templates/ は層ではなく、写して使うひな形の置き場です。" +
        "直し方: ひな形を src/ の該当の層へ写し、写したファイルを import する（写し方は templates/module/README.md の「使い方」）。" +
        "根拠: ARCHITECTURE.md の「層と責務」の templates/ の段落。",
      from: { path: "^src/" },
      to: { path: "^templates/" },
    },
    {
      name: "no-circular",
      severity: "error",
      comment: "循環した依存があります。直し方: 共通の部分を下の層へ移す。",
      from: {},
      to: { circular: true },
    },
    {
      name: "not-to-unresolvable",
      severity: "error",
      comment: "解決できない import があります。直し方: パスの誤りを直すか、依存を package.json に足す。",
      from: {},
      to: { couldNotResolve: true },
    },
  ],
  options: {
    doNotFollow: { path: "node_modules" },
    tsPreCompilationDeps: true,
    tsConfig: { fileName: "tsconfig.json" },
    enhancedResolveOptions: {
      exportsFields: ["exports"],
      conditionNames: ["import", "require", "node", "default", "types"],
    },
  },
};
