#!/usr/bin/env node
// 秘匿値の検査の本体。入口は scripts/harness/check-secrets.sh（npm run check:secrets と check:secrets:push）。
// CI はこのファイルを node で直接呼ぶ（npm の pre と post のスクリプトを動かさないため）。
//
// 2 つの調べ方がある。
//   作業ツリー（引数なし）: git の一覧（追跡済みのファイルと、.gitignore で除外していない未追跡のファイル）を、
//     作業ツリーの現在の中身で調べる。
//   コミット（--commits [--remote <名前>] [git rev-list の引数]）: 指定した範囲の各コミットに記録された中身を、
//     git から取り出して調べる。範囲のコミットメッセージと、手元のすべての注釈付きのタグの注釈も、単純な内容検査で調べる。
//     範囲を省くと「HEAD --branches --tags --not --remotes=<名前>」（手元のすべてのブランチとタグ、HEAD から
//     到達でき、push 先のリモートの追跡ブランチから到達できないコミット。名前の既定は origin。初回の push ではすべて）。
//     範囲のコミットが 0 件でも、タグの注釈は調べる。
//
// どちらも次の場合は失敗にする（理由は docs/adr/0002-secret-scan-scope.md）。
//   - 一覧にあるのに検査できなかったファイル（作業ツリーで削除したものを除く）
//   - シンボリックリンク
//   - 中身に NUL バイトを含み、既知のバイナリの拡張子（BINARY_EXTS）でないファイル（UTF-16 で書いた文字のファイルなど。
//     secretlint も単純な内容検査も、中の文字を読めないため）
//   - secretlint の除外のファイル（名前が .secretlintignore で始まるもの）と、secretlint の無効化のコメント
//   - 秘匿値が見つかったファイル、コミットメッセージ、タグの注釈
// secretlint が既定で対象外にするファイル（.secretlintrc.* など）と、文字のファイルでないファイルは、
// この中の単純な内容検査（SIMPLE_PATTERNS）で調べる。既知のバイナリの拡張子のファイルは、UTF-16LE と UTF-16BE で
// 読んだ中身も同じ検査に掛ける。
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const SECRETLINT = path.join(ROOT, "node_modules", ".bin", "secretlint");
const CONFIG = path.join(ROOT, ".secretlintrc.json");
// secretlint は、この名前のファイルを各ディレクトリで除外の設定として読む。既定の名前（.secretlintignore）を
// 使わせないため、存在しない名前を渡す。
const UNUSED_IGNORE_NAME = ".harness-secretlintignore-unused";
// secretlint の無効化のコメントの目印。このファイル自身が一致しないよう、2 つに分けて書く。
const DISABLE_MARK = Buffer.from("secretlint" + "-disable");
// secretlint の 1 回の起動に渡すファイルの上限（引数の長さの上限を超えないため）
const SECRETLINT_CHUNK_FILES = 200;
const SECRETLINT_CHUNK_BYTES = 64 * 1024;
// git cat-file --batch の 1 回の起動で取り出す数
const CAT_FILE_CHUNK = 1000;

// secretlint が既定で対象外にするファイル（node_modules/secretlint/src/search.ts の DEFAULT_IGNORE_PATTERNS）。
const isSecretlintDefaultExcluded = (rel) => {
  const parts = rel.split("/");
  if (parts.includes(".git") || parts.includes("node_modules")) return true;
  const base = parts[parts.length - 1];
  return /^\.secretlintrc(\.(json|ya?ml|js))?$/.test(base) || base.startsWith(".secretlintignore");
};

// 単純な内容検査で探す形（代表的な鍵とトークンの接頭辞）。secretlint の規則より粗い。
const SIMPLE_PATTERNS = [
  ["GitHub のトークン", /gh[pousr]_[A-Za-z0-9]{36,}/],
  ["GitHub の細かい権限のトークン", /github_pat_[A-Za-z0-9_]{22,}/],
  ["Anthropic の鍵・トークン", /sk-ant-[a-z0-9]+-[A-Za-z0-9_-]{20,}/],
  ["OpenAI などの sk- の鍵", /\bsk-[A-Za-z0-9_-]{20,}/],
  ["AWS のアクセスキー", /AKIA[0-9A-Z]{16}/],
  ["Slack のトークン", /xox[abposr]-[A-Za-z0-9-]{10,}/],
  ["Google の API キー", /AIza[0-9A-Za-z_-]{35}/],
  ["npm のトークン", /npm_[A-Za-z0-9]{36}/],
  ["秘密鍵", /BEGIN [A-Z ]*PRIVATE KEY/],
];

const die = (msg) => {
  console.error(`check-secrets: ${msg}`);
  process.exit(2);
};

const git = (args, input) => {
  const r = spawnSync("git", ["-C", ROOT, "-c", "core.quotePath=false", ...args], { maxBuffer: 1 << 30, input });
  if (r.error) die(`git を実行できません: ${r.error.message}`);
  return r;
};
const gitOk = (args, input) => {
  const r = git(args, input);
  if (r.status !== 0) die(`git ${args.join(" ")} が失敗しました: ${r.stderr.toString()}`);
  return r.stdout;
};
// 処理は同期で進むので、区切りごとにイベントループへ戻し、SIGINT と SIGTERM の処理を動かす
const yieldForSignals = () => new Promise((resolve) => setImmediate(resolve));
const splitNul = (buf) => buf.toString("utf8").split("\0").filter((s) => s !== "");

// git cat-file --batch で、オブジェクトの中身をまとめて取り出す。onObject(sha, 種類, 中身) を順に呼ぶ。
const catBatch = async (shas, onObject) => {
  for (let i = 0; i < shas.length; i += CAT_FILE_CHUNK) {
    await yieldForSignals();
    const chunk = shas.slice(i, i + CAT_FILE_CHUNK);
    const out = gitOk(["cat-file", "--batch"], chunk.join("\n") + "\n");
    let pos = 0;
    for (const want of chunk) {
      const nl = out.indexOf(0x0a, pos);
      if (nl < 0) die(`git cat-file の出力が途中で終わりました（${want}）`);
      const [sha, type, size] = out.subarray(pos, nl).toString("utf8").split(" ");
      if (sha !== want || type === "missing" || size === undefined) die(`git cat-file で ${want} を取り出せません`);
      const start = nl + 1;
      const end = start + Number(size);
      onObject(sha, type, out.subarray(start, end));
      pos = end + 1; // 中身の後の改行
    }
  }
};

const problems = { unreadable: [], symlinks: [], nulFiles: [], ignoreFiles: [], disableComments: [] };

// 中身に NUL バイトを含んでよい、既知のバイナリの拡張子（今のリポジトリにあるものと、よくある画像とフォント）。
// これ以外の拡張子で NUL バイトを含むファイルは、UTF-16 の文字のファイルなどの読めないファイルとして失敗にする。
const BINARY_EXTS = new Set(["ico", "png", "jpg", "jpeg", "gif", "webp", "avif", "bmp", "woff", "woff2", "ttf", "otf", "eot"]);
const isKnownBinary = (rel) => BINARY_EXTS.has(path.extname(rel).slice(1).toLowerCase());

// 作業ツリーの一覧を作る。返り値の各要素は { abs: 読むパス, rel: リポジトリでのパス, label: 表示名 }。
const collectWorktree = () => {
  const listed = [...new Set(splitNul(gitOk(["ls-files", "-z", "--cached", "--others", "--exclude-standard"])))];
  const deleted = new Set(splitNul(gitOk(["ls-files", "-z", "--deleted"])));
  const entries = [];
  let deletedCount = 0;
  for (const rel of listed) {
    const abs = path.join(ROOT, rel);
    let st;
    try {
      st = fs.lstatSync(abs);
    } catch {
      if (deleted.has(rel)) deletedCount += 1;
      else problems.unreadable.push(rel);
      continue;
    }
    if (st.isSymbolicLink()) problems.symlinks.push(rel);
    else if (st.isFile()) entries.push({ abs, rel, label: rel });
    else problems.unreadable.push(rel); // ディレクトリ（サブモジュールなど）
  }
  return { entries, texts: [], note: deletedCount > 0 ? `作業ツリーで削除した ${deletedCount} 件は対象外` : "" };
};

// --commits の引数を読む。返り値は git rev-list に渡す引数。
const parseCommitArgs = (args) => {
  let remote = null;
  if (args[0] === "--remote") {
    remote = args[1];
    if (!remote || !/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(remote)) die("--remote の後にリモートの名前を書いてください");
    args = args.slice(2);
  }
  if (args.length > 0) {
    if (remote !== null) die("--remote と範囲の指定は一緒に使えません");
    return args;
  }
  // push するのは HEAD だけとは限らない（別のブランチやタグ）ので、手元のすべてのブランチとタグから辿る
  const hasHead = git(["rev-parse", "--verify", "-q", "HEAD"]).status === 0;
  const hasRefs = gitOk(["for-each-ref", "--count=1", "refs/heads", "refs/tags"]).length > 0;
  if (!hasHead && !hasRefs) {
    console.log("check-secrets: コミットがまだ無いので、検査するコミットはありません");
    process.exit(0);
  }
  return [...(hasHead ? ["HEAD"] : []), "--branches", "--tags", "--not", `--remotes=${remote ?? "origin"}`];
};

// コミットの中身を一時ディレクトリへ取り出して一覧を作る。同じパスと同じ中身の組は 1 回だけ調べる。
// 範囲のコミットメッセージと、手元の注釈付きのタグの注釈は、texts（単純な内容検査だけに掛ける文字列）として返す。
const collectCommits = async (revArgs, tmp) => {
  const commits = gitOk(["rev-list", ...revArgs, "--"]).toString().split("\n").filter(Boolean);
  // 0 件でも終えない（タグの注釈は範囲と関係なく調べる）
  if (commits.length === 0) console.log("check-secrets: 検査するコミットはありません（タグの注釈は調べます）");
  const seen = new Map();
  for (const commit of commits) {
    await yieldForSignals();
    const short = commit.slice(0, 12);
    for (const line of splitNul(gitOk(["ls-tree", "-r", "-z", "--full-tree", commit]))) {
      const tab = line.indexOf("\t");
      const [mode, type, sha] = line.slice(0, tab).split(" ");
      const rel = line.slice(tab + 1);
      const label = `${short}:${rel}`;
      if (mode === "120000") {
        problems.symlinks.push(label);
        continue;
      }
      if (type !== "blob" || rel.split("/").some((p) => p === ".." || p === "." || p === "")) {
        problems.unreadable.push(label);
        continue;
      }
      const key = `${sha}\0${rel}`;
      if (seen.has(key)) continue;
      seen.set(key, { abs: path.join(tmp, "tree", sha, rel), rel, label, sha });
    }
  }
  const pathsBySha = new Map();
  for (const e of seen.values()) pathsBySha.set(e.sha, [...(pathsBySha.get(e.sha) ?? []), e.abs]);
  await catBatch([...pathsBySha.keys()], (sha, type, body) => {
    for (const abs of pathsBySha.get(sha)) {
      fs.mkdirSync(path.dirname(abs), { recursive: true });
      fs.writeFileSync(abs, body);
    }
  });

  // コミットメッセージとタグの注釈（見出しの行の後ろ）。タグはどれが push されるか分からないので、手元のすべてを調べる。
  const texts = [];
  const afterHeader = (body) => {
    const i = body.indexOf("\n\n");
    return i < 0 ? "" : body.subarray(i + 2).toString("latin1");
  };
  await catBatch(commits, (sha, type, body) => texts.push({ label: `${sha.slice(0, 12)}（コミットメッセージ）`, text: afterHeader(body) }));
  const tags = gitOk(["for-each-ref", "--format=%(objecttype) %(objectname) %(refname)", "refs/tags"])
    .toString()
    .split("\n")
    .filter((l) => l.startsWith("tag "))
    .map((l) => l.split(" "));
  const tagNames = new Map(tags.map(([, sha, ref]) => [sha, ref]));
  await catBatch([...tagNames.keys()], (sha, type, body) => texts.push({ label: `${tagNames.get(sha)}（タグの注釈）`, text: afterHeader(body) }));

  return {
    entries: [...seen.values()],
    texts,
    note: `コミット ${commits.length} 件のメッセージと、注釈付きのタグ ${tagNames.size} 件の注釈も単純な内容検査で調べた`,
  };
};

const simpleScanText = (text) => SIMPLE_PATTERNS.filter(([, re]) => re.test(text)).map(([name]) => name);
// 既知のバイナリの拡張子のファイルは、UTF-16LE と UTF-16BE で読んだ中身も調べる（偶数と奇数の両方の位置から読む）
const simpleScan = (entry) => {
  const buf = fs.readFileSync(entry.abs);
  const views = [buf.toString("latin1")];
  if (isKnownBinary(entry.rel)) {
    for (const start of [0, 1]) {
      const part = Buffer.from(buf.subarray(start, start + ((buf.length - start) & ~1)));
      views.push(part.toString("utf16le"));
      views.push(part.swap16().toString("utf16le"));
    }
  }
  return [...new Set(views.flatMap(simpleScanText))];
};

// ファイルを、引数の長さの上限を超えない組に分ける
const chunkFiles = (files) => {
  const chunks = [];
  let cur = [];
  let bytes = 0;
  for (const f of files) {
    const len = Buffer.byteLength(f) + 1;
    if (cur.length > 0 && (cur.length >= SECRETLINT_CHUNK_FILES || bytes + len > SECRETLINT_CHUNK_BYTES)) {
      chunks.push(cur);
      cur = [];
      bytes = 0;
    }
    cur.push(f);
    bytes += len;
  }
  if (cur.length > 0) chunks.push(cur);
  return chunks;
};

const main = async () => {
  const argv = process.argv.slice(2);
  const commitMode = argv[0] === "--commits";
  if (argv.length > 0 && !commitMode) die(`知らない引数です: ${argv[0]}（使えるのは --commits だけ）`);
  if (!fs.existsSync(SECRETLINT)) die("secretlint がありません。先に npm ci を実行してください");
  const revArgs = commitMode ? parseCommitArgs(argv.slice(1)) : [];

  // 終了のときと、SIGINT・SIGTERM で止めたときに一時ディレクトリを消す（取り出したファイルと報告を残さない）
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "harness-secrets-"));
  const cleanup = () => fs.rmSync(tmp, { recursive: true, force: true });
  process.on("exit", cleanup);
  for (const [sig, code] of [["SIGINT", 130], ["SIGTERM", 143]]) {
    process.on(sig, () => {
      cleanup();
      console.error(`check-secrets: ${sig} で止めました`);
      process.exit(code);
    });
  }
  {
    const { entries, texts, note } = commitMode ? await collectCommits(revArgs, tmp) : collectWorktree();
    // コミットの検査は、範囲のコミットが 0 件でもタグの注釈を調べるので、ファイルが無くても続ける
    if (!commitMode && entries.length === 0 && problems.symlinks.length === 0 && problems.unreadable.length === 0) {
      die("対象のファイルがありません");
    }

    // secretlint の除外を、ファイルを足すだけで働かせないための検査と、NUL バイトを含むファイルの検査
    const readable = [];
    for (const e of entries) {
      if (path.basename(e.rel).startsWith(".secretlintignore") || path.basename(e.rel) === UNUSED_IGNORE_NAME) {
        problems.ignoreFiles.push(e.label);
      }
      const buf = fs.readFileSync(e.abs);
      if (buf.includes(DISABLE_MARK)) problems.disableComments.push(e.label);
      if (buf.includes(0) && !isKnownBinary(e.rel)) problems.nulFiles.push(e.label);
      else readable.push(e);
    }

    // コミットの中身はリポジトリの外の一時ディレクトリに置くので、secretlint の既定の除外が掛からない
    const routeToSimple = (e) => !commitMode && isSecretlintDefaultExcluded(e.rel);
    const forSimple = readable.filter(routeToSimple);
    const forSecretlint = readable.filter((e) => !routeToSimple(e));
    const excludedCount = forSimple.length; // secretlint の既定の対象外で、単純な内容検査だけで調べるファイル
    const simpleSet = new Set(forSimple);
    const byAbs = new Map(forSecretlint.map((e) => [e.abs, e]));
    const findings = [];
    let checkedBySecretlint = 0;

    const common = ["--secretlintrc", CONFIG, "--secretlintignore", UNUSED_IGNORE_NAME, "--no-gitignore", "--no-glob"];
    const seenAbs = new Set();
    const withFindings = [];
    for (const files of chunkFiles(forSecretlint.map((e) => e.abs))) {
      await yieldForSignals();
      const report = path.join(tmp, "report.json");
      const r = spawnSync(SECRETLINT, [...common, "--format", "json", "--output", report, "--", ...files], {
        cwd: ROOT,
        stdio: ["ignore", "inherit", "inherit"],
      });
      await yieldForSignals(); // 子のプロセスが SIGINT で止まった場合は、ここで止める
      if (r.status !== 0 || !fs.existsSync(report)) die(`secretlint が異常終了しました（終了コード ${r.status}）`);
      const results = JSON.parse(fs.readFileSync(report, "utf8"));
      fs.rmSync(report);
      for (const res of results) {
        const e = byAbs.get(path.resolve(res.filePath));
        if (!e) continue;
        seenAbs.add(e.abs);
        if (res.messages.length > 0) withFindings.push(e);
        checkedBySecretlint += 1;
        if (res.sourceContentType === "binary" && !simpleSet.has(e)) {
          simpleSet.add(e);
          forSimple.push(e); // secretlint の規則の多くは文字のファイルだけを調べるため
        }
      }
    }
    for (const e of forSecretlint) if (!seenAbs.has(e.abs)) problems.unreadable.push(e.label);
    // 既知のバイナリの拡張子のファイルは、secretlint が文字のファイルと見なしても単純な内容検査に掛ける（UTF-16 の中身のため）
    for (const e of forSecretlint) {
      if (isKnownBinary(e.rel) && !simpleSet.has(e)) {
        simpleSet.add(e);
        forSimple.push(e);
      }
    }
    // 見つかった値を伏せた形で表示する（secretlint の既定の maskSecrets）
    for (const files of chunkFiles(withFindings.map((e) => e.abs))) {
      spawnSync(SECRETLINT, [...common, "--", ...files], { cwd: ROOT, stdio: "inherit" });
    }
    for (const e of withFindings) findings.push(`${e.label}（secretlint）`);
    for (const e of forSimple) {
      for (const name of simpleScan(e)) findings.push(`${e.label}（単純な内容検査: ${name}）`);
    }
    for (const t of texts) {
      for (const name of simpleScanText(t.text)) findings.push(`${t.label}（単純な内容検査: ${name}）`);
    }

    const summary =
      `secretlint で ${checkedBySecretlint} 件、単純な内容検査で ${forSimple.length} 件` +
      `（うち secretlint の既定の対象外 ${excludedCount} 件、secretlint でも調べた ${forSimple.length - excludedCount} 件）` +
      `を調べました${note ? `。${note}` : ""}`;
    console.log(`check-secrets: ${commitMode ? "コミットの中身" : "作業ツリー"}: ${summary}`);

    let failed = false;
    const report = (list, title, fix) => {
      if (list.length === 0) return;
      failed = true;
      console.error(`check-secrets: NG: ${title}（${list.length} 件）`);
      for (const x of list) console.error(`  - ${x}`);
      console.error(`  直し方: ${fix}`);
    };
    report(problems.unreadable, "一覧にあるのに検査できなかったファイル", "ファイルの種類と読み取りの権限を確かめる。サブモジュールは使わない");
    report(problems.symlinks, "シンボリックリンク", "シンボリックリンクをやめ、実体のファイルを置く（リンク先の中身は検査と食い違うため）");
    report(
      problems.nulFiles,
      "NUL バイトを含むファイル（UTF-16 で書いた文字のファイルなど）",
      `文字のファイルは UTF-8 で保存し直す（UTF-16 などの中身は検査で読めないため）。バイナリのファイルは既知の拡張子（${[...BINARY_EXTS].join("、")}）にする`,
    );
    report(problems.ignoreFiles, "secretlint の除外のファイル", "このファイルを消す。誤検出は .secretlintrc.json の規則の設定で直し、ADR に理由を書く");
    report(problems.disableComments, "secretlint の無効化のコメント", "コメントを消す。誤検出は .secretlintrc.json の規則の設定で直し、ADR に理由を書く");
    report(findings, "秘匿値の疑い", "値を消し、鍵を無効にして作り直す。コミット済みなら履歴（コミットメッセージとタグを含む）からも消す");
    if (failed) process.exit(1);
    console.log("check-secrets: 秘匿値は見つかりませんでした");
  }
};

await main();
