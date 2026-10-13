// 早期通知（scripts/harness/notify.sh）の入力の変換。notify.sh だけが呼ぶ。
//
// 使い方: node notify-paths.mjs <claude|codex> <出すパスの数の上限> <入力のバイト数の上限> < フックの入力の JSON
//
// 標準入力のフックの入力から、道具が書いたファイルのパスを取り出し、標準出力へ、1 件ずつ NUL で終わる形で出す。
// - 出すのは絶対パス。相対パスは、入力の cwd の項目を基準に、文字列としてつなぐ（`..` を畳まない。シンボリックリンクを
//   挟むと、畳んだ結果が実際の場所とずれるためで、実体のパスへの解決は notify.sh が行う）。
// - 判定できないパスは、絶対パスの代わりに、`!` で始まる目印（`!empty`、`!control`）を出す。notify.sh は対象外として数える。
// - 名前が `.md` で終わらない絶対パスは出さず、数だけを、最後に `!not-md:<数>` の 1 件で出す（文書でない書き込みは、
//   いくつあっても、notify.sh の判定と上限にかけないため）。
// - 出すパスが上限を超えたら、上限までを出して、最後に `!too-many` の 1 件を出す。
// - claude: tool_input.file_path の 1 件。
// - codex: tool_input.command（apply_patch のパッチの全文）の見出しの行のパス。受ける見出しは `*** Add File: `、
//   `*** Update File: `、`*** Delete File: `、`*** Move to: ` の 4 種類で、種類で扱いを分けない。見出しの語の後ろから
//   行末までをパスとして読む（引用符を外さない）。4 種類に当たらない `***` の行は無視する。
//
// 終了コード: 0 = 取り出せた。3 = 入力の形が想定と違う（理由を標準エラーに 1 語で出す。notify.sh が知らせる）。
// 4 = 引数（呼び出し元の名前、2 つの上限）が違う。5 = 入力が、バイト数の上限を超えた（超えた時点で、読むのをやめる）。
//
// 決まり: 読み込むのは `node:` で始まる組み込みのモジュールだけにする（node_modules と、相対のパスのファイルを読み込まない）。
// 早期通知が実行するものを、notify.sh、このファイル、check-docs.sh の 3 つに限るためである（notify.test.sh が検索で確かめる）。
import { readSync } from 'node:fs';

const EXIT_SHAPE = 3;
const EXIT_USAGE = 4;
const EXIT_TOO_LARGE = 5;
const HEADER = /^\*\*\* (?:Add File|Update File|Delete File|Move to): (.*)$/;

function shapeChanged(reason) {
  process.stderr.write(`${reason}\n`);
  process.exit(EXIT_SHAPE);
}

function isObject(value) {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

// パスを、出力の 1 件にする。cwd は、相対パスの基準（絶対パスの文字列か、無ければ undefined）
function toRecord(path, cwd) {
  if (path === '') return '!empty';
  if (/[\0\n\r]/.test(path)) return '!control';
  if (path.startsWith('/')) return path;
  if (typeof cwd !== 'string' || !cwd.startsWith('/') || /[\0\n\r]/.test(cwd)) shapeChanged('no-cwd');
  return cwd.endsWith('/') ? `${cwd}${path}` : `${cwd}/${path}`;
}

function claudePaths(input) {
  const filePath = input.tool_input?.file_path;
  if (typeof filePath !== 'string') shapeChanged('no-file-path');
  return [filePath];
}

function codexPaths(input) {
  const patch = input.tool_input?.command;
  if (typeof patch !== 'string') shapeChanged('no-command');
  const paths = [];
  for (const rawLine of patch.split('\n')) {
    const line = rawLine.endsWith('\r') ? rawLine.slice(0, -1) : rawLine;
    const found = HEADER.exec(line);
    if (found) paths.push(found[1]);
  }
  if (paths.length === 0) shapeChanged('no-patch-header');
  return paths;
}

// 標準入力を、上限のバイト数まで読む。上限を超えたら、残りを読まずに終わる（メモリーを使い切らないため）
function readInput(maxBytes) {
  const chunks = [];
  const buffer = Buffer.alloc(65536);
  let total = 0;
  for (;;) {
    let size;
    try {
      size = readSync(0, buffer, 0, buffer.length, null);
    } catch (error) {
      if (error.code === 'EAGAIN') continue;
      if (error.code === 'EOF') break;
      shapeChanged('unreadable');
    }
    if (size === 0) break;
    total += size;
    if (total > maxBytes) {
      process.stderr.write('too-large\n');
      process.exit(EXIT_TOO_LARGE);
    }
    chunks.push(Buffer.from(buffer.subarray(0, size)));
  }
  return Buffer.concat(chunks).toString('utf8');
}

const caller = process.argv[2];
const maxRecords = Number(process.argv[3]);
const maxBytes = Number(process.argv[4]);
if ((caller !== 'claude' && caller !== 'codex') || !Number.isInteger(maxRecords) || maxRecords < 1
  || !Number.isInteger(maxBytes) || maxBytes < 1) {
  process.stderr.write('bad-arguments\n');
  process.exit(EXIT_USAGE);
}

const text = readInput(maxBytes);
if (text.trim() === '') shapeChanged('empty');

let input;
try {
  input = JSON.parse(text);
} catch {
  shapeChanged('not-json');
}
if (!isObject(input) || !isObject(input.tool_input)) shapeChanged('no-tool-input');

const paths = caller === 'claude' ? claudePaths(input) : codexPaths(input);
const seen = new Set();
const records = [];
let notMarkdown = 0;
let tooMany = false;
for (const path of paths) {
  const record = toRecord(path, input.cwd);
  if (seen.has(record)) continue;
  seen.add(record);
  if (record.startsWith('/') && !record.endsWith('.md')) {
    notMarkdown += 1;
  } else if (records.length >= maxRecords) {
    tooMany = true;
    break;
  } else {
    records.push(record);
  }
}
if (notMarkdown > 0) records.push(`!not-md:${notMarkdown}`);
if (tooMany) records.push('!too-many');
process.stdout.write(records.map((record) => `${record}\0`).join(''));
