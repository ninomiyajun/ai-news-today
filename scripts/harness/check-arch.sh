#!/usr/bin/env bash
# 層の依存の向きの検査の入口（ARCHITECTURE.md）。規則の本体は .dependency-cruiser.cjs にある。
# 手元と CI で同じコマンドを使う: npm run check:arch
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# 規則のパス（^src/...）はリポジトリのルートからの相対なので、ルートで実行する
cd "$ROOT"

# src/ の直下に、層の表に無いディレクトリやファイルが無いことを確かめる。dependency-cruiser の規則は
# import の辺にだけ掛かるので、何も import しないファイルを表に無いディレクトリに置くと検出できないため。
# 層の一覧は .dependency-cruiser.cjs の unregistered-layer の規則から読む（一覧を 2 か所に持たない）。
node - <<'JS'
const { spawnSync } = require("node:child_process");
const path = require("node:path");
const config = require(path.resolve(".dependency-cruiser.cjs"));
const rule = config.forbidden.find((r) => r.name === "unregistered-layer");
if (!rule || !rule.from || !rule.from.pathNot) {
  console.error("check-arch: NG: .dependency-cruiser.cjs に unregistered-layer の規則（from.pathNot）がありません");
  process.exit(1);
}
const allowed = new RegExp(rule.from.pathNot);
// コミットの対象になるファイル（追跡済みと、.gitignore で除外していない未追跡）から、src/ の直下の名前を得る。
// .DS_Store など .gitignore で除外したものは数えない。
const r = spawnSync("git", ["-c", "core.quotePath=false", "ls-files", "-z", "--cached", "--others", "--exclude-standard", "--", "src"]);
if (r.status !== 0) {
  console.error(`check-arch: NG: git ls-files が失敗しました: ${r.stderr}`);
  process.exit(1);
}
const tops = new Set();
for (const p of r.stdout.toString("utf8").split("\0").filter(Boolean)) {
  const rest = p.slice("src/".length);
  const slash = rest.indexOf("/");
  tops.add(slash === -1 ? `src/${rest}` : `src/${rest.slice(0, slash)}/`);
}
const bad = [...tops].filter((p) => !allowed.test(p));
if (bad.length > 0) {
  console.error(`check-arch: NG: src/ の直下に、層の表に無いものがあります（${bad.length} 件）`);
  for (const p of bad) console.error(`  - ${p}`);
  console.error(`  直し方: ${rule.comment}`);
  process.exit(1);
}
JS

# err-long は、違反ごとに規則の comment（直し方）も表示する
npx --no-install depcruise --config .dependency-cruiser.cjs --output-type err-long src
