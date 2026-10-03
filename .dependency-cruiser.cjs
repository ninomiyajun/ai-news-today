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
