// harness-copy: source=home/agents/skills/project-harness-init/assets/parts/node-compose/assets/check-compose.mjs
// harness-copy: version=rules-2026.11.13-1
// harness-copy: sha256=5f1118304f76989067e6619c6d42493547bfceb9f730c98102166dfa3f52a99a
// harness-copy: この 4 行と本体は手で変えない。正本を直して project-harness-init の「導入済みのプロジェクトの更新」で置き換える
// アプリの開発環境の定義（compose.yaml・compose.override.yaml・Dockerfile）の静的な検査の本体。
// 入口は scripts/harness/check-compose.sh（node でこのファイルを動かす）。docker の CLI と Docker の daemon は使わない。
//
//   node check-compose.mjs <根> <道具の根>
//
// <根> は検査する定義の置き場、<道具の根> は yaml を読む node_modules の置き場（入口の check-compose.sh の 2 つ上）。
//
// 確かめること（エージェントの起動の検査〔定義を展開してから当てる〕と同じ規則の一部を、ファイルの文字と YAML の構造で当てる）:
//   - 道具: YAML は道具の根の node_modules/yaml（版 2.9.1）だけで読む。上のディレクトリへは探しに行かない。
//   - 原文の文字: 制御文字、CR（復帰）、U+0085・U+2028・U+2029（行の区切りとして読む読み取りがある文字）、U+FEFF を拒む。
//   - YAML の読み取り: 文書は 1 つ。重複したキー、anchor・alias・merge key（<<）、型の印（!）、%YAML・%TAG の指示、
//     文字でない項目の名前を拒み、読めない YAML と読み取りの警告は不合格にする。原文の $（展開）と逆斜線も拒む。
//   - compose.yaml: 許可の一覧の形。一覧に無い項目はすべて拒む。ホストのパスの bind（Windows のドライブの形を含む）は、すべて拒む。
//     すべてのサービスに、数値の UID:GID（どちらも 0 でない）の user を求める。
//   - compose.override.yaml（あれば）: サービス app の volumes に .:/app の bind を 1 つだけ持つ形のほかは、すべて拒む。
//   - Dockerfile: 命令は許可の一覧（FROM・RUN・COPY・ARG・ENV・WORKDIR・USER・LABEL・EXPOSE）だけ。build の context から
//     ファイルを読む命令（--from の無い COPY、ADD、from の無い RUN --mount=type=bind）、先頭の指示（syntax・escape）、
//     BUILDKIT_SYNTAX、USER の root、ダイジェストの無い FROM、後に作るイメージへ受け継がれる ENV の名前（PATH など）を拒む。
//     行の継続は BuildKit と同じく空白を挟まずにつなぎ、逆斜線の直前が空白でない継続は拒む。build の target の段の
//     最後の利用者が root でないことを確かめる。疑わしい形は、読み方を広く取って拒む側に倒す。
//   - 根の直下: ほかの名前の Compose の定義（docker-compose.yml など。大文字・小文字の違いを含む）、Dockerfile ごとの ignore
//     ファイル（Dockerfile.dockerignore など）、COMPOSE_・DOCKER_ で始まる変数を書いた .env と、1 行 1 つの「名前=値」でない
//     .env を拒む。Dockerfile の命令の設定（-- で始まる語）の引用符も拒む。
// 終了コード: 0 = 合格 / 1 = 不合格（理由を標準エラーへ 1 行ずつ）/ 2 = 使い方の誤りや道具の不足
import fs from 'node:fs'
import path from 'node:path'
import { pathToFileURL } from 'node:url'

const YAML_VERSION = '2.9.1'
const MAX_BYTES = 65536
const violations = []
const add = (file, msg) => violations.push(`${file}: ${msg}`)
const die = (msg) => {
  process.stderr.write(`check-compose: ${msg}\n`)
  process.exit(2)
}
// 思わぬ例外は不合格（1）と取り違えないように、道具の不足（2）として終える
process.on('uncaughtException', (e) => die(`検査の本体が例外で止まりました（${String(e && e.message).split('\n')[0]}）`))

const root = process.argv[2]
const toolRoot = process.argv[3]
if (!root || !toolRoot || process.argv.length !== 4) {
  process.stderr.write('使い方: node check-compose.mjs <根> <道具の根>\n')
  process.exit(2)
}
if (!fs.existsSync(root) || !fs.statSync(root).isDirectory()) die(`根がディレクトリではありません: ${root}`)
if (!fs.existsSync(toolRoot) || !fs.statSync(toolRoot).isDirectory()) die(`道具の根がディレクトリではありません: ${toolRoot}`)

// YAML の道具を、道具の根の node_modules/yaml だけから読む（上のディレクトリの node_modules は使わない）。
// 実体のパスが道具の根の node_modules の中にあり、版が決めたものであることを確かめる。node_modules そのものがシンボリック
// リンクの形（試し検査の写しが本物の根の node_modules を指す形）は許し、そのリンク先の中にあることを確かめる
async function loadYaml() {
  const nm = path.join(toolRoot, 'node_modules')
  const missing = 'yaml のパッケージがありません（根の node_modules/yaml。npm ci で devDependencies を入れてください）'
  let nmReal, pkgReal, rootReal, nmIsLink
  try {
    rootReal = fs.realpathSync(toolRoot)
    nmIsLink = fs.lstatSync(nm).isSymbolicLink()
    nmReal = fs.realpathSync(nm)
    pkgReal = fs.realpathSync(path.join(nm, 'yaml'))
  } catch {
    die(missing)
  }
  if (!nmIsLink && nmReal !== path.join(rootReal, 'node_modules')) die(`根の node_modules の実体が根の中にありません（${nmReal}）`)
  if (!pkgReal.startsWith(nmReal + path.sep)) die(`根の node_modules/yaml の実体が根の node_modules の中にありません（${pkgReal}。リンクで外の yaml を使わせないため）`)
  let pkg
  try {
    pkg = JSON.parse(fs.readFileSync(path.join(pkgReal, 'package.json'), 'utf8'))
  } catch {
    die(missing)
  }
  if (!pkg || pkg.name !== 'yaml' || pkg.version !== YAML_VERSION) {
    die(`根の node_modules/yaml の版が ${YAML_VERSION} ではありません（${pkg && pkg.version}。npm install --save-dev --save-exact yaml@${YAML_VERSION} で入れてください）`)
  }
  let entry
  try {
    entry = fs.realpathSync(path.join(pkgReal, 'dist', 'index.js'))
  } catch {
    die(missing)
  }
  if (!entry.startsWith(pkgReal + path.sep)) die(`yaml の入口が yaml のパッケージの中にありません（${entry}）`)
  const mod = await import(pathToFileURL(entry).href)
  return mod.default ?? mod
}
const YAML = await loadYaml()

const isMap = (v) => v !== null && typeof v === 'object' && !Array.isArray(v)
const isStr = (v) => typeof v === 'string'
const isStrList = (v) => Array.isArray(v) && v.every(isStr)
const keysOf = (v) => (isMap(v) ? Object.keys(v) : [])
const show = (v) => (isStr(v) ? v : JSON.stringify(v))

// 根の直下のファイルを読む（無ければ null）。シンボリックリンクと通常のファイルでないものは拒む
function readRootFile(name) {
  const p = path.join(root, name)
  let st
  try {
    st = fs.lstatSync(p)
  } catch {
    return null
  }
  if (st.isSymbolicLink()) {
    add(name, 'シンボリックリンクは使えません（リンク先のファイルを読ませないため）')
    return null
  }
  if (!st.isFile()) {
    add(name, '通常のファイルではありません')
    return null
  }
  if (st.size > MAX_BYTES) {
    add(name, `${MAX_BYTES} バイトを超えています（${st.size} バイト）`)
    return null
  }
  return fs.readFileSync(p, 'utf8')
}

// 原文の文字の検査（YAML・Dockerfile・.env）。行番号は最初に見つけた行（行は LF で数える）
function rawRule(file, text, re, msg) {
  const lines = text.split('\n')
  for (let i = 0; i < lines.length; i++) {
    if (re.test(lines[i])) {
      add(file, `${msg}（${i + 1} 行目）`)
      return
    }
  }
}
function rawControlChars(file, text) {
  // タブと改行のほかの制御文字（見えない文字で読み方を変えさせないため）
  rawRule(file, text, /[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/, '制御文字は使えません')
  // 行の区切りの読み方が読み取りの道具ごとに分かれる文字。Compose の YAML の読み取り（go-yaml）は CR と U+0085 を行の
  // 区切りとして読むが、この検査の読み取り（yaml）は注釈を閉じない。注釈の中に項目を隠させないため、すべて拒む
  rawRule(file, text, /\r/, 'CR（復帰。改行の CRLF を含む）は使えません（行の区切りの読み方が Compose とこの検査で分かれ、注釈の中に項目を隠せるため。改行は LF だけにしてください）')
  rawRule(file, text, /\u0085/, 'U+0085（次の行）は使えません（行の区切りとして読む読み取りがあり、注釈の中に項目を隠せるため）')
  rawRule(file, text, /[\u2028\u2029]/, 'U+2028・U+2029（行と段落の区切り）は使えません（行の区切りとして読む読み取りがあり、注釈の中に項目を隠せるため）')
  rawRule(file, text, /\uFEFF/, 'U+FEFF（BOM）は使えません（読み取りの道具ごとに扱いが分かれるため）')
}

// ---- YAML の読み取り ---------------------------------------------------------------
function parseYaml(file, text) {
  rawControlChars(file, text)
  rawRule(file, text, /\$/, '$ による展開は使えません（ホストの環境変数で値を埋めさせないため）')
  rawRule(file, text, /\\/, '逆斜線は使えません（引用の中の escape で項目の名前を隠せるため）')
  let docs
  try {
    docs = YAML.parseAllDocuments(text, { uniqueKeys: true, merge: false, strict: true, version: '1.2', schema: 'core', prettyErrors: false })
  } catch (e) {
    add(file, `YAML として読めません（${String(e && e.message).split('\n')[0]}）`)
    return undefined
  }
  const list = Array.isArray(docs) ? docs : [docs]
  if (list.length !== 1) {
    add(file, `YAML の文書は 1 つだけにしてください（${list.length} 個あります）`)
    if (list.length === 0) return undefined
  }
  let readable = true
  for (const doc of list) {
    for (const e of doc.errors) {
      add(file, `YAML として読めません（${e.code}: ${String(e.message).split('\n')[0]}）`)
      readable = false
    }
    for (const w of doc.warnings) add(file, `YAML の読み取りで警告が出ました（${w.code}: ${String(w.message).split('\n')[0]}）`)
    if (doc.directives && ((doc.directives.yaml && doc.directives.yaml.explicit) || Object.keys(doc.directives.tags || {}).some((h) => h !== '!' && h !== '!!'))) {
      add(file, 'YAML の指示（%YAML・%TAG）は使えません')
    }
    YAML.visit(doc, {
      Node(_, node) {
        if (node.anchor) add(file, `YAML の anchor（&${node.anchor}）は使えません`)
        if (node.tag) add(file, `YAML の型の印（${node.tag}）は使えません`)
      },
      Alias(_, node) {
        add(file, `YAML の alias（*${node.source}）は使えません`)
      },
      Pair(_, pair) {
        const k = pair.key
        if (!YAML.isScalar(k) || typeof k.value !== 'string') {
          add(file, `項目の名前は文字だけにしてください（${k === null ? '空' : String(YAML.isScalar(k) ? k.value : '構造')}）`)
        } else if (k.value === '<<') {
          add(file, 'merge key（<<）は使えません')
        }
      },
    })
  }
  if (!readable) return undefined
  try {
    return list[0].toJS({ maxAliasCount: 100 })
  } catch (e) {
    add(file, `YAML を値に直せません（${String(e && e.message).split('\n')[0]}）`)
    return undefined
  }
}

// ---- compose.yaml ------------------------------------------------------------------
const SERVICE_KEYS = ['image', 'build', 'command', 'environment', 'healthcheck', 'depends_on', 'volumes', 'ports', 'init', 'user', 'working_dir', 'networks']
const BUILD_KEYS = ['context', 'dockerfile', 'target', 'args']
const HEALTH_KEYS = ['test', 'interval', 'timeout', 'retries', 'start_period', 'start_interval', 'disable']
const NAME_RE = /^[A-Za-z0-9][A-Za-z0-9_.-]*$/

// 名前を特別に扱う項目（設計の許可の一覧で、名指しで拒むもの）。当たれば理由を返す
function namedDeny(key) {
  if (key.startsWith('x-')) return 'x- で始まる項目は使えません'
  if (key === 'include') return 'include は使えません（ホストのほかのファイルを読ませないため）'
  if (key === 'extends') return 'extends は使えません（ホストのほかのファイルを読ませないため）'
  if (key === 'env_file') return 'env_file は使えません（ホストのファイルの値を埋めさせないため）'
  if (key === 'secrets' || key === 'configs') return `secrets・configs は使えません（${key}）`
  return null
}

function checkEnvLike(file, where, v, what) {
  // 対応表（値は文字だけ）か、「名前=値」の文字の並び。値の無い項目はホストの値を受け継ぐので拒む
  if (isMap(v)) {
    for (const [k, val] of Object.entries(v)) {
      if (!isStr(val)) add(file, `${where} の ${what} に文字でない値（値の無い受け継ぎの項目など）があります（${k}）`)
    }
    return Object.keys(v)
  }
  if (Array.isArray(v)) {
    const names = []
    for (const item of v) {
      if (!isStr(item) || !item.includes('=')) add(file, `${where} の ${what} に文字でない値（値の無い受け継ぎの項目など）があります（${show(item)}）`)
      else names.push(item.slice(0, item.indexOf('=')))
    }
    return names
  }
  add(file, `${where} の ${what} の形が不正です`)
  return []
}

function checkComposeVolumes(file, s, list, topVolumes) {
  if (!Array.isArray(list)) {
    add(file, `サービス ${s} の volumes の形が不正です`)
    return
  }
  for (const m of list) {
    if (isStr(m)) {
      const parts = m.split(':')
      if (parts.length < 2 || parts.length > 3) {
        add(file, `サービス ${s} の volumes の ${m} は「名前付き volume:置き先」の形にしてください（名前の無い volume は使えません）`)
        continue
      }
      const [src, dst, mode] = parts
      // Windows のドライブの形（c:/Users など）は、Compose がホストのパスとして読む
      if (/^[A-Za-z]:/.test(m) && (src.length === 1 || /^[A-Za-z]:[\\/]/.test(m))) {
        add(file, `サービス ${s} の volumes に bind があります（Windows のドライブの形のホストのパス: ${m}）`)
        continue
      }
      if (/^[./~]/.test(src) || src.includes('/') || src === '') {
        add(file, `サービス ${s} の volumes に bind があります（名前付き volume だけです: ${src} → ${dst}）`)
        continue
      }
      if (!Object.prototype.hasOwnProperty.call(topVolumes, src)) add(file, `サービス ${s} の volume ${src} は最上位の volumes にありません`)
      if (mode !== undefined && !['ro', 'rw', 'nocopy'].includes(mode)) add(file, `サービス ${s} の volumes の ${m} の ${mode} は許可されていません`)
      if (!dst || !dst.startsWith('/')) add(file, `サービス ${s} の volumes の ${m} の置き先は絶対のパスにしてください`)
    } else if (isMap(m)) {
      const type = m.type
      if (type !== 'volume') {
        add(file, `サービス ${s} の volumes に ${type === undefined ? '種類の無い項目' : show(type)} があります（名前付き volume だけです: ${show(m.source ?? '')} → ${show(m.target ?? '')}）`)
        continue
      }
      for (const k of keysOf(m)) if (!['type', 'source', 'target', 'read_only', 'volume'].includes(k)) add(file, `サービス ${s} の volumes の ${k} は許可されていません`)
      if (!isStr(m.source) || !Object.prototype.hasOwnProperty.call(topVolumes, m.source)) add(file, `サービス ${s} の volume ${show(m.source ?? '（名前なし）')} は最上位の volumes にありません`)
      if (!isStr(m.target) || !m.target.startsWith('/')) add(file, `サービス ${s} の volumes の target は絶対のパスにしてください`)
      if (m.read_only !== undefined && typeof m.read_only !== 'boolean') add(file, `サービス ${s} の volumes の read_only は真偽値だけです`)
      if (m.volume !== undefined && (!isMap(m.volume) || keysOf(m.volume).some((k) => k !== 'nocopy'))) add(file, `サービス ${s} の volumes の volume の項目は nocopy だけです`)
    } else {
      add(file, `サービス ${s} の volumes の形が不正です（${show(m)}）`)
    }
  }
}

function checkPorts(file, s, list) {
  if (!Array.isArray(list)) {
    add(file, `サービス ${s} の ports の形が不正です`)
    return
  }
  for (const p of list) {
    if (isStr(p)) {
      if (!/^127\.0\.0\.1:([0-9]+(-[0-9]+)?)?:[0-9]+(-[0-9]+)?(\/(tcp|udp))?$/.test(p)) add(file, `サービス ${s} の ports は 127.0.0.1 だけです（${p}）`)
    } else if (isMap(p)) {
      if (p.host_ip !== '127.0.0.1') add(file, `サービス ${s} の ports は 127.0.0.1 だけです（${show(p.host_ip ?? '全てのアドレス')}:${show(p.published ?? '')}:${show(p.target ?? '')}）`)
      for (const k of keysOf(p)) if (!['host_ip', 'target', 'published', 'protocol', 'mode', 'name', 'app_protocol'].includes(k)) add(file, `サービス ${s} の ports の ${k} は許可されていません`)
    } else {
      add(file, `サービス ${s} の ports は 127.0.0.1 だけです（${show(p)}。全てのアドレスで待ち受ける形）`)
    }
  }
}

function checkBuild(file, s, b) {
  if (isStr(b)) b = { context: b }
  if (!isMap(b)) {
    add(file, `サービス ${s} の build の形が不正です`)
    return null
  }
  for (const k of keysOf(b)) {
    const deny = namedDeny(k)
    if (deny) add(file, `サービス ${s} の build: ${deny}`)
    else if (!BUILD_KEYS.includes(k)) add(file, `サービス ${s} の build.${k} は許可されていません`)
  }
  if (b.context !== undefined && b.context !== '.') add(file, `サービス ${s} の build.context は . だけです（${show(b.context)}）`)
  if (b.dockerfile !== undefined && b.dockerfile !== 'Dockerfile') {
    add(file, `サービス ${s} の build.dockerfile は context の中の相対のパスの、直下の Dockerfile だけです（${show(b.dockerfile)}。承認のハッシュに入らないファイルで build させないため）`)
  }
  if (b.target !== undefined && !isStr(b.target)) add(file, `サービス ${s} の build.target は文字だけです`)
  if (b.args !== undefined) {
    if (isMap(b.args) || Array.isArray(b.args)) {
      const where = `サービス ${s} の build.args`
      const before = violations.length
      const names = checkEnvLike(file, `サービス ${s}`, b.args, 'build.args')
      for (let i = before; i < violations.length; i++) violations[i] += '（build.args は文字の値だけにしてください。値の無い項目はホストの値を受け継ぐ）'
      if (names.some((n) => n.toUpperCase() === 'BUILDKIT_SYNTAX') || (isMap(b.args) && keysOf(b.args).some((n) => n.toUpperCase() === 'BUILDKIT_SYNTAX'))) {
        add(file, `${where} の BUILDKIT_SYNTAX は使えません（build の frontend を外部のイメージに差し替えられるため）`)
      }
    } else {
      add(file, `サービス ${s} の build.args は文字の値だけにしてください（形が不正です）`)
    }
  }
  return isStr(b.target) && b.target !== '' ? b.target : null
}

function checkHealthcheck(file, s, h) {
  if (!isMap(h)) {
    add(file, `サービス ${s} の healthcheck の形が不正です`)
    return
  }
  for (const k of keysOf(h)) if (!HEALTH_KEYS.includes(k)) add(file, `サービス ${s} の healthcheck.${k} は許可されていません`)
  if (h.test !== undefined && !isStr(h.test) && !isStrList(h.test)) add(file, `サービス ${s} の healthcheck.test は文字か文字の並びだけです`)
  for (const k of ['interval', 'timeout', 'start_period', 'start_interval']) if (h[k] !== undefined && !isStr(h[k])) add(file, `サービス ${s} の healthcheck.${k} は文字だけです`)
  if (h.retries !== undefined && !Number.isInteger(h.retries)) add(file, `サービス ${s} の healthcheck.retries は整数だけです`)
  if (h.disable !== undefined && typeof h.disable !== 'boolean') add(file, `サービス ${s} の healthcheck.disable は真偽値だけです`)
}

function checkCompose(file, top) {
  if (!isMap(top)) {
    add(file, '最上位が対応表（項目の名前と値の組）ではありません')
    return { usesBuild: false, targets: [] }
  }
  for (const k of keysOf(top)) {
    const deny = namedDeny(k)
    if (deny) add(file, deny)
    else if (!['services', 'volumes', 'networks'].includes(k)) add(file, `最上位の ${k} は許可されていません`)
  }
  const topVolumes = top.volumes ?? {}
  const topNetworks = top.networks ?? {}
  if (!isMap(topVolumes)) add(file, '最上位の volumes の形が不正です')
  else {
    for (const [n, v] of Object.entries(topVolumes)) {
      if (!NAME_RE.test(n)) add(file, `volume の名前 ${n} が不正です`)
      else if (n.length === 1) add(file, `volume の名前 ${n} は 1 文字にできません（Windows のドライブの名前と取り違えて、ホストのパスとして読まれるため）`)
      if (v === null) continue
      if (!isMap(v)) {
        add(file, `volume ${n} の形が不正です`)
        continue
      }
      for (const k of keysOf(v)) {
        if (k === 'external') {
          if (v.external !== false) add(file, `volume ${n} の external は許可されていません（既存の volume を重ねさせないため）`)
        } else add(file, `volume ${n} の ${k} は許可されていません`)
      }
    }
  }
  if (!isMap(topNetworks)) add(file, '最上位の networks の形が不正です')
  else {
    for (const [n, v] of Object.entries(topNetworks)) {
      if (!NAME_RE.test(n)) add(file, `network の名前 ${n} が不正です`)
      if (v === null) continue
      if (!isMap(v)) {
        add(file, `network ${n} の形が不正です`)
        continue
      }
      for (const k of keysOf(v)) {
        if (k === 'external') {
          if (v.external !== false) add(file, `network ${n} の external は許可されていません（既存のネットワークにつながせないため）`)
        } else if (k === 'driver') {
          if (v.driver !== 'bridge') add(file, `network ${n} の driver は bridge だけです`)
        } else if (k === 'internal') {
          if (typeof v.internal !== 'boolean') add(file, `network ${n} の internal は真偽値だけです`)
        } else add(file, `network ${n} の ${k} は許可されていません`)
      }
    }
  }
  const services = top.services
  if (!isMap(services) || Object.keys(services).length === 0) {
    add(file, 'services がありません')
    return { usesBuild: false, targets: [] }
  }
  let usesBuild = false
  const targets = []
  for (const [s, v] of Object.entries(services)) {
    if (!NAME_RE.test(s)) add(file, `サービスの名前 ${s} が不正です`)
    if (!isMap(v)) {
      add(file, `サービス ${s} の形が不正です`)
      continue
    }
    for (const k of keysOf(v)) {
      const deny = namedDeny(k)
      if (deny) add(file, `サービス ${s}: ${deny}`)
      else if (!SERVICE_KEYS.includes(k)) add(file, `サービス ${s} の ${k} は許可されていません`)
    }
    const hasImage = Object.prototype.hasOwnProperty.call(v, 'image')
    const hasBuild = Object.prototype.hasOwnProperty.call(v, 'build')
    if (hasImage && hasBuild) add(file, `サービス ${s} は image と build を同時に持てません`)
    if (!hasImage && !hasBuild && !keysOf(v).some((k) => namedDeny(k))) add(file, `サービス ${s} に image も build もありません`)
    if (hasImage && (!isStr(v.image) || !/@sha256:[0-9a-f]{64}$/.test(v.image))) add(file, `サービス ${s} の image はダイジェスト（@sha256:…）付きにしてください（${show(v.image)}）`)
    if (hasBuild) {
      usesBuild = true
      // target を省いた（空文字を含む）サービスは最後の段で build されるので、null（最後の段）として加える
      const t = checkBuild(file, s, v.build)
      if (!targets.includes(t)) targets.push(t)
    }
    if (v.command !== undefined && v.command !== null && !isStr(v.command) && !isStrList(v.command)) add(file, `サービス ${s} の command の形が不正です`)
    if (v.environment !== undefined) checkEnvLike(file, `サービス ${s}`, v.environment, 'environment')
    if (v.healthcheck !== undefined) checkHealthcheck(file, s, v.healthcheck)
    if (v.depends_on !== undefined) {
      const d = v.depends_on
      const names = Array.isArray(d) ? d : isMap(d) ? Object.keys(d) : null
      if (names === null) add(file, `サービス ${s} の depends_on の形が不正です`)
      else {
        for (const n of names) if (!isStr(n) || !Object.prototype.hasOwnProperty.call(services, n)) add(file, `サービス ${s} の depends_on の ${show(n)} はありません`)
        if (isMap(d)) {
          for (const [n, c] of Object.entries(d)) {
            if (c === null) continue
            if (!isMap(c)) {
              add(file, `サービス ${s} の depends_on の ${n} の形が不正です`)
              continue
            }
            for (const k of keysOf(c)) if (!['condition', 'required', 'restart'].includes(k)) add(file, `サービス ${s} の depends_on の ${k} は許可されていません`)
            if (c.condition !== undefined && !['service_started', 'service_healthy', 'service_completed_successfully'].includes(c.condition)) add(file, `サービス ${s} の depends_on の condition が不正です`)
          }
        }
      }
    }
    if (v.volumes !== undefined) checkComposeVolumes(file, s, v.volumes, isMap(topVolumes) ? topVolumes : {})
    if (v.ports !== undefined) checkPorts(file, s, v.ports)
    if (v.init !== undefined && typeof v.init !== 'boolean') add(file, `サービス ${s} の init は真偽値だけです`)
    if (v.working_dir !== undefined && !isStr(v.working_dir)) add(file, `サービス ${s} の working_dir は文字だけです`)
    // user は必須で、数値の UID:GID（どちらも 0 でない）だけ。起動の時にイメージの USER より優先し、名前の解決
    // （イメージの中の利用者の一覧）に頼らないので、Dockerfile の RUN で passwd を書き換えても、外のイメージの既定が root でも効く
    if (v.user === undefined) {
      add(file, `サービス ${s} に user がありません（数値の UID:GID で、どちらも 0 でないものを書いてください。例 "1000:1000"。書かないとイメージの既定の利用者〔root もありうる〕で動くため）`)
    } else {
      const p = composeUserProblem(v.user)
      if (p) add(file, `サービス ${s} の user に root は使えません（数値の UID:GID で、どちらも 0 でない利用者だけ: ${show(v.user)}。${p}）`)
    }
    if (v.networks !== undefined) {
      const n = v.networks
      const names = Array.isArray(n) ? n : isMap(n) ? Object.keys(n) : null
      if (names === null) add(file, `サービス ${s} の networks の形が不正です`)
      else {
        for (const x of names) if (!isStr(x) || (x !== 'default' && !(isMap(topNetworks) && Object.prototype.hasOwnProperty.call(topNetworks, x)))) add(file, `サービス ${s} の network ${show(x)} は最上位の networks にありません`)
        if (isMap(n)) {
          for (const [x, c] of Object.entries(n)) {
            if (c === null) continue
            if (!isMap(c)) add(file, `サービス ${s} の networks.${x} の形が不正です`)
            else for (const k of keysOf(c)) if (k !== 'aliases') add(file, `サービス ${s} の networks.${x}.${k} は許可されていません`)
            if (isMap(c) && c.aliases !== undefined && !isStrList(c.aliases)) add(file, `サービス ${s} の networks.${x}.aliases は文字の並びだけです`)
          }
        }
      }
    }
  }
  return { usesBuild, targets }
}

// ---- compose.override.yaml（人が使う .:/app の bind だけ） -------------------------
function checkOverride(file, top) {
  const only = '（compose.override.yaml では、サービス app の volumes の .:/app の bind 1 つだけを許します）'
  if (!isMap(top)) {
    add(file, `最上位が対応表（項目の名前と値の組）ではありません${only}`)
    return
  }
  for (const k of keysOf(top)) {
    const deny = namedDeny(k)
    if (deny) add(file, deny)
    else if (k !== 'services') add(file, `最上位の ${k} は許可されていません${only}`)
  }
  const services = top.services
  if (!isMap(services) || !isMap(services.app)) {
    add(file, `サービス app がありません${only}`)
    return
  }
  for (const s of keysOf(services)) if (s !== 'app') add(file, `サービス ${s} は書けません${only}`)
  const app = services.app
  for (const k of keysOf(app)) {
    const deny = namedDeny(k)
    if (deny) add(file, `サービス app: ${deny}`)
    else if (k !== 'volumes') add(file, `サービス app の ${k} は許可されていません${only}`)
  }
  const vols = app.volumes
  if (!Array.isArray(vols) || vols.length !== 1 || vols[0] !== '.:/app') {
    add(file, `サービス app の volumes は .:/app の bind 1 つだけです（${show(vols)}）`)
  }
}

// ---- Dockerfile --------------------------------------------------------------------
// 命令の許可の一覧。この Dockerfile のイメージ（L1）の上に、エージェントの実行環境のイメージ（L2）を作るので、L2 の build と
// 起動へ受け継がれる設定を変える命令（ONBUILD・SHELL・ENTRYPOINT・CMD・VOLUME・HEALTHCHECK・STOPSIGNAL）を許さない
const DF_ALLOWED = ['FROM', 'RUN', 'COPY', 'ARG', 'ENV', 'WORKDIR', 'USER', 'LABEL', 'EXPOSE']
const DF_DENY_REASON = {
  ADD: 'build の context のファイルと URL を読むため',
  ONBUILD: 'このイメージを土台にする build（エージェントの実行環境のイメージ）で、後から命令を動かすため',
  SHELL: 'このイメージを土台にする build の RUN を動かすシェルを変えるため',
  ENTRYPOINT: '起動の入口を変えさせないため',
  CMD: '起動のコマンドは compose.yaml の command に書くため',
  VOLUME: 'このイメージを土台にするコンテナに、名前の無い volume を作らせるため',
  HEALTHCHECK: 'このイメージを土台にするコンテナの中で、定期的にコマンドを動かすため',
  STOPSIGNAL: 'このイメージを土台にするコンテナの止め方を変えるため',
  MAINTAINER: '古い命令で、使う理由が無いため',
}
// ENV で書けない名前。このイメージを土台にする build と起動へ受け継がれ、コマンドの探し先・読み込むライブラリ・
// シェルやツールの起動時の動きを変えられるもの
const ENV_DENY_RE = /^(PATH|ENV|BASH_ENV|SHELLOPTS|BASHOPTS|PS4|IFS|CDPATH|PROMPT_COMMAND|HOME|SHELL|LD_.*|DYLD_.*|NODE_OPTIONS|NODE_PATH|NODE_EXTRA_CA_CERTS|NODE_TLS_REJECT_UNAUTHORIZED|NPM_CONFIG_.*|GIT_.*|PERL5OPT|PERL5LIB|PERLLIB|PYTHONPATH|PYTHONSTARTUP|PYTHONHOME|RUBYOPT|RUBYLIB|SSL_CERT_FILE|SSL_CERT_DIR|CURL_CA_BUNDLE|HTTP_PROXY|HTTPS_PROXY|ALL_PROXY|NO_PROXY)$/i
const DIGEST_RE = /@sha256:[0-9a-f]{64}$/
const USER_RE = /^[A-Za-z0-9_][A-Za-z0-9_.-]*(:[A-Za-z0-9_][A-Za-z0-9_.-]*)?$/
const COPY_FLAGS = ['from', 'chown', 'chmod', 'link', 'parents', 'exclude']

// 利用者（USER と compose の user）の値の問題を返す。問題が無ければ null
function userProblem(v) {
  if (/\$/.test(v)) return '$ は使えません（build の引数や環境変数で root にさせないため）'
  if (!USER_RE.test(v)) return `名前か番号（と「:」の後のグループ）だけにしてください（${v}。引用符・符号・空白は使えません）`
  const [u, g] = v.split(':')
  if (u.toLowerCase() === 'root' || /^0+$/.test(u)) return `root は使えません（${v}。0 だけの番号も root です）`
  if (g !== undefined && (g.toLowerCase() === 'root' || /^0+$/.test(g))) return `グループに root（0）は使えません（${v}）`
  return null
}
// compose の user の問題を返す（数値の UID:GID で、どちらも 0 でないものだけを許す）
function composeUserProblem(v) {
  if (!isStr(v)) return '文字だけにしてください'
  const m = /^([0-9]+):([0-9]+)$/.exec(v)
  if (!m) return `数値の UID:GID の形ではありません（名前は、イメージの中の利用者の一覧〔passwd〕の書き換えで 0 にできるため。符号・空白も使えません）`
  if (/^0+$/.test(m[1])) return 'UID が 0 です（0 だけの番号も root です）'
  if (/^0+$/.test(m[2])) return 'グループに root（0）は使えません'
  return null
}
const isRootUser = (u) => u === null || u.split(':')[0].toLowerCase() === 'root' || /^0+$/.test(u.split(':')[0])

// 引数の先頭の --設定 を読む。「--」だけの語で設定の並びは終わり、その後の語は --設定 の形でも設定ではない
function leadingFlags(args) {
  const toks = args.trim().split(/\s+/).filter(Boolean)
  const flags = []
  let i = 0
  for (; i < toks.length; i++) {
    const t = toks[i]
    if (t === '--') {
      i++
      break
    }
    if (!t.startsWith('--')) break
    const eq = t.indexOf('=')
    flags.push({ raw: t, name: (eq < 0 ? t.slice(2) : t.slice(2, eq)).toLowerCase(), value: eq < 0 ? null : t.slice(eq + 1) })
  }
  return { flags, rest: toks.slice(i) }
}
// 値を囲む 1 組の引用符を外す
const unquote = (v) => (/^"[^"]*"$/.test(v) || /^'[^']*'$/.test(v) ? v.slice(1, -1) : v)

// COPY --from・mount の from の値の問題を返す。それより前の段の名前か番号、またはダイジェスト付きのイメージだけを許す
function refProblem(raw, ctx) {
  const v = unquote(raw)
  if (v === '') return '値が空です'
  if (/[$"'\\]/.test(v)) return `$・引用符・逆斜線は使えません（${raw}）`
  const prior = ctx.stages.slice(0, ctx.cur)
  if (prior.some((s) => s.name === v.toLowerCase())) return null
  if (/^[0-9]+$/.test(v) && Number(v) < prior.length) return null
  if (DIGEST_RE.test(v)) return null
  return `それより前の段の名前か、ダイジェスト（@sha256:…）付きのイメージだけです（${raw}）`
}

// 1 つの命令（名前と引数）を確かめる。ctx は段の一覧（名前と最後の利用者）と、いまの段の番号。
// nested は ONBUILD の中の命令（段の一覧を変えない）
function checkInstruction(file, where, name, args, ctx, nested) {
  const up = name.toUpperCase()
  if (up === 'ONBUILD') {
    add(file, `${where}: ONBUILD は使えません（${DF_DENY_REASON.ONBUILD}）`)
    const m = /^\s*(\S+)\s*([\s\S]*)$/.exec(args)
    if (m) checkInstruction(file, `${where}の ONBUILD`, m[1], m[2], ctx, true)
    return
  }
  if (!DF_ALLOWED.includes(up)) {
    if (DF_DENY_REASON[up]) add(file, `${where}: ${up} は使えません（${DF_DENY_REASON[up]}）`)
    else add(file, `${where}: 命令 ${up} は使えません（許可の一覧 ${DF_ALLOWED.join('・')} に無い命令です）`)
    if (up !== 'ADD') return
  }
  // 設定（-- で始まる語）の引用符は拒む。BuildKit は引用符の中の空白を区切りにしないが、この検査は空白で語を分けるので、
  // 引用符の中に偽の設定（--exclude=" --from=base " など）を隠せるため。BuildKit の読み方を真似るより、拒むほうを選ぶ
  if (['ADD', 'COPY', 'RUN', 'FROM'].includes(up)) {
    for (const f of leadingFlags(args).flags) {
      if (/["']/.test(f.raw)) add(file, `${where}: ${up} の設定に引用符は使えません（${f.raw}。引用符の中の空白で、設定の区切りの読み方が BuildKit とこの検査で分かれるため）`)
    }
  }
  if (up === 'ADD' || up === 'COPY') {
    if (/<</.test(args)) add(file, `${where}: ${up} のヒアドキュメント（<<）は使えません（後の行を命令でなく中身として読ませ、命令の区切りの読み方を変えるため）`)
    const { flags } = leadingFlags(args)
    for (const f of flags) {
      if (/[$\\]/.test(f.raw)) add(file, `${where}: ${up} の設定に $ と逆斜線は使えません（${f.raw}。build の引数で読み元を変えさせないため）`)
      else if (up === 'COPY' && !COPY_FLAGS.includes(f.name)) add(file, `${where}: COPY の設定 --${f.name} は許可されていません`)
    }
    if (up === 'COPY') {
      const from = flags.filter((f) => f.name === 'from')
      if (from.length === 0 || from.some((f) => f.value === null)) {
        add(file, `${where}: build の context からの COPY は使えません（--from を付けた COPY だけ: ${args.trim().slice(0, 80)}）`)
      } else {
        for (const f of from) {
          const p = refProblem(f.value, ctx)
          if (p) add(file, `${where}: COPY の --from は、${p}`)
        }
      }
    }
    return
  }
  if (up === 'RUN') {
    if (/<</.test(args)) add(file, `${where}: RUN のヒアドキュメント（<<）は使えません（後の行を命令でなく中身として読ませ、命令の区切りの読み方を変えるため）`)
    for (const f of leadingFlags(args).flags) {
      if (f.name !== 'mount') add(file, `${where}: RUN の設定 --${f.name} は使えません（--mount だけです。build のネットワークや権限を変えさせないため）`)
    }
    return
  }
  if (up === 'ENV') {
    if (/\$/.test(args)) {
      add(file, `${where}: ENV に $ は使えません（build の引数で名前と値を変えさせないため）`)
      return
    }
    const toks = args.trim().split(/\s+/).filter(Boolean)
    const names = toks.length > 0 && !toks[0].includes('=') ? [toks[0]] : [...args.matchAll(/(?:^|\s)([^\s=]+)=/g)].map((m) => m[1])
    for (const n of names) {
      const bare = n.replace(/["'\\]/g, '')
      if (ENV_DENY_RE.test(bare)) add(file, `${where}: ENV の ${bare} は使えません（このイメージを土台にする build と起動へ受け継がれ、コマンドの探し先や起動の動きを変えるため）`)
    }
    return
  }
  if (up === 'USER') {
    const v = args.trim()
    const p = userProblem(v)
    if (p) add(file, `${where}: USER に ${p}`)
    // 形の不正な値（$ を含むものなど）は、最後の利用者の確かめでは root として扱う
    if (!nested && ctx.cur >= 0) ctx.stages[ctx.cur].user = p ? null : v
    return
  }
  if (up === 'FROM') {
    if (/\$/.test(args)) add(file, `${where}: FROM に $ は使えません（build の引数で土台のイメージを変えさせないため）`)
    const { flags, rest } = leadingFlags(args)
    for (const f of flags) if (f.name !== 'platform') add(file, `${where}: FROM の設定 --${f.name} は許可されていません`)
    const image = rest[0] || ''
    const parent = ctx.stages.find((s) => s.name !== null && s.name === image.toLowerCase())
    if (!parent && image.toLowerCase() !== 'scratch' && !DIGEST_RE.test(image)) {
      add(file, `${where}: FROM の土台のイメージはダイジェスト（@sha256:…）付きにしてください（${image}）`)
    }
    if (nested) return
    let stageName = null
    if (rest.length >= 3 && rest[1].toUpperCase() === 'AS') stageName = rest[2].toLowerCase()
    else if (rest.length !== 1) add(file, `${where}: FROM の形が不正です（FROM <イメージ> [AS <段の名前>] だけです）`)
    // 外のイメージの既定の利用者は root として扱う（node の公式イメージの既定は root）
    ctx.stages.push({ name: stageName, user: parent ? parent.user : null, line: where })
    ctx.cur = ctx.stages.length - 1
  }
}

// RUN --mount の設定を確かめる（書かれた場所によらず、論理の行のすべての --mount。type の既定は bind）
function checkMounts(file, lineOf, text, ctx) {
  for (const m of text.matchAll(/--mount(\s|$)/g)) add(file, `${lineOf(m.index)} 行目: --mount は --mount=<設定> の形で書いてください`)
  for (const m of text.matchAll(/--mount=("[^"]*"|'[^']*'|\S+)/g)) {
    const where = `${lineOf(m.index)} 行目`
    const spec = unquote(m[1])
    if (/[$"'\\]/.test(spec)) {
      add(file, `${where}: --mount の設定に $・引用符・逆斜線は使えません（--mount=${m[1]}。build の引数や読み方の違いで種類と読み元を変えさせないため）`)
      continue
    }
    const kv = {}
    for (const part of spec.split(',')) {
      const eq = part.indexOf('=')
      const k = (eq < 0 ? part : part.slice(0, eq)).trim().toLowerCase()
      kv[k] = eq < 0 ? '' : part.slice(eq + 1).trim()
    }
    const type = (kv.type ?? 'bind').toLowerCase()
    if (type === 'bind' && !kv.from) {
      add(file, `${where}: from を付けない RUN --mount=type=bind は使えません（build の context を参照の元にするため: --mount=${spec}）`)
    } else if (kv.from !== undefined && kv.from !== '') {
      const p = refProblem(kv.from, ctx)
      if (p) add(file, `${where}: --mount の from は、${p}`)
    }
  }
}

// targets: compose.yaml の build.target の一覧（空なら最後の段）
function checkDockerfile(file, text, targets) {
  rawControlChars(file, text)
  const lines = text.split('\n')
  // 先頭の指示（parser directive）。指示の位置の決まりに頼らず、どの行にあっても拒む（読み方を広く取る。大文字・小文字と
  // 空白の数によらない）
  lines.forEach((l, i) => {
    if (/^\s*#\s*syntax\s*=/i.test(l)) add(file, `${i + 1} 行目: 先頭の syntax の指示は使えません（build の frontend として外部のイメージを取り込んで実行させるため。ダイジェスト付きでも同じ）`)
    if (/^\s*#\s*escape\s*=/i.test(l)) add(file, `${i + 1} 行目: escape の指示は使えません（行の継続の読み方を変えるため）`)
  })
  rawRule(file, text, /BUILDKIT_SYNTAX/i, 'BUILDKIT_SYNTAX は使えません（build の frontend を外部のイメージに差し替えられるため）')
  // 論理の行（行の継続を連ねた命令）を作る。BuildKit と同じく、継続の行は逆斜線と改行を除いて空白を挟まずにつなぎ、
  // 継続の途中の注釈と空白だけの行は飛ばす。逆斜線の直前が空白でない継続（CO\ と PY など）は、つないだ結果で命令の名前や
  // 設定ができてしまい、行ごとに読む人と道具の読み方が分かれるので拒む
  const logical = []
  let cur = null
  for (let i = 0; i < lines.length; i++) {
    const l = lines[i]
    if (cur === null) {
      if (/^\s*(#|$)/.test(l)) continue
      cur = { start: i, text: '', segs: [] }
    } else if (/^\s*(#|$)/.test(l)) {
      continue
    }
    const m = /\\[ \t]*$/.exec(l)
    let body = l
    if (m) {
      body = l.slice(0, m.index)
      if (body !== '' && !/\s$/.test(body)) add(file, `${i + 1} 行目: 行の継続の逆斜線の直前は空白にしてください（継続の行は空白を挟まずにつながるため、命令の名前や設定を行をまたいで分けて書けてしまう）`)
    }
    cur.segs.push({ off: cur.text.length, line: i + 1 })
    cur.text += body
    if (!m) {
      logical.push(cur)
      cur = null
    }
  }
  if (cur !== null) logical.push(cur)
  const ctx = { stages: [], cur: -1 }
  for (const lg of logical) {
    const lineOf = (pos) => {
      let n = lg.segs[0].line
      for (const s of lg.segs) if (s.off <= pos) n = s.line
      return n
    }
    const m = /^\s*(\S+)\s*([\s\S]*)$/.exec(lg.text)
    if (!m) continue
    const where = `${lg.start + 1} 行目`
    if (ctx.cur < 0 && !['FROM', 'ARG'].includes(m[1].toUpperCase())) add(file, `${where}: 最初の FROM の前に書けるのは ARG だけです（${m[1]}）`)
    checkInstruction(file, where, m[1], m[2], ctx, false)
    checkMounts(file, lineOf, lg.text, ctx)
  }
  // build の target の段（無ければ最後の段）の最後の利用者が root でないこと（元にした段の USER を受け継ぐ）
  if (ctx.stages.length === 0) {
    add(file, 'FROM がありません')
    return
  }
  const want = targets.length > 0 ? targets : [null]
  for (const t of want) {
    const stage = t === null ? ctx.stages[ctx.stages.length - 1] : ctx.stages.find((s) => s.name === t.toLowerCase())
    const label = t === null ? '最後の段' : `build.target の段 ${t}`
    if (!stage) {
      add(file, `${label} がありません`)
      continue
    }
    if (isRootUser(stage.user)) {
      add(file, `${label}（${stage.line}の FROM から）の最後の利用者が root です（土台の node のイメージの既定は root。段の中か元にした段の最後の USER に、root でない利用者を書いてください）`)
    }
  }
}

// ---- .env（Compose が根から自動で読む） -------------------------------------------
// 1 行に 1 つの「名前=値」だけを許す。値は、引用符で始まるなら同じ行の閉じる引用符で終わり、その後ろは注釈だけ。
// 引用符で始まらないなら空白・引用符・# を含まない語で、その後ろは注釈だけ。空行と注釈の行は許す。逆斜線はどこにも書けない。それ以外の構文
// （同じ行の 2 つ目の代入、引用符の中の改行など）は、Compose の読み取りとこの検査で読み方が分かれうるので拒む
const DOTENV_LINE_RE = /^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)=(?:'[^']*'|"[^"]*"|[^\s'"#]*)(?:\s+#.*)?\s*$/
function checkDotEnv(file, text) {
  rawControlChars(file, text)
  text.split('\n').forEach((l, i) => {
    // 逆斜線は、注釈の行を含めてすべて拒む。引用符の中の逆斜線を escape として読む読み取りでは、値が次の行まで続き、
    // 次の行の中身が別の代入になりうるため（Compose の読み方は真似ずに拒む）
    if (/\\/.test(l)) {
      add(file, `${i + 1} 行目: .env に逆斜線は使えません（引用符の escape として読まれると、値が次の行まで続いて、次の行の中身が別の代入になりうるため）`)
      return
    }
    if (/^\s*(#.*)?$/.test(l)) return
    const m = DOTENV_LINE_RE.exec(l)
    if (!m) {
      add(file, `${i + 1} 行目: .env は 1 行に 1 つの「名前=値」だけにしてください（同じ行の 2 つ目の代入や、引用符の中の改行などは、Compose とこの検査で読み方が分かれうるため）`)
      return
    }
    if (/^(COMPOSE|DOCKER)_/i.test(m[1])) add(file, `${i + 1} 行目: COMPOSE_・DOCKER_ で始まる変数は書けません（${m[1]}。COMPOSE_FILE などで、検査していない定義や接続先を Compose に読ませられるため）`)
  })
}

// ---- 根の直下 ----------------------------------------------------------------------
// 名前は小文字に直して比べる（macOS などの大文字・小文字を区別しないファイルシステムでは、Compose.Override.yml なども
// 同じ名前として読まれるため）
const entries = fs.readdirSync(root)
const ALT_COMPOSE = ['compose.yml', 'compose.override.yml', 'docker-compose.yml', 'docker-compose.yaml', 'docker-compose.override.yml', 'docker-compose.override.yaml']
const CANONICAL = ['compose.yaml', 'compose.override.yaml', 'Dockerfile', '.dockerignore', '.env']
for (const n of entries) {
  const low = n.toLowerCase()
  if (ALT_COMPOSE.includes(low)) add(n, 'ほかの名前の Compose の定義は使えません（compose.yaml と compose.override.yaml だけにする。検査していない定義を人の起動で読ませないため）')
  else if (CANONICAL.some((c) => c.toLowerCase() === low && c !== n)) add(n, `名前の大文字・小文字が違います（${CANONICAL.find((c) => c.toLowerCase() === low)} にしてください。大文字・小文字を区別しないファイルシステムでは同じ名前として読まれ、検査と読み方が分かれるため）`)
  if (low !== '.dockerignore' && low.endsWith('.dockerignore')) add(n, 'Dockerfile ごとの ignore ファイルは使えません（直下の .dockerignore より優先され、承認のハッシュに入らないファイルで build の入力が変わるため）')
}

const composeText = readRootFile('compose.yaml')
let usesBuild = false
let targets = []
if (composeText === null) {
  if (!violations.some((v) => v.startsWith('compose.yaml:'))) add('compose.yaml', 'ありません')
} else {
  const top = parseYaml('compose.yaml', composeText)
  if (top !== undefined) ({ usesBuild, targets } = checkCompose('compose.yaml', top))
}
const overrideText = readRootFile('compose.override.yaml')
if (overrideText !== null) {
  const top = parseYaml('compose.override.yaml', overrideText)
  if (top !== undefined) checkOverride('compose.override.yaml', top)
}
const dockerfileText = readRootFile('Dockerfile')
if (dockerfileText !== null) checkDockerfile('Dockerfile', dockerfileText, targets)
else if (usesBuild && !violations.some((v) => v.startsWith('Dockerfile:'))) add('Dockerfile', 'ありません（build を使うサービスがあります）')
const envText = readRootFile('.env')
if (envText !== null) checkDotEnv('.env', envText)

if (violations.length > 0) {
  for (const v of violations) process.stderr.write(`check-compose: 不合格: ${v}\n`)
  process.exit(1)
}
const checked = ['compose.yaml', overrideText !== null ? 'compose.override.yaml' : null, dockerfileText !== null ? 'Dockerfile' : null, envText !== null ? '.env' : null].filter(Boolean)
process.stderr.write(`check-compose: 合格: ${checked.join('・')}\n`)
