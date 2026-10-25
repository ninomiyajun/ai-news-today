# 検査の本体を、規約のひな形の正本の写し・設定・追加の検査の口に置き換える

## 作業の場所

- ブランチ: `refactor/harness-engine-from-template`（`origin/main` の `ac4555f` から）
- worktree のディレクトリ名: `wt-news-p9e`

## 目的

このプロジェクトの検査（`scripts/harness/`）は、利用者の規約のリポジトリ（`~/.agent-rules`。以下 K）のひな形から
手で写して育てたもので、K の正本と中身が離れている。K は、検査の本体を「どのプロジェクトでも同じ中身の写し」として
配り、プロジェクトごとの値を設定のファイル（`scripts/harness/harness.conf`）に、プロジェクトだけの検査を追加の検査の口
（`scripts/harness/checks.d/*.sh`）に置く形に変わった（K の `home/agents/skills/project-harness-init/SKILL.md` の
「設定のファイル」「追加の検査の口」「導入済みのプロジェクトの更新」）。この作業では次を行う。

1. 検査の本体（`check-docs.sh`・`check-docs.test.sh`・`notify.sh`・`notify.test.sh`・`drift-scan.sh`・`drift-scan.test.sh`）と、
   部品 `node-harness`（`stack-adapter.sh`・`stack-adapter.test.sh`）・`node-secrets`（`check-secrets.sh`・`check-secrets.mjs`）の
   検査のファイルを、K の規約の版の印 `rules-2026.10.25-1`（K のコミット `c66d63c`）の正本の写しに置き換える。置き換えは
   K の道具 `scripts/harness-copies.sh update` で行い、手で写さない。
2. このプロジェクトだけの検査 3 つ（今の `check-docs.sh` の検査 12「文書の検査の一覧」・13「通信の名前の一覧」・
   14「層の評価の上限」。以下「T の検査 12〜14」）を、追加の検査の口へ移す。新しい本体の検査 12「検査の由来の記録」・
   13「写しの中身」（以下「本体の検査 12・13」）とは番号が同じで別物である。この計画では必ず書き分ける。
3. 本体の検査 12（検査を定めるファイルを変えた差分に、検査の由来の記録の行が無ければ失敗にする）を、このプロジェクトで
   働かせ、`.dependency-cruiser.cjs` を変えた差分で働くことを確かめる。
4. 写しが正本と同じであることを、K の比べる道具（`harness-copies.sh verify`）で確かめる。

なぜ行うか: 写しが離れると、K の直しがこのプロジェクトへ届かない。また、Dependabot の版だけの更新を止めずに、検査を
定めるファイルの実質の変更にだけ由来の記録を求める仕組み（本体の検査 12 と設定の `record_exempt_line_re`）を入れる。
この作業は、利用者単位の計画 `~/.claude/harness-rollout/p9-plan.md`（以下 P9 の計画）の手順 15（束 E と束 G の (2)。
T-engine）に当たる。検証の節の基準は、P9 の計画の完了の条件 C11・C12・C20 (8)・C21 に対応づける。

前提:

- 製品の仕様は無い（利用者に見える機能を変えない、検査の整理である）。
- 層・依存の向き・不変条件は変えない。`ARCHITECTURE.md` は、検査 13 を指す 1 行（63 行目「`scripts/harness/check-docs.sh` の
  検査 13 も直す」）の参照先だけを直す。関係する ADR は `docs/adr/0001-layers-and-checks.md`（層と検査）、
  `docs/adr/0002-secret-scan-scope.md`（秘匿値の検査）、`docs/adr/0005-early-notify-hooks.md`（早期通知。37 行目が
  `notify-paths.mjs` を実行するファイルに挙げている）、`docs/adr/0006-drift-scan.md`（定期の走査）。
- 置き換えの前の検査の結果（`origin/main` の `ac4555f`、`npm ci` の後の `npm run check`。まとめ役が 2026-10-25 に取った出力で、
  リポジトリの外にある）: 終了コード 0。秘匿値 0 件、vitest 18 ファイル 144 件、`check-docs.sh` OK、`check-docs.test.sh` 175 件、
  `notify.test.sh` 183 件、`lint-rules.test.mjs` 15 件、`check-arch.test.sh` 9 件、`drift-scan.test.sh` 51 件がすべて期待どおり、
  `check-arch.sh` 違反 0 件（48 モジュール、117 の依存）。
- K の `harness-copies.sh verify` をこの worktree で流した結果（2026-10-25、置き換えの前。何も書かない道具）: 終了コード 1。
  「管理されていない写し」が `check-docs.sh`・`check-docs.test.sh`・`notify.sh`・`notify.test.sh`・`drift-scan.sh`・
  `drift-scan.test.sh` の 6 つ、「写しが無い」が `scripts/harness/checks.d/README.md` と `docs/PLANS.md` の 2 つの区画
  （`plan-status-spec`・`plan-cost-spec`。区画の印の行が無い）。部品の写しは、設定のファイルが無く `part=` の行が無いので、
  期待の一覧に出ていない。
- `harness-copies.sh update` は、作業ツリーに未コミットの変更があるとき（K の `scripts/harness-copies.sh` 329〜331 行）と、
  `scripts/harness/harness.conf` が無いとき（同 332〜334 行）と、`docs/PLANS.md` に区画の印の行が無いとき（同 355 行）に、
  書かずに止まる。`--apply` の後の確かめでは、文書の検査が通らないと、その後の試験を流さない（同 488〜508 行）。
- `update` は、設定に `template_version` が無く、写しの冒頭にも版の印が無いとき、期待の一覧の版（`BASE_TAG`）を最新の版の印に
  する（同 177〜184 行）。今回は最新の版の印が `--to` と同じ `rules-2026.10.25-1` なので、描いた物（写しでないひな形から
  作ったファイル）のひな形の差を「知らせる」の行は出ない（同 408〜414 行は `BASE_TAG` と `--to` の正本の差だけを知らせる）。
  手順 6 の時点で `git -C ~/.agent-rules tag -l 'rules-*'` の最新が `rules-2026.10.25-1` であることを確かめる（新しい印があると
  基準の版と由来の記録の向きが変わる。違えば止めてまとめ役に知らせる）。
- Dependabot の PR #24・#25・#26・#36・#37（`package.json`・`package-lock.json` だけ）は、P9 の計画の手順 17 で扱うので、
  この作業では触れない。

### 受け取った前提の棚卸し

選択肢の範囲を限っている前提と、変えると採る案が変わる前提だけを挙げる。

守る前提（変えうる判断として扱わない）:

- 権限と安全の決まり: コミット・push・PR の作成は利用者の明示的な指示の後だけ（利用者単位の規約）。K（`~/.agent-rules`）、
  P9 の計画、このリポジトリの本体の作業ツリーを、この作業で編集しない（まとめ役からの依頼の制約）。
- 利用者が個別に選んだ判断: 束 G の (2) は「行の置き換えだけ」の変更に由来の記録を求めない（2026-10-23 の利用者の決定。
  P9 の計画 10 節「2026-10-23 手順 14（R-template）で決めたこと」の 2 行目）。Dependabot の 5 本の PR に触れない（上の前提）。

上位の計画と既存の作りにある設計判断:

| 前提 | 出どころ | 理由の有無 | 変えた場合の得失 |
|---|---|---|---|
| C12 の確かめは「`check-docs.test.sh` に 3 つの場合を足す」 | P9 の計画 854 行（C12 の行の操作の列） | 理由の記載なし | 変えると C11 との食い違い（下の行）が解ける。P9 の計画の C12 の行を直すことになり、利用者の承認が要る。2026-10-25 の利用者の決定で、このプロジェクトだけの試験に置くと決まった（決まった点の U1） |
| `check-docs.test.sh` は正本の写し（手で変えない） | K の `assets/kinds.tsv` 30 行（`check_docs_test` の 7 列目が `copy`） | 「敷いた後もこのリポジトリの正本が正本です。敷いた先では手で変えず」（K の `SKILL.md` 17〜20 行） | 変えると写しの仕組み（本体の検査 13 と比べる道具）が壊れ、C11 (2)(3) が不合格になる。この作業では変えない |
| T の検査 12〜14 は追加の検査の口へ移す | P9 の計画 1605 行（10 節の表）と 430〜431 行（束 E） | 「プロジェクト専用の検査は、決まった置き場（例: `scripts/harness/checks.d/*.sh`…）に置き、本体が順に読んで実行する」（P9 の計画 430 行） | 本体へ移す案は、2 つ以上のプロジェクトで要る検査に限る決まり（K の `SKILL.md` 271 行「2 つ以上のプロジェクトの `checks.d/` に同じ働きの検査がある…ときは、本体へ移します」）に当たらない |
| 区画の印を、`update` の初回の前に置く | P9 の計画 1607 行 | 「`T` の PLANS.md（9f53336）には区画の印が無い。手順 15 の初回は印を置いてから流す」 | 置かないと `update` が止まる（K の `harness-copies.sh` 355 行）。変える余地は無い |
| `update` は未コミットの変更があると止まる | K の `harness-copies.sh` 329〜331 行 | 理由の記載なし | K を直す案は、K を編集しない制約に反するので採らない。この前提のため、準備の変更を先にコミットする必要がある。2026-10-25 の利用者の決定で、作業用のコミットを作ると決まった（決まった点の U2） |
| CI は 1 本の `harness.yml` で、秘匿値の検査を先に動かす | `.github/workflows/harness.yml` 1〜4 行、33〜57 行 | 「秘匿値の検査を、リポジトリ由来のスクリプトより先に動かす理由は docs/adr/0002-secret-scan-scope.md」（同 4 行） | K のひな形の 2 本（`ci-harness.yml`・`ci-secrets.yml`）に分ける案は、同じ検査を 2 回動かし、秘匿値の検査の後に動く段が 2 本に分かれるだけで、得を 1 文で示せない。1 本のまま保つ。損: K の 2 つのひな形の置き先（`harness-docs.yml`・`harness-secrets.yml`）にファイルが無いので、ひな形が変わっても `update` は知らせない（K の `harness-copies.sh` 410〜414 行は置き先にファイルがあるときだけ知らせる）。そのため ADR 0007 に、更新のたびに 2 つのひな形の差を手で見る手順を書く（手順 13） |
| 写しの版は `rules-2026.10.25-1` | P9 の計画 1643 行からの節（10 節「2026-10-25 手順 15 の前の版の印…」の印を作った記録） | 「手順 15 の前に版の印が要る」「最新の印 `rules-2026.10.23-1` には新しい正本が無く」（P9 の計画 1611 行） | 変える余地は無い（K の手元の最新の印） |

### 選択肢を絞る前の確かめ

- 置き換えの進め方（全体を 1 回の `update` で置き換える）について:
  - 両方を行う案（今の検査を残しつつ写しも置く）: 同じ検査が 2 つになり、本体の検査 13 と比べる道具の対象が分かれる。
    写しの仕組みの目的（中身を 1 つにする）に反する具体的な害があるので外す。
  - 前提を変える案（`update` を使わず手で写す）: K の `SKILL.md` 32〜34 行と 41〜43 行が、写しを置くのはスクリプトだけと
    定める（K の手順の決まり）。手で写すと冒頭の `harness-copy:` の行の版と中身の照合を人が作ることになり、誤りの余地が
    増えるので外す。
  - 既存の実装を変える案（T の今の `check-docs.sh` を直して設定を読ませる）: 束 E の目的（K の正本を正本にする）に届かない
    ので外す。
  - やらない案: P9 の計画の手順 15 そのものをやめることになり、利用者の承認済みの計画を変える。この計画の範囲で決めず、
    外す。
- C12 の試験の置き場（U1）と、`update` の前のコミット（U2）は、利用者に案を比べて示し、下の「決まった点」のとおり決まった。

### 決まった点（利用者の決定。2026-10-25）

設計の中で利用者に仰いだ 3 つの点は、2026-10-25 の利用者の決定で決まった。決定の記録の正本は P9 の計画の 10 節
「2026-10-25 手順 15（T-engine）で決めたこと（会話 910f67f4）」で、決めた理由と外した案はこの計画の判断の記録にも書く。
P9 の計画の側の呼び名（判断 1〜3 と案 A〜C）は、この計画の呼び名（U1〜U3 と案の番号）と違うので、下に両方を書く。

#### U1 C12 の 3 つの場合の試験の置き場（P9 の計画の判断 1）

- 背景: P9 の計画の C12 の行（854 行）は「`check-docs.test.sh` に、(1) `.dependency-cruiser.cjs` だけを変えた差分、(2) 同じ変更と
  検査の由来の記録の行、(3) 関係の無い変更、の 3 つの場合を足す」と書く。しかし新しいひな形では `check-docs.test.sh` は正本の
  写しで（K の `assets/kinds.tsv` 30 行）、手で足すと本体の検査 13 が「写しの中身が合いません」で失敗し、比べる道具も
  「不一致」を出すので、C11 (2)(3) と両立しない。
- 確かめた事実:
  - K の正本の試験（K の `assets/harness/check-docs.test.sh`）は、本体の検査 12 の場合を 11 件持つ（1011〜1021 行）。そのうち
    1011 行「検査を変えて記録に行を足した」（通る）、1012 行「検査を変えたのに記録に行が無い」（失敗する）、1019 行「検査で
    ないファイルの変更は記録を求めない」（通る）が、C12 の (2)・(1)・(3) と同じ形である。ただし、これらの場合が使う地図は
    969〜977 行の `base_with_log` が作る最小の 2 行（1 列目が「検査」で 2 列目が `scripts/harness/` の行と、記録の行）で、
    変えるファイルは `scripts/harness/new-check.sh`（978・981 行）である。このプロジェクトの本物の地図も、
    `.dependency-cruiser.cjs` も使わない。
  - このプロジェクトの地図（`AGENTS.md` 79 行の「検査（…）」の行）の 2 列目に `.dependency-cruiser.cjs` がある。本体の検査 12 は、
    地図の 1 列目が「検査」か「検査（」で始まる行の 2 列目のバッククォートの中のパスを、検査を定めるファイルとして読む
    （K の `assets/harness/check-docs.sh` 1220〜1228 行・1282 行）。
- 決定: 案 2（P9 の計画の側は案 A）。`scripts/harness/` の直下に、このプロジェクトだけの試験 `harness-log-map.test.sh`
  （写しでないファイル）を置き、`package.json` の `test:harness` につなぐ。試験は、手順の節の「一時のリポジトリの作り方」で
  作った一時のリポジトリで、このプロジェクトの `AGENTS.md` の文書の地図をそのまま使い、変える前の状態の検査が終了コード 0 で
  終わることを確かめてから、3 つの場合を流す。判定は、本体の検査 12 の NG の行の有無と終了コードの両方で行う（V7〜V9）。
  `HARNESS_TODAY` は固定する。`package.json` は検査を定めるファイルなので、由来の記録の行も足す。
- P9 の計画の C12 の文の「`check-docs.test.sh` に足す」は「このプロジェクトだけの試験 `harness-log-map.test.sh` に置く」と
  読み替える（文の書き換えは監督の会話が行う）。

#### U2 `update` の前の、準備の変更のコミット（P9 の計画の判断 3）

- 背景: `harness-copies.sh update` は、作業ツリーに未コミットの変更があると止まる（K の `harness-copies.sh` 329〜331 行）。
  一方、`update` の前に、設定のファイル（`scripts/harness/harness.conf`）と `docs/PLANS.md` の区画の印を置く必要があり
  （同 332〜334 行・355 行）、この計画のファイルも未コミットである。
- 決定: 案 A（P9 の計画の側は判断 3 の指示）。ブランチ `refactor/harness-engine-from-template` に、`scripts/harness/harness.conf`・
  `docs/PLANS.md`・この計画のファイル（`docs/exec-plans/active/2026-10-25-harness-engine-from-template.md`）の 3 つを、作業用の
  コミットにする指示が出た。コミットはまとめ役が行う。push・PR は含まない（全体の実装レビューの後に、あらためて指示を受ける。
  手順 18）。作業用のコミットはこの 1 回だけで、`update` の後の変更は手順 18 までコミットしない（V2・V6 は作業ツリーを写して
  確かめるので、2 回目の作業用のコミットは要らない）。

#### U3 置き換えの後に対応の無い試験の項目が出たときの扱い（P9 の計画の判断 2）

- 背景: C11 (5) は「置き換えの前に合格した試験の項目が、置き換えの後もすべて合格」を求める。置き換えで試験の件数が大きく
  変わる見込みがある（このプロジェクトの `notify.test.sh` は 936 行、K の正本は 292 行。`drift-scan.test.sh` は 598 行と 192 行。
  行数は `wc -l` で数えた）。対応の無い項目は、手順 15 で対応表を作るまで分からない。
- 決定: 案 i（P9 の計画の側は案 A）。置き換えの前の試験の項目を 1 件ずつ、次の 4 つに分け、ファイルと行を添えた対応表にする。
  - (i) このプロジェクトに残る振る舞い（`checks.d/` の検査、`check-arch.sh` など）を確かめていた → このプロジェクトの試験に足す。
  - (ii) K の正本の試験か K の受入試験に同じ働きの項目がある → その項目（K のファイル:行）に対応づける。
  - (iii) K の正本の中身そのもの（本体の注釈と短い名前の一覧の数の照合など）を確かめていた → K で正本の試験に足す作業として
    監督の会話への報告に書き、C11 (5) の上は対応づけ済みと数える。
  - (iv) 消えた実装（`notify-paths.mjs`、`drift-scan.sh` の正規表現の写しの一致など）だけを確かめていた → 理由つきで
    「確かめる対象が無くなった」とする。
  - どれにも当たらない項目が残れば、V5 を不合格にし、持ち越す。
- P9 の計画の C11 (5) の「すべて合格」は「すべて合格か、根拠つきで対応づけた」と読み替える（文の書き換えは監督の会話が行う）。

## 検証（完了の条件）

P9 の計画の識別子との対応: V1〜V6 は C11 の (1)〜(6)、V7〜V9 は C12 の (1)〜(3)、V10 は C20 (8)、V11 は C21。
V2・V6〜V9 の「一時のリポジトリ」は、手順の節の「一時のリポジトリの作り方」で作ったものを指す。

### V1 すべての検査が通る（C11 (1)）

- 前提: 手順 3〜13 を終えている。依存は `npm ci` で入れてある。`git fetch --prune origin` の後である（本体の検査 12 が
  `origin/main` との分岐元を使うため）。
- 操作: worktree の根で `npm run check` を実行する。
- 期待する結果: 終了コード 0。`check-docs.sh` の出力が「check-docs: OK」で、`check-docs.sh --print checks` が本体の 13 個の後に
  追加の検査の 3 つの名前を出す。`test:harness` の各試験（写しの 4 本、部品の `stack-adapter.test.sh`、このプロジェクトだけの
  試験）がすべて期待どおりと出す。
- 確かめ方: 自動テスト

### V2 写しを 1 行変えると検査が失敗する（C11 (2)）

- 前提: 手順 14 を終えている。作業ツリーの今の中身を写した一時のリポジトリで、コミットの前に `scripts/harness/notify.sh` の本体
  （冒頭の `harness-copy:` の行より後）の 1 行を変えてある（コミットと `origin/main` の付け替えは、変えた後に行う。本体の検査 12 の
  失敗を混ぜないため）。
- 操作: 一時のリポジトリの根で `bash scripts/harness/check-docs.sh` を実行する。
- 期待する結果: 終了コード 1。出力に「写し scripts/harness/notify.sh の中身が合いません」がある。
- 確かめ方: 自動テスト

### V3 比べる道具が、写しの本体が正本と同じと出す（C11 (3)）

- 前提: 手順 14 を終えている。K の手元に版の印 `rules-2026.10.25-1` がある。
- 操作: `HARNESS_COPIES_CMP_TAG=rules-2026.10.25-1 bash ~/.agent-rules/home/agents/skills/project-harness-init/scripts/harness-copies.sh
  verify <この worktree の根>`（比べの相手の版を固定し、K に新しい版の印が付いても「更新あり」に変わらないようにする。
  K の `harness-copies.sh` 187〜191 行）。
- 期待する結果: 終了コード 0。写し（中心の 7 つ、部品の 4 つ）と区画 2 つのすべての行の分類が「一致」。
- 確かめ方: 自動テスト

### V4 PR の CI が成功する（C11 (4)）

- 前提: 手順 18 で PR を作ってある。
- 操作: PR の `harness` と `drift-scan` の実行の結果を `gh pr checks <番号> --repo <所有者>/ai-news-today` で見る。
- 期待する結果: すべて成功。実行の番号を進捗に書く。
- 確かめ方: 人が確認

### V5 置き換えの前に合格した試験の項目が、置き換えの後もすべて合格（C11 (5)）

- 前提: 手順 2 の基準の記録と、手順 14 の `npm run check` の出力がある。
- 操作: 手順 15 の方法で、置き換えの前の試験の項目ごとに、置き換えの後の対応する項目を表にする。
- 期待する結果: 前の項目のすべてに、合格した後の項目か、決まった点の U3 の (i)〜(iv) の分類と根拠（ファイルと行）がある。どれにも当たらない項目は 0 件。vitest の件数（144 件）、
  `lint-rules.test.mjs`（15 件）、`check-arch.test.sh`（9 件）は、置き換えの前と同じ件数で合格する（このプロジェクトの
  ファイルで、置き換えない）。
- 確かめ方: 人が確認

### V6 本体と冒頭のハッシュを一緒に変えた写しは、検査を通るが比べる道具で失敗する（C11 (6)）

- 前提: V2 とは別に作った一時のリポジトリで、コミットの前に `scripts/harness/notify.sh` の本体の 1 行を変え、冒頭の
  `harness-copy: sha256=` の値を、冒頭の行を除いた中身の sha256 に書き換えてある（コミットと `origin/main` の付け替えは、変えた
  後に行う）。
- 操作: 一時のリポジトリの根で `bash scripts/harness/check-docs.sh` を流し、比べる道具の `verify` を一時のリポジトリの根に対して
  流す（比べの相手の版は固定しない。「不一致」は冒頭に記録された版の正本との照合で決まるため）。
- 期待する結果: 文書の検査は終了コード 0。比べる道具は `notify.sh` を「不一致」とし、終了コード 1。
- 確かめ方: 自動テスト

### V7 `.dependency-cruiser.cjs` だけを変えた差分は失敗する（C12 (1)）

- 前提: 決まった点の U1 のとおり、このプロジェクトだけの試験 `scripts/harness/harness-log-map.test.sh` がある。試験は一時のリポジトリを作り、
  変える前の状態で `scripts/harness/check-docs.sh` が終了コード 0 で終わり、本体の検査 12 の NG の行が無いことを確かめてから、
  各場合を流す（変える前に通らなければ、場合を流さずに試験を失敗にする）。
- 操作: 一時のリポジトリで `.dependency-cruiser.cjs` の 1 行（コメントの行でよい）を変え、写した先の `scripts/harness/check-docs.sh`
  を流す。
- 期待する結果: 終了コード 1、かつ出力に「検査を定めるファイル（.dependency-cruiser.cjs）を変えたのに、検査の由来の記録
  docs/harness-log.md に行が足されていません」の NG の行がある。
- 確かめ方: 自動テスト

### V8 同じ変更に由来の記録の行を足すと通る（C12 (2)）

- 前提: V7 と同じ。
- 操作: V7 と同じ変更に加え、`docs/harness-log.md` の記録の表に 1 行を足して流す。
- 期待する結果: 終了コード 0、かつ出力に本体の検査 12 の NG の行（「検査の由来の記録」を含む NG の行）が無い。
- 確かめ方: 自動テスト

### V9 関係の無い変更は記録を求めない（C12 (3)）

- 前提: V7 と同じ。
- 操作: 地図の検査の行に無いファイル（例: `src/` の下のファイルのコメントの行）だけを変えて流す。
- 期待する結果: 終了コード 0、かつ出力に本体の検査 12 の NG の行が無い。
- 確かめ方: 自動テスト

### V10 実装レビューを通る（C20 (8)）

- 前提: 手順 3〜16 の差分（作業用のコミットと未コミットの変更）がそろっている。
- 操作: まとめ役が実装レビュー（1 段目と、規模に応じた第二レビュー）を行い、指摘を直す。手順 4 の準備の変更のレビューとは別に、
  全体の差分を対象にする。
- 期待する結果: 統合した結論に重大な指摘が残らない。
- 確かめ方: 人が確認

### V11 コミットごとに個人情報と秘匿値が無い（C21）

- 前提: 各コミットの直前。
- 操作: `npm run check:secrets`、push の前に `git fetch --prune origin` の後で `npm run check:secrets:push`。コミットの中身・
  メッセージ・PR の題と本文に、アカウント名・姓名・メールアドレス・ホームと一時ディレクトリの絶対パスが無いことを検索する。
  コミットの後に作者を確かめる。
- 期待する結果: どれも 0 件で、終了コード 0。作者が指定どおり（noreply の形）。記録は P9 の計画の証拠の置き場
  （`~/.claude/harness-rollout/p9-evidence/c21/`）に置く。
- 確かめ方: 人が確認

## 手順

各手順の「設計」の箇条は、その手順で何をどう変えるかの決定である（決めた理由は判断の記録）。

**一時のリポジトリの作り方（V2・V6・V7〜V9 で共通。手順 12 の試験と手順 16 で同じ形を使う）**:

- (a) リポジトリの外に `mktemp -d` で置き場を作り、終わりに消す（`trap` で消す）。
- (b) 写す一覧は、作業ツリーの根で `git -c core.fsmonitor=false ls-files -z --cached --others --exclude-standard` の NUL 区切りの
  一覧から、作業ツリーで削除済みの項目（`git ls-files -z --deleted` に出るもの。手順 11 で消す `notify-paths.mjs` など）を除いた
  ものとする。`docs/exec-plans/active/` の下の計画と記録（`.md`）も除き、置き場の `docs/exec-plans/active/` は空のディレクトリとして
  作る（本体の検査 8・9・11 の結果を、写した日の進行中の計画に左右させないため。`active/` は必須のディレクトリなので作る）。
- (c) 残りの各パスを、作業ツリーの今の中身のまま写す（ディレクトリを作り、ファイルは `cp -p`、シンボリックリンクはリンクのまま）。
  読み取りや写しに失敗したパスがあれば、そのパスを示して終了コード 2 で止める（失敗を一律に無視しない）。
- (d) 場合ごとの変更（V2・V6 の写しの変更）は、ここで加える。
- (e) 置き場で `git init -q` し、K の `assets/harness/check-docs.test.sh` 962〜965 行と同じ付け方（`-c user.name=test -c user.email=test
  -c commit.gpgsign=false -c core.hooksPath=/dev/null -c core.fsmonitor=false`）で、`add -A` と `commit -q` を行い、
  `update-ref refs/remotes/origin/main HEAD` で分岐元をそのコミットにする（CI に git の作者の設定が無くてもコミットできるように
  するため）。
- (f) 検査は、環境変数 `GITHUB_BASE_REF`・`HARNESS_BASE_REF` を外し（CI の pull request では `GITHUB_BASE_REF` が入っているため）、
  `HARNESS_TODAY=2026-10-25` に固定して流す。
- (g) V7〜V9 の場合の変更は、(e) の後に作業ツリーとして加える（本体の検査 12 は、分岐元からの作業ツリーの差分を見る）。

1. **この計画を書き、設計レビューと利用者の確認を得る。** U1〜U3 の利用者の答えを判断の記録に書き、下書きの指示の文を
   決めた内容に置き換える（2026-10-25 に反映した）。

2. **置き換えの前の基準を記録する。** まとめ役の置き換えの前の `npm run check` の出力から、試験のスクリプトごとに
   `ok: ` で始まる行（項目の名前）を取り出し、P9 の計画の証拠の置き場（`~/.claude/harness-rollout/p9-evidence/c11/`）に
   スクリプトごとのファイルで保存する（vitest は件数だけ）。あわせて `npm run scan:drift -- --out <リポジトリの外の空の置き場>`
   の結果を保存する（置き換えの後と比べるため）。

3. **準備の変更（`update` が前提にするもの）を置く。**
   - 設定のファイル `scripts/harness/harness.conf` を、K の `assets/harness-conf.txt` の形で新しく作る（設定のファイルは
     プロジェクトが正本で、手で書いてよい。K の `assets/harness-conf.txt` 4 行）。中身は次のとおり（注釈の行は K のひな形の
     注釈を写す）。`required.1` は、今の `check-docs.sh` の `required_for_version` の版 1 の一覧（157〜187 行の関数）と同じ 20 行で、
     版の数（`AGENTS.md` の「ハーネスの版: 1」）は変えない。`claude_md_exact=yes` は、今の検査 2（`CLAUDE.md` が 1 行と
     完全に一致）と同じ振る舞いを保つため。`template_version` は書かない（`update` が書く）。
     ```
     format=1
     agents_max_lines=120
     required.1=AGENTS.md
     required.1=CLAUDE.md
     required.1=ARCHITECTURE.md
     required.1=.gitignore
     required.1=docs/adr/README.md
     required.1=docs/PLANS.md
     required.1=docs/exec-plans/active/
     required.1=docs/exec-plans/completed/
     required.1=docs/QUALITY_SCORE.md
     required.1=docs/quality-eval/README.md
     required.1=docs/quality-eval/tasks/
     required.1=docs/quality-eval/results/
     required.1=scripts/harness/check-docs.sh
     required.1=scripts/harness/check-arch.sh
     required.1=scripts/harness/check-secrets.sh
     required.1=scripts/harness/check-secrets.mjs
     required.1=.dependency-cruiser.cjs
     required.1=.secretlintrc.json
     required.1=.github/workflows/harness.yml
     required.1=.github/dependabot.yml
     claude_md_exact=yes
     arch_path_prefixes=src docs scripts .github templates
     arch_root_file_exts=md cjs mjs ts json yml
     default_branch=main
     part=node-harness
     part=node-secrets
     record_exempt_line_re=^\s*-?\s*uses:[ \t]*(?<name>[^@\s]+)@(?<ver>[0-9a-f]{40}(\s+#.*)?)$
     record_exempt_line_re=^\s*"(?<name>[@A-Za-z0-9._/-]+)":\s*"(?<ver>[~^]?[0-9][0-9A-Za-z.+-]*)",?\s*$
     ```
     1 行目の `record_exempt_line_re` は K の `assets/harness-conf.txt` の最後の規則（CI のアクションを 40 桁のコミットで固定した
     行の版の置き換え）、2 行目は部品 `node-harness` の断片（K の `assets/parts/node-harness/fragments/harness-conf-lines.txt`。
     `package.json` の依存の版だけの置き換え）である。
   - `docs/PLANS.md` を直す。
     - 「必須の節」の 5（進捗）を、K の `assets/plans.md` 69〜108 行の形に合わせ、空の区画の印の行の組
       （`plan-status-spec` の begin と end。中身は `update` が正本で埋める）を置く。
     - 「必須の節」の後に、節「## 費用の節と見張り点」を K の `assets/plans.md` 115〜118 行と 140〜141 行の文で足し、その間に
       空の区画の印の行の組（`plan-cost-spec`）を置く。
     - 「置き場所と名前」の古い計画の箇条（26〜36 行。36 行の「日数は `scripts/harness/check-docs.sh` の `STALE_PLAN_DAYS` に持つ」
       を含む）を、K の `assets/plans.md` 26〜30 行の形に直し、本体の検査 11 が読む「古い計画の日数: 30」の 1 行を置く（無いと
       本体の検査 11 が失敗する。K の `assets/harness/check-docs.sh` 1186〜1193 行）。古い説明の文を残さない。
     - `scripts/harness/check-docs.sh` を直すよう書いた 2 か所（57 行・92 行）を、「規約の正本を直して `update` で置き換える」
       旨に直す（写しは手で直さないため）。

4. **準備の変更の実装レビューを受ける。** まとめ役に、手順 3 で変えたもの（`scripts/harness/harness.conf`・`docs/PLANS.md`）と
   この計画を対象にした実装レビュー（`impl-reviewer` の 1 段）を頼む。指摘を直してから手順 5 へ進む。

5. **準備の変更をコミットする（決まった点の U2）。** 手順 4 の後に、利用者のコミットの指示（2026-10-25 に出た）に従い、まとめ役が
   `scripts/harness/harness.conf`・`docs/PLANS.md`・この計画を名前で指定して作業用のコミットにする（push はしない）。コミットの直前に V11 の
   検索を行う。

6. **`update` の計画を出して照らす。** `bash ~/.agent-rules/home/agents/skills/project-harness-init/scripts/harness-copies.sh update
   <この worktree の根> --to rules-2026.10.25-1 --adopt scripts/harness/check-docs.sh --adopt scripts/harness/check-docs.test.sh
   --adopt scripts/harness/notify.sh --adopt scripts/harness/notify.test.sh --adopt scripts/harness/drift-scan.sh
   --adopt scripts/harness/drift-scan.test.sh --adopt scripts/harness/check-secrets.sh --adopt scripts/harness/check-secrets.mjs
   --adopt docs/PLANS.md#plan-status-spec --adopt docs/PLANS.md#plan-cost-spec`（`--apply` なし。何も書かない）。
   - 流す前に、`git -C ~/.agent-rules tag -l 'rules-*'` の最新が `rules-2026.10.25-1` であることを確かめる（新しい印があると
     基準の版と由来の記録の向きが変わる。違えば止めてまとめ役に知らせる）。
   - 期待する計画: 「置き換える」が 8 つ（上の 8 つのファイル）、「作る」が 3 つ（`scripts/harness/checks.d/README.md`・
     `scripts/harness/stack-adapter.sh`・`scripts/harness/stack-adapter.test.sh`）、「区画を置き換える」が 2 つ、「設定の版を
     書き換える」が 1 つ。「知らせる」の行は、前提の節のとおり出ない見込み（描いた物は手順 9 で手で比べる）。
   - 「止める」が出たら、その理由に従って準備を直す（直したら手順 4・5 と同じくレビューとコミットの指示を得る）。期待と違う
     行があれば、進まずに判断の記録に書き、まとめ役に返す。

7. **`update` の計画を利用者に示し、承認を得る（関門）。** まとめ役が、手順 6 の出力（`--adopt` で引き取る 10 個の名前と、
   置き換える・作る・区画を置き換える・設定を書き換える一覧）と、次に `--apply` で書くことを利用者に示し、承認を得る
   （K の `SKILL.md` の「導入済みのプロジェクトの更新」の 2・3。手で変えた写しを捨てて引き取るのは利用者が答えたものだけ）。
   承認が無ければ手順 8 へ進まない。

8. **`update` で置き換える。** 手順 6 と同じ引数に `--apply` を足して流す。道具は、写しと区画の置き換え、`template_version` の
   追加、`docs/harness-log.md` への「規約の版の更新」の 1 行の追加を行い、`verify`・文書の検査・その試験・早期通知と定期の
   走査の試験・部品の試験を流す。出力を P9 の証拠の置き場に保存する。終了コード 1 のときは、変更は残るので、出力の NG を
   この計画の手順 10〜13 で解けるものか（T の検査 12〜14 が無いことによるものなど）を見分けて、発見の欄に書く。文書の検査が
   通らないと道具は後の試験を流さない（K の `harness-copies.sh` 488〜508 行）ので、試験の結果は手順 14 で確かめる。

9. **描いた物を、版の印のひな形と手で比べる。** 前提の節のとおり `update` は描いた物の差を知らせないので、次の組を
   `git -C ~/.agent-rules show rules-2026.10.25-1:home/agents/skills/project-harness-init/assets/<ひな形>` の出力と
   このプロジェクトのファイルで比べる: `agents.md` と `AGENTS.md`、`codex-hooks.json` と `.codex/hooks.json`、
   `claude-settings.json` と `.claude/settings.json`、`parts/node-harness/assets/drift-scan.yml` と `.github/workflows/drift-scan.yml`、
   `ci-harness.yml` と `parts/node-secrets/assets/ci-secrets.yml` と `.github/workflows/harness.yml`、
   `parts/node-secrets/assets/secretlintrc.json` と `.secretlintrc.json`。差ごとに、取り込むか（取り込むなら手順 11・13 のどこで）と
   理由を判断の記録に書く。取り込むと決めた差は、この計画の手順 11・13 の箇条に足してから進む。
   `claude-settings.json` と `.claude/settings.json` の組の、早期通知の `command` の引用符の位置の差は、取り込むと決めてある
   （手順 11。理由は判断の記録の「`.claude/settings.json` の書き方」の行）。

10. **T の検査 12〜14 を追加の検査の口へ移す。** 今の `check-docs.sh`（置き換えの前のもの。`git show ac4555f:scripts/harness/check-docs.sh`
    で読む）の次の部分を、それぞれ 1 つのファイルにする。各ファイルは K の `checks.d/README.md` の決まり（2 行目以降に
    `# 検査の名前: <名前>` を 1 行、終了コード 0/1、`check-docs: NG: ` と `  直し方: ` の組）に従い、検査する根のファイルを文書として
    読むだけにする。試験は、置き換えの前の `check-docs.test.sh` の該当の場合を、同じ名前の `<名前>.test.sh` へ移す。
    各試験は自分で一時のリポジトリを作る（本体の試験の補助の関数は使えないので、要る分を試験の中に書く）。

    | 今の検査 | 今の行 | 行き先 | 検査の名前 | 移す試験の場合の数（置き換えの前の数） |
    |---|---|---|---|---|
    | T の検査 12 文書の検査の一覧 | 冒頭の説明 56〜62 行、本体 1021〜1121 行 | `scripts/harness/checks.d/check-list.sh` | 文書の検査の一覧 | 10（11） |
    | T の検査 13 通信の名前の一覧 | 冒頭の説明 63〜75 行、本体 1123〜1279 行 | `scripts/harness/checks.d/network-names.sh` | 通信の名前の一覧 | 12（12） |
    | T の検査 14 層の評価の上限 | 冒頭の説明 76〜87 行、本体 1281〜1402 行 | `scripts/harness/checks.d/layer-ratings.sh` | 層の評価の上限 | 36（36） |

    設計:
    - `check-list.sh` は、今の検査 12 の前半（`AGENTS.md` の検査のコマンドの表の文書の行と、`docs/QUALITY_SCORE.md` の目標の表の
      「文書の検査の不整合（…）」の 2 つの括弧書きを、名前の一覧と比べる部分）だけを移す。名前の一覧は、今の `CHECK_NAMES` では
      なく `bash "$HARNESS_ENGINE_DIR/check-docs.sh" --print checks` の出力（本体の 13 個と、追加の検査の名前を名前の順に）から読む。
      追加の検査は名前の順に流れるので、括弧書きの順は「…、古い計画、検査の由来の記録、写しの中身、文書の検査の一覧、
      層の評価の上限、通信の名前の一覧」になる（`check-list.sh` < `layer-ratings.sh` < `network-names.sh`）。
    - 今の検査 12 の後半（冒頭の「確かめること」の番号が 1 から欠けずに並び、数が `CHECK_NAMES` と同じ）とその試験
      （「CHECK_NAMES の数が冒頭の一覧の検査の数と違う」の 1 件）は移さない。後半は K の写しの注釈の形（公開した口でないもの）に
      依って K の中身を確かめるもので、このプロジェクトでは写しを直せないため。手順 15 の対応表で決まった点の U3 の (iii) に
      分類し、K で正本の試験に足す作業として監督の会話への報告に書く（C11 (5) の上は対応づけ済みと数える）。
    - `network-names.sh` は、今の検査 13 をそのまま移す（`ARCHITECTURE.md` と `eslint.config.mjs` を文字列として読む）。
    - `layer-ratings.sh` は、今の検査 14 をそのまま移す。表 1 の見出しの行（今の 1286 行 `LAYER_T1_HEADER`）は、今は
      `drift-scan.sh` の `T1_HEADER` の写しと書いてあるが、K の `drift-scan.sh` には `T1_HEADER` が無い（K の
      `assets/harness/drift-scan.sh` を `grep -n T1_HEADER` して 0 件）。このファイルの定数として持ち、注釈を「`docs/QUALITY_SCORE.md`
      の表 1 の見出しの行と同じ文字列」に直す。
    - 置き換えの前の試験の場合で、ほかに本体の試験に無いもの（「設計の正本: 書いた templates/ のパスが実在する」「〜が無い」の
      2 件。置き換えの前の `check-docs.test.sh` 931〜942 行）は、手順 15 の対応表で扱う。
    - `checks.d/` は検査を定めるファイルの置き場の下なので、`docs/harness-log.md` に 3 つの検査を移した行を足す（手順 13）。

11. **早期通知の付け替え。**
    - `scripts/harness/notify-paths.mjs` を消す（K の `notify.sh` は入力の変換を perl で行い、このファイルを使わない。K の
      `assets/harness/notify.sh` 22 行）。
    - `.codex/hooks.json` を、K の `assets/codex-hooks.json` と同じ確かめ（`notify-paths.mjs` の有無を確かめる箇所を外し、
      `scripts/harness/` に除外されていない未追跡のファイルが無いことの確かめを足す）に直す。`command` は K のひな形の値を
      そのまま使う（手順 9 で見つけた、最初の `git worktree list` に `-c core.fsmonitor=false` を付ける差も含む）。直さないと、マージの後に
      Codex の早期通知が「起動の前の確かめが成り立ちません」で常に動かなくなる（今の `.codex/hooks.json` が
      `HEAD:scripts/harness/notify-paths.mjs` の存在を確かめるため）。
    - `.claude/settings.json` の早期通知の `command`（今の 15 行 `"/bin/bash \"$CLAUDE_PROJECT_DIR\"/scripts/harness/notify.sh claude"`）を、
      K のひな形 `assets/claude-settings.json` 9 行と同じ書き方 `"/bin/bash \"$CLAUDE_PROJECT_DIR/scripts/harness/notify.sh\" claude"` に
      直す（引用符を、パスの全体を囲む位置へ移す）。K の写しの `notify.test.sh` 279 行の項目「11: .claude/settings.json が notify.sh
      claude を呼ぶ」は、`grep -qF 'scripts/harness/notify.sh\" claude'` でこの書き方を探すので、直さないと置き換えの後にこの項目が
      失敗し、`npm run test:harness` と CI の `harness` が止まる。`permissions` の行はこのプロジェクトのものを残す。
    - `docs/adr/0005-early-notify-hooks.md` の本文は変えない。`docs/adr/README.md` の目録の 0005 の状態を「採用（実行するプログラムの
      範囲は 0007 で置換）」にし、0005 の「結果と限界」の節の末尾に、実行するプログラムの範囲は 0007 で置き換えたことを示す
      注記を 1 行足す（0001 と 0002 の前例と同じ扱い）。

12. **C12 の試験を書く（決まった点の U1）。** `scripts/harness/harness-log-map.test.sh` を新しく作る。
    試験は「一時のリポジトリの作り方」の (a)〜(c)・(e)・(f) で一時のリポジトリを作り、変える前の状態で検査が終了コード 0 で
    終わり、本体の検査 12 の NG の行が無いことを確かめる（通らなければ、場合を流さずに失敗にする）。続けて、場合ごとに
    一時のリポジトリを作り直して（または `git -C <置き場> checkout -- .` と `git clean` で戻して）、V7〜V9 の操作を (g) の形で加え、
    終了コードと NG の行の有無の両方で判定する。

13. **つなぎと文書を直す。**
    - `package.json` の `test:harness`: `bash scripts/harness/check-docs.test.sh && bash scripts/harness/notify.test.sh &&
      node scripts/harness/lint-rules.test.mjs && bash scripts/harness/check-arch.test.sh && bash scripts/harness/drift-scan.test.sh &&
      bash scripts/harness/stack-adapter.test.sh`（最後に `&& bash scripts/harness/harness-log-map.test.sh`）。`check` は
      変えない（`stack-adapter.sh` が `npm run <名前>` を `&&` でつないだ形を読むため。K の `assets/parts/node-harness/PART.md`）。
    - `.github/workflows/harness.yml`: 段の順（秘匿値の検査の 2 段を、ほかのスクリプトより先）と `permissions: contents: read` は
      変えない。変えるのは `test-harness` の段の名前の括弧書き（段の読み取りの試験と、由来の記録の試験を足す）と、
      手順 9 で取り込むと決めた差だけ。K の `assets/ci-harness.yml` と部品の `ci-secrets.yml` のファイルは置かない（棚卸しの表の
      CI の行）。手順 9 で取り込むと決めた差: 取得の段の `fetch-depth: 0` の注釈に、本体の検査 12 が分岐元との merge-base を
      求めるためでもあることを足す（K の `ci-harness.yml` の同じ箇所の注釈。値は今も 0 なので変えない）。
    - `.secretlintrc.json`: 手順 9 で取り込むと決めた差。`Anthropic OAuth token` の規則の `pattern` を、K の部品のひな形
      `parts/node-secrets/assets/secretlintrc.json` と同じ `(?:sk-ant-oat)` で囲んだ形にする（意味は変わらない）。
    - `.github/workflows/drift-scan.yml`: pull request の `paths` の `scripts/harness/drift-scan.sh` と `drift-scan.test.sh` の 2 行を
      `scripts/harness/**` にする（K の `drift-scan.sh` は `stack-adapter.sh`・`check-docs.sh --print arch-path-re`・
      `check-secrets.sh --file`・設定のファイルを使うので、それらの変更でも走査を試すため。K の部品のひな形 `drift-scan.yml` と
      同じ）。ほかの行は、手順 9 で取り込むと決めた差のほかは変えない。
    - `AGENTS.md`（120 行の上限。今 115 行）:
      - 導入済みの印の説明（5〜8 行。8 行目の「同じ変更で `check-docs.sh` の版ごとの一覧を足す」を含む）を、必須のファイルの
        一覧が `scripts/harness/harness.conf` の `required.<版>` にあり、`scripts/harness/` の検査の本体は規約の正本の写しで手で
        変えず、このプロジェクトだけの検査は `scripts/harness/checks.d/` に置く、という内容に直す（K の `assets/agents.md` 9〜10 行の
        文を使う）。古い説明の文を残さない。
      - 検査のコマンドの表の文書の行（54 行）の括弧書きを、手順 10 の順の 16 個の名前に直す。検査の試験の行（55 行）の括弧書きに、
        段の読み取り（定期の走査の部品）と、検査の由来の記録の試験を足す。
      - 文書の地図の「定期の走査」の行（82 行）の 1 列目を「検査（定期の走査）」にし、3 列目に段の読み取りが
        `scripts/harness/stack-adapter.sh` であることを足す（K の部品の断片 `agents-map-rows.md` の形。`drift-scan.yml` が検査を
        定めるファイルになり、本体の検査 12 の対象になる）。
    - `ARCHITECTURE.md` 63 行: 「`scripts/harness/check-docs.sh` の検査 13」を「`scripts/harness/checks.d/network-names.sh`」に直す。
    - `eslint.config.mjs` 11 行・13 行のコメント: 同じく「`scripts/harness/checks.d/network-names.sh`」に直す（コメントだけ）。
    - `docs/QUALITY_SCORE.md`: 10 行・12 行・63 行の「検査 14」を「`scripts/harness/checks.d/layer-ratings.sh`」に、21 行の
      「文書の検査の不整合（…）」の括弧書きを `AGENTS.md` と同じ 16 個の名前に直す（`check-list.sh` が両方を照らす）。
      10 行の「走査」の側の記述（`drift-scan.sh` の表 1 の読み取り）が K の `drift-scan.sh` と合うかを確かめ、合わなければ直す。
    - `docs/PLANS.md` の「受け入れ確認の記録」の「置き場と名前」の失敗の条件（「基準ごとの最新の結果が『合格』でない」）に、
      K の `assets/plans.md` の括弧書き（進捗の状態の表で、その基準を `不合格`〔根拠に `持ち越し: <持ち越し先>`〕として閉じた
      ものを除く。持ち越しの無い `不合格` の行は失敗にする）を足す。K の `assets/harness/check-docs.sh` 792〜797 行の振る舞いに
      文書を合わせるため。
    - `docs/exec-plans/tech-debt-tracker.md` の TD-6（32 行。今の `notify.test.sh` 665〜682 行の試験 15 がまれに失敗する）と TD-7
      （33 行。今の `drift-scan.sh` 476〜513 行の表 2 の読み取りと、今の検査 14 を指す）を見直す。置き換えの後も問題が残るかを、
      K の写しで評価する（TD-6 の試験 15 は、K の `assets/harness/notify.test.sh` に `前後で変わらない`・`snapshot`・`ls -la` を
      `grep` して 0 件で、写しには無い見込み。TD-7 は K の `drift-scan.sh` の表を読む部分と `layer-ratings.sh` で評価する）。
      問題が残らない行は一覧の決まり（解消した変更で行を消す）のとおり消し、残る行は場所の参照だけを直す。どうしたかと根拠を
      判断の記録に書く。
    - `docs/harness-log.md` の記録の表に、次の行を足す（`update` が足した 1 行に加えて）: T の検査 12〜14 を追加の検査の口へ移した
      行（3 つの検査ごとに 1 行。元の行の「外した変更」の列に、この変更で本体から外したことを書く）、早期通知の付け替え
      （`notify-paths.mjs` を消した）の行、由来の記録の試験を足した行。
    - ADR 0005 の「結果と限界」の末尾の注記（手順 11 で足した）の「0007」を、`0007-harness-engine-copies.md` へのリンクにする。
    - 新しい ADR `docs/adr/0007-harness-engine-copies.md` を書き、`docs/adr/README.md` の目録に足す。内容:
      - 検査の本体を K の正本の写しにしたこと、設定と追加の検査の口の分け方、写しを手で変えないこと、更新は K の
        `harness-copies.sh update` で行うこと、`claude_md_exact=yes` を保つこと。
      - 早期通知が実行するプログラムの範囲（`notify.sh`・`check-docs.sh` と、起動元の `checks.d/` の検査。`notify-paths.mjs` を
        消した）。0005 のこの部分を置き換える。
      - CI を 1 本の `harness.yml` のまま保つこと。`harness.yml` が K の `ci-harness.yml`（敷いたときの置き先は
        `.github/workflows/harness-docs.yml`）と部品の `ci-secrets.yml`（同 `.github/workflows/harness-secrets.yml`）に当たること。
        置き先にファイルが無いので `update` はひな形の差を知らせない。そのため、更新のたびに
        `git -C ~/.agent-rules diff <前の版の印> <新しい版の印> -- home/agents/skills/project-harness-init/assets/ci-harness.yml
        home/agents/skills/project-harness-init/assets/parts/node-secrets/assets/ci-secrets.yml` で 2 つのひな形の差を見て、取り込むかを
        決める手順。
      - 更新で新しく作られた写しの試験（`*.test.sh`）は `test:harness` に自動ではつながらないので、更新のたびに、`update` の出力の
        「作る」の行に試験があれば `package.json` の `test:harness` に足す手順。
      - K が本体の検査を足して `--print checks` の名前が増えたら、`AGENTS.md` と `docs/QUALITY_SCORE.md` の 2 つの括弧書きを同じ
        変更で直すこと（`check-list.sh` が失敗して知らせる）。追加の検査は `LC_ALL=C` のファイル名の順に並ぶこと。
      - 秘匿値の検査の写し（`check-secrets.sh`・`check-secrets.mjs`）には、道具の選び方と限界の理由（ADR 0002）を指す注釈が
        無くなったので、その理由は ADR 0002 にあること。

14. **全体の検査を流す（V1）。** `git fetch --prune origin` の後に `npm run check` を流し、出力を P9 の証拠の置き場に保存する。
    `update` の確かめは文書の検査が通らないと試験を流さないので、すべての試験の結果はこの出力で確かめる。あわせて
    `npm run scan:drift -- --out <リポジトリの外の空の置き場>` を流し、手順 2 の結果と比べる（走査の段の名前と、品質目標の表の
    読み取りが変わっていないこと）。早期通知の所要時間を 1 回測る（作業ツリーの中の `.md` のファイルを書いたことを表す
    フックの入力を `notify.sh claude` に渡し、`time` で測る。K の `notify.sh` の全体の上限 18 秒〔53 行 `TIME_LIMIT=18`〕より短い
    ことを確かめ、秒数を進捗に書く）。

15. **置き換えの前後の試験の対応表を作る（V5）。** 手順 2 と手順 14 の `ok: ` の行を、スクリプトごとに名前で突き合わせる
    （`comm` で同じ名前と、前にだけある名前と、後にだけある名前に分ける）。前にだけある項目ごとに、表の行
    「前の項目 | 前のスクリプト | 後の項目（スクリプトと名前） | 分類 | 根拠」を作る。分類は、同じ名前で合格した項目のほかは、決まった点の U3 の (i)〜(iv) の
    どれか（(i) このプロジェクトの試験に足した、(ii) K の正本の試験か K の受入試験の項目に対応づけた、(iii) K の正本の中身を確かめて
    いたので、K で正本の試験に足す作業として監督の会話への報告に書いた、(iv) 確かめる対象が無くなった）。(iii) には、手順 10 で
    移さなかった「CHECK_NAMES の数が冒頭の一覧の検査の数と違う」を入れる。どれにも当たらない項目が残れば V5 を不合格にし、
    持ち越す。表は P9 の証拠の置き場
    （`~/.claude/harness-rollout/p9-evidence/c11/`）に置き、件数を進捗に書く。

16. **写しの守りと由来の記録の検査を確かめる（V2・V3・V6・V7〜V9）。** V3 はこの worktree で比べる道具を流す。V2 と V6 は、
    「一時のリポジトリの作り方」で、それぞれ別の一時のリポジトリを作って行う（作業ツリーの今の中身を写すので、未コミットの
    変更を含めて確かめられる）。V7〜V9 は手順 12 の試験の出力で確かめる。

17. **実装レビューを受ける（V10）。** まとめ役に差分の範囲（作業用のコミットと未コミットの変更）と、この計画のパスを渡す。
    指摘を直したら、手順 14〜16 のうち影響を受けるものを流し直す。

18. **コミット・push・PR（利用者の指示の後）。** 指示を得てから、自分が変えたファイルを名前で指定してコミットし（V11 の検索を
    コミットの直前に行う）、push の前に `git fetch --prune origin` と `npm run check:secrets:push` を通し、PR を作る。PR の題は英語の
    Conventional Commits の形（例: `refactor: replace harness engine with template copies`）。

19. **CI と競合を確かめる（V4）。** PR の CI がすべて成功すること、`main` と競合していないこと（`gh pr view <番号> --json
    mergeable,mergeStateStatus`）を確かめ、実行の番号を進捗に書く。

20. **計画を閉じる（マージの前）。** 状態の表がすべて済・対象外・不合格になったことを照合の道具
    （`~/.agents/skills/exec-plan/scripts/plan-status.sh --require-done` と `--report`）で確かめ、結果と振り返りを書き、この計画を
    `docs/exec-plans/completed/` へ移す。閉じる変更をコミットする前に V11 の検索を行い、利用者の指示を得てコミット・push し、
    閉じた後の CI も成功することを確かめる。閉じ忘れると、進行中の計画の古さの検査（本体の検査 11。30 日）で CI が止まる。

## 進捗

### 状態の表

| 項目 | 状態 | 根拠 |
|---|---|---|
| V1 | 済 | 2026-10-26。`@87beb0d`、未コミットの変更を含めて確かめた。`git fetch --prune origin` の後の `npm run check` が終了コード 0。`check-docs: OK`、`--print checks` は本体の 13 個の後に追加の検査 3 つ、`test:harness` の 9 本がすべて期待どおり。出力は `~/.claude/harness-rollout/p9-evidence/c11/t-engine-after-npm-run-check.log` |
| V2 | 済 | 2026-10-26。`@87beb0d`、未コミットの変更を含めて確かめた（一時のリポジトリに写した）。`check-docs.sh` が終了コード 1 で「写し scripts/harness/notify.sh の中身が合いません」。出力は `~/.claude/harness-rollout/p9-evidence/c11/t-engine-v2-v6.txt` |
| V3 | 済 | 2026-10-26。`@87beb0d`、未コミットの変更を含めて確かめた。`HARNESS_COPIES_CMP_TAG=rules-2026.10.25-1` の `verify` が終了コード 0 で、写し 11 個と区画 2 つの 13 行すべてが「一致」。出力は `~/.claude/harness-rollout/p9-evidence/c11/t-engine-v3-verify.txt` |
| V4 | 未 | |
| V5 | 済 | 2026-10-26。利用者が対応表 `~/.claude/harness-rollout/p9-evidence/c11/t-engine-c11-5-map.md` を確かめ、「この分け方でよい」と答えた（2026-10-25、会話 910f67f4 の発言番号 13）。前の 433 件のうち、どれにも当たらない項目は 0 件 |
| V6 | 済 | 2026-10-26。`@87beb0d`、未コミットの変更を含めて確かめた（V2 と別の一時のリポジトリ）。`check-docs.sh` が終了コード 0、`verify`（版を固定しない）が終了コード 1 で `notify.sh` を「不一致」。出力は `~/.claude/harness-rollout/p9-evidence/c11/t-engine-v2-v6.txt` |
| V7 | 済 | 2026-10-26。`@87beb0d`、未コミットの変更を含めて確かめた。`scripts/harness/harness-log-map.test.sh` が 4 件中 4 件期待どおり。出力は `~/.claude/harness-rollout/p9-evidence/c12/t-engine-v7-v9.txt` |
| V8 | 済 | 2026-10-26。`@87beb0d`、未コミットの変更を含めて確かめた。`scripts/harness/harness-log-map.test.sh` が 4 件中 4 件期待どおり。出力は `~/.claude/harness-rollout/p9-evidence/c12/t-engine-v7-v9.txt` |
| V9 | 済 | 2026-10-26。`@87beb0d`、未コミットの変更を含めて確かめた。`scripts/harness/harness-log-map.test.sh` が 4 件中 4 件期待どおり。出力は `~/.claude/harness-rollout/p9-evidence/c12/t-engine-v7-v9.txt` |
| V10 | 済 | 2026-10-26。実装レビューの 1 段目（impl-reviewer・design-reviewer・security-reviewer）は重大 0、2 段目（Codex、gpt-6.1-sol）は重大 0・推奨 2・任意 1。採った 12 件を反映し、impl-reviewer の反映の後の確かめで合格。採らなかった 3 件は監督の会話への報告に書く。判断の記録の「手順 17 の 1 段目の指摘の反映」「手順 17 の 2 段目（Codex）の指摘の反映」の行 |
| V11 | 未 | |
| 手順 1 | 済 | 2026-10-25。計画を起票し、設計レビューの 2 回目で指摘の解消を確かめた。U1〜U3 は利用者の決定（2026-10-25。判断の記録の「利用者の決定」の行）を反映した |
| 手順 2 | 済 | 2026-10-25。`~/.claude/harness-rollout/p9-evidence/c11/t-engine-before-*`（試験ごとの `ok: ` の行 5 つ、vitest の件数、`npm run check` の出力、定期の走査の報告と出力）。`ac4555f` の出力から取った |
| 手順 3 | 済 | 2026-10-25。`scripts/harness/harness.conf`（新規）と `docs/PLANS.md` を未コミットの変更として置いた。置いた後に `npm run check:docs` と `bash scripts/harness/check-docs.test.sh`（175 件中 175 件）が終了コード 0（未コミットの変更を含めて確かめた） |
| 手順 4 | 済 | 2026-10-25。impl-reviewer の 1 段（対象: `scripts/harness/harness.conf`・`docs/PLANS.md`・この計画。未コミットの変更を含めて確かめた）で必須 0・推奨 1。推奨は手順 13 の箇条に足した（判断の記録の「手順 4」の行） |
| 手順 5 | 済 | 2026-10-25。まとめ役が作業用のコミット `87beb0d`（`scripts/harness/harness.conf`・`docs/PLANS.md`・この計画の 3 つ。push なし）を作った。コミットの後に `git status --short` が空で、`git log` の先頭が `87beb0d` であることを確かめた。V11 の検索の記録は `~/.claude/harness-rollout/p9-evidence/c21/t-engine-step5-commit-pre.txt` |
| 手順 6 | 済 | 2026-10-25。`@87beb0d`、未コミットの変更なしで流した。版の印の最新は `rules-2026.10.25-1`。`update`（`--apply` なし）は終了コード 0 で、置き換える 8・作る 3・区画を置き換える 2・設定の版を書き換える 1 が期待と一致し、止める・知らせるの行は無かった。流した後も作業ツリーに変更が無かった。出力は `~/.claude/harness-rollout/p9-evidence/c11/t-engine-update-plan.txt` |
| 手順 7 | 済 | 2026-10-25。利用者が `update` の計画（手順 6 の出力）による書き換えを承認した（会話 910f67f4 の発言番号 6。判断の記録の「手順 7 の利用者の決定」の行） |
| 手順 8 | 済 | 2026-10-25。`@87beb0d` の上で `--apply` つきで流した（計画のファイルは流す間だけコミットの中身に戻した。判断の記録の「手順 7 の利用者の決定」の行）。終了コード 1。書いたのは写し 8 つの置き換え、3 つの新規（`scripts/harness/checks.d/README.md`・`stack-adapter.sh`・`stack-adapter.test.sh`）、`docs/PLANS.md` の区画 2 つ、`harness.conf` の `template_version` の 1 行、`docs/harness-log.md` の 1 行。道具の確かめは、`verify` が 13 個すべて一致、文書の検査が OK、試験は `check-docs.test.sh`・`drift-scan.test.sh`・`stack-adapter.test.sh` が通り、`notify.test.sh` が 1 件で通らなかった（手順 11 で解く。発見の欄の「手順 8」の行）。出力は `~/.claude/harness-rollout/p9-evidence/c11/t-engine-update-apply.txt` |
| 手順 9 | 済 | 2026-10-25。7 組をひな形（`rules-2026.10.25-1`）と `diff` で比べ、差ごとの扱いを判断の記録の「手順 9」の行に書いた。取り込む差 3 つ（`.codex/hooks.json` の `-c core.fsmonitor=false`、`harness.yml` の注釈、`.secretlintrc.json` の正規表現）を手順 11・13 の箇条に足した |
| 手順 10 | 済 | 2026-10-25。`scripts/harness/checks.d/` に `check-list.sh`・`layer-ratings.sh`・`network-names.sh` と、それぞれの `.test.sh`（10・36・12 件。すべて期待どおり）を置いた。`AGENTS.md` の検査のコマンドの表の文書の行と、`docs/QUALITY_SCORE.md` の目標の表の測る項目の括弧書きを 16 個の名前に直した（判断の記録の「手順 10」の行）。`bash scripts/harness/check-docs.sh --print checks` の末尾 3 つが「文書の検査の一覧、層の評価の上限、通信の名前の一覧」の順。`bash scripts/harness/check-docs.test.sh` が 150 件中 150 件、`npm run check:docs` が終了コード 0 |
| 手順 11 | 済 | 2026-10-25。`scripts/harness/notify-paths.mjs` を消した（git を使わずファイルを消した）。`.codex/hooks.json` を K の `assets/codex-hooks.json`（`rules-2026.10.25-1`）と同じ中身にした。`.claude/settings.json` の `command` を K のひな形と同じ書き方にした（`permissions` は残した）。`docs/adr/README.md` の 0005 の状態と、0005 の「結果と限界」の末尾の注記を足した（判断の記録の「手順 11」の行）。`bash scripts/harness/notify.test.sh` が合格 43 件・不合格 0 件、`npm run check:docs` が終了コード 0 |
| 手順 12 | 済 | 2026-10-25。`scripts/harness/harness-log-map.test.sh` を新しく作った。単独で流して 4 件中 4 件が期待どおり（変える前の状態、V7、V8、V9）。`package.json` へのつなぎは手順 13。`npm run check:docs` が終了コード 0（判断の記録の「手順 12」の行） |
| 手順 13 | 済 | 2026-10-25。手順 13 の箇条のすべてを直した（`package.json`、`harness.yml`、`.secretlintrc.json`、`drift-scan.yml`、`AGENTS.md`、`ARCHITECTURE.md`、`eslint.config.mjs`、`docs/QUALITY_SCORE.md`、`docs/PLANS.md` の区画の外、`tech-debt-tracker.md`、`docs/harness-log.md`、ADR 0005 の注記のリンク、ADR 0007 と目録）。どうしたかと根拠は判断の記録の「手順 13」の行。`npm run check:docs` が終了コード 0。`npm run check` の結果は判断の記録の「手順 13」の行 |
| 手順 14 | 済 | 2026-10-26。V1 のとおり。`npm run scan:drift` は要対応 0 件で、手順 2 の報告と比べて段の名前（`check:secrets`・`lint`・`typecheck`・`test`・`check:docs`・`test:harness`・`check:arch`）と品質目標の行は変わらない（違いは日時・対象のコミット・所要秒・TD-6 の行・origin の行の名前と説明の文）。報告は `~/.claude/harness-rollout/p9-evidence/c11/t-engine-after-drift-scan-report.md`。早期通知の所要時間は 2.2 秒（上限 18 秒。`~/.claude/harness-rollout/p9-evidence/c11/t-engine-after-notify-time.txt`） |
| 手順 15 | 済 | 2026-10-26。対応表は `~/.claude/harness-rollout/p9-evidence/c11/t-engine-c11-5-map.md`。前の 433 件のうち、同じ名前で合格 188 件、期待の文言だけが違う同名 8 件、(i) 5 件、(ii) 42 件、(iii) 181 件、(iv) 9 件、どれにも当たらない 0 件。(i) の 5 件は新しい試験 `scripts/harness/project-config.test.sh` に足した（判断の記録の「手順 15」の行）。V5 は人が確かめる |
| 手順 16 | 済 | 2026-10-26。V2・V3・V6・V7〜V9 の行のとおり |
| 手順 17 | 済 | 2026-10-26。実装レビューの 1 段目（impl-reviewer・design-reviewer・security-reviewer）は重大 0、2 段目（Codex、gpt-6.1-sol）は重大 0・推奨 2・任意 1。採った 12 件を反映し、impl-reviewer の反映の後の確かめで合格。採らなかった 3 件は監督の会話への報告に書く。判断の記録の「手順 17 の 1 段目の指摘の反映」「手順 17 の 2 段目（Codex）の指摘の反映」の行 |
| 手順 18 | 未 | |
| 手順 19 | 未 | |
| 手順 20 | 未 | |

- 2026-10-25: 計画を起票した（手順 1 の途中）。終えたこと: 計画のファイルを書いた。残り: 設計レビューと、未決 U1〜U3 の
  利用者の答え。未コミットの変更: この計画のファイル（新規）だけ。
- 2026-10-25: 設計レビューの 1 段目と第二レビューの統合の結果で計画を直した（手順 1 の途中）。終えたこと: 判断の記録の
  「設計レビューの反映」の行のとおり直した。残り: 未決 U1〜U3 の利用者の答え。未コミットの変更: この計画のファイル（新規）だけ。
- 2026-10-25: 手順 2 を終えた。置き換えの前の `npm run check` の出力（`ac4555f`、終了コード 0）から、`check-docs.test.sh` 175 件・
  `notify.test.sh` 183 件・`lint-rules.test.mjs` 15 件・`check-arch.test.sh` 9 件・`drift-scan.test.sh` 51 件の `ok: ` の行を
  スクリプトごとのファイルに分け、vitest の件数（18 ファイル 144 件）とあわせて P9 の証拠の置き場の `c11/` に
  `t-engine-before-` で始まる名前で保存した。`npm run scan:drift` は要対応 0 件で、報告を同じ置き場に保存した。
- 2026-10-25: 手順 3 を終えた。未コミットの変更: `scripts/harness/harness.conf`（新規。手順 3 の中身）、`docs/PLANS.md`
  （進捗の節の区画 `plan-status-spec` の空の組、節「費用の節と見張り点」と区画 `plan-cost-spec` の空の組、古い計画の箇条を
  「古い計画の日数: 30」の行の形へ、`check-docs.sh` を直すと書いた 2 か所を規約の正本と `update` で置き換える旨へ）、
  この計画のファイル（新規）。手順 4 の実装レビューを待つ。
- 2026-10-25: 手順 1 を終えた。利用者の決定（U1〜U3）を、目的の節の「決まった点」、V5・V7、手順 1・5・10・12・13・15 と判断の
  記録に反映した。未コミットの変更: `scripts/harness/harness.conf`（新規）、`docs/PLANS.md`、この計画のファイル（新規）。
  次は手順 5（まとめ役が作業用のコミットを作る）。
- 2026-10-25: 手順 5・6 を終えた。手順 5 はまとめ役が作業用のコミット `87beb0d` を作った（push なし）。手順 6 の `update` の計画
  （`--apply` なし）は期待と 14 行すべてで一致した。未コミットの変更: この計画のファイル（手順 5・6 の状態の表と、この行）。
  次は手順 7（まとめ役が `update` の計画を利用者に示し、承認を得る）。
- 2026-10-25: 手順 7・8 を終えた。利用者の承認を受けて `update --apply` を流した（終了コード 1。NG は `notify.test.sh` の 1 件だけで、
  手順 11 で解く）。流した後の `npm run check:docs` は終了コード 0。未コミットの変更: 手順 8 で道具が書いたもの（状態の表の手順 8 の
  行のとおり）と、この計画のファイル（手順 5〜8 の状態の表、進捗、発見、判断の記録）。次は手順 9。
- 2026-10-26: 手順 9〜16 を終えた。未コミットの変更: 手順 8〜13 と手順 15 の変更（`git status --short` のとおり）と、この計画の
  ファイル。`git diff --summary` に実行の許可の変更は無い（`notify-paths.mjs` の削除だけ）。次は手順 17（実装レビュー）。
- 2026-10-26: 手順 17 の途中。実装レビューの 1 段目の指摘のうち、まとめ役が採った 8 件を反映した（判断の記録の「手順 17 の 1 段目の
  指摘の反映」の行）。反映の後の `npm run check` は終了コード 0。手順 17 の残り: まとめ役の次の段のレビュー。
- 2026-10-26: 手順 17 の途中。Codex の第二レビューの指摘 3 件を反映した（判断の記録の「手順 17 の 2 段目（Codex）の指摘の反映」の
  行）。反映の後の `npm run check` は終了コード 0。手順 17 の残り: まとめ役による統合。
- 2026-10-26: 手順 17 を終えた。利用者が対応表を確かめ（発言番号 13）、V5・V10 を済にした。利用者はコミット・push・PR の作成も
  指示した。次は手順 18（コミット・push・PR）。

## 発見

- 2026-10-25: 本体の検査 11 は、古い計画の日数を `docs/PLANS.md` の「古い計画の日数: <整数>」の行から読み、無ければ失敗にする
  （K の `assets/harness/check-docs.sh` 1186〜1193 行）。今の `docs/PLANS.md` にはこの行が無い（日数は今の `check-docs.sh` の
  `STALE_PLAN_DAYS` に持つ。`docs/PLANS.md` 36 行）。手順 3 で行を置く。
- 2026-10-25: 今の `.codex/hooks.json` は `HEAD:scripts/harness/notify-paths.mjs` の存在を確かめてから早期通知を起動する。
  `notify-paths.mjs` を消すなら、同じ変更で `.codex/hooks.json` を直す必要がある（手順 11）。
- 2026-10-25: `harness-copies.sh update` は、`scripts/harness/harness.conf` が無いと止まる（K の `scripts/harness-copies.sh` 332〜334 行）。
  設定のファイルは `update` が作らないので、手順 3 で手で作る。
- 2026-10-25: K の `check-docs.sh` の検査 1〜11 は、今の `check-docs.sh` の検査 1〜11 と、設定と文書から値を読むことのほかに、
  次の違いがある（`diff` で確かめた）。検査 2 は `claude_md_exact=no` のとき「`@AGENTS.md` だけの行がある」でよくなる（手順 3 で
  `yes` にして今の振る舞いを保つ）。検査 9 は、状態の表で「不合格」・根拠に「持ち越し:」を書いた基準を失敗にしない（足された
  振る舞いで、今の計画には当たらない）。
- 2026-10-25（手順 3）: 手順 3 の後の `docs/PLANS.md` を K の `assets/plans.md`（プレースホルダーを埋めたもの）と比べると、
  区画の中身と例のほかに、区画の外の「受け入れ確認の記録」の「置き場と名前」の 2 か所が違う（K は、状態の表で「不合格」と
  「持ち越し:」を書いた基準を失敗にしない旨と、絶対パスの形をパスの列挙でなく「ホームの下と一時ディレクトリの下」と書く）。
  前者は上の行の検査 9 の違いに当たる。手順 3 の範囲に無いので変えていない。扱いは判断の記録の「手順 4」の行で決めた。
- 2026-10-25（置き換えの調べ）: 実装の作業担当が、このプロジェクトの中身に K の写しを重ねた一時の場所で、写しの試験を流して
  置き換えの前と比べた（出どころは作業担当の調べ）。要点:
  - `check-docs.test.sh`: 175 件 → 146 件。名前が一致するのは 103 件。前にだけある 72 件のうち 60 件は T の検査 12〜14 の場合
    （手順 10 で追加の検査の試験へ移す）。`templates/` のパスの試験 2 件は、決まった点の U3 の (i) としてこのプロジェクトの試験に
    足し直す。
  - `notify.test.sh`: 183 件 → 43 件。名前が一致するのは 6 件。
  - `drift-scan.test.sh`: 51 件 → 29 件。名前が一致するのは 0 件。
  - K の `drift-scan.sh`（版の印 `rules-2026.10.25-1`）は、品質目標の表の読み取りが今の `drift-scan.sh`（`87beb0d`）より緩む点が
    3 つある。
    - (1) 3 つの表の見出しの行を、決まった文字列と完全一致で照らすこと（今の 240〜242 行・258〜267 行）が無くなる。K は見出しの
      列の名前で読み、ほかの列があってもよい（K の 487〜496 行）。
    - (2) 列の数をちょうど 4・6・7 と求めること（今の 285 行・289〜290 行）が無くなる。
    - (3) 層の表（表 2）が無いと要対応にすること（今の 310 行）が無くなる。K では層の表は省ける（K の 27 行）。
    - このプロジェクトの `docs/QUALITY_SCORE.md` の 3 つの表（16 行・51 行・65 行）は、K が要る列を持つので、走査は働く。
  - K の写しの `notify.test.sh` の項目「11: .claude/settings.json が notify.sh claude を呼ぶ」は、今の `.claude/settings.json` の書き方
    では失敗する（合格 42・不合格 1）。手順 11 で書き方を直す。
- 2026-10-25（手順 8）: `update --apply` の確かめで出た NG は 1 つだけで、手順 10〜13 で解けるものに当たる。
  - `notify.test.sh` の項目「11: .claude/settings.json が notify.sh claude を呼ぶ」が通らない。上の行のとおり、手順 11 で
    `.claude/settings.json` の書き方を直して解く。
  - 手順 10〜13 で解けないものは無い。文書の検査は、T の検査 12〜14 が本体から外れたので、`AGENTS.md` と `docs/QUALITY_SCORE.md` の
    括弧書きが古いままでも OK になる（手順 10 の `check-list.sh` を置くまでは、この食い違いを検査が拾わない）。
  - 道具が `docs/harness-log.md` に足した行の「出どころ」の列は「規約の版の更新（rules-2026.10.25-1 → rules-2026.10.25-1）」で、
    前と後の版が同じになっている。設定に `template_version` が無かったので、前の版を最新の版の印とみなしたため（前提の節の
    `BASE_TAG` の決まり）。まとめ役の決定で、手で直さず道具の出力のまま残す。K の道具への改善の候補として、監督の会話への
    報告に書く（まとめ役が書く）。
- 2026-10-25（手順 8、手順 10 で気づいた）: `update --apply` で置き換えた写しのうち、`scripts/harness/check-docs.sh`・`check-secrets.sh`・
  `notify.sh` の 3 つの実行の許可が外れた（`git diff --summary` で 100755 から 100644 への変更）。K の版の印 `rules-2026.10.25-1` では
  `check-docs.sh` は 100755、ほかの 2 つは 100644 で、道具が書いたファイルの許可は 0600 だった。このプロジェクトでは 3 つとも
  `bash <ファイル>` で呼ぶので、検査と試験は動く。写しの中身ではないので手で直してよいかは、まとめ役の判断を待つ（この作業では
  直していない）。K の道具への改善の候補（置き換えるときに元のファイルの許可を保つ）として、監督の会話への報告に書く。

## 判断の記録

- 2026-10-25（起票）: T の検査 12〜14 の振り分けは、どれもこのプロジェクトの文書（`AGENTS.md`・`docs/QUALITY_SCORE.md`・
  `ARCHITECTURE.md`）と `eslint.config.mjs` の形に依る検査なので、本体へ移さず追加の検査の口へ移す（K の `SKILL.md` 271 行の
  本体へ移す条件「2 つ以上のプロジェクトの `checks.d/` に同じ働きの検査がある」に当たらない）。
- 2026-10-25（起票）: そのほかのこのプロジェクトだけの検査のファイルの振り分け。
  - `check-arch.sh`・`check-arch.test.sh`・`lint-rules.test.mjs`: 残す（このプロジェクトの層と ESLint の規則の検査で、K に正本が
    無い。`scripts/harness/` の下の写しでないファイルとして置く）。
  - `check-secrets.sh`・`check-secrets.mjs`: 部品 `node-secrets` の写しに置き換える（K の部品の正本は `--file` を足したもので、
    定期の走査が使う。K の `SKILL.md` 324〜326 行）。`.secretlintrc.json` は描いた物なので、このプロジェクトのものを残す
    （手順 9 で差を確かめる）。
  - `notify-paths.mjs`: 消す（K の `notify.sh` が perl で入力を読む）。
  - `drift-scan.sh`・`drift-scan.test.sh`・`notify.sh`・`notify.test.sh`・`check-docs.sh`・`check-docs.test.sh`: 中心の写しに置き換える。
  - `stack-adapter.sh`・`stack-adapter.test.sh`: 部品 `node-harness` の写しとして新しく置く。
  - `.github/workflows/drift-scan.yml`・`.claude/settings.json`: 描いた物なので、このプロジェクトのものを残し、要る箇所だけ直す
    （手順 9・11・13）。
- 2026-10-25（起票）: 必須のファイルの一覧（`required.1`）と導入済みの印の版（1）は変えない。版を上げると、必須のファイルの意味が
  変わり、`AGENTS.md` と設定の両方を同時に直す必要が出るが、この作業の目的（検査の本体の置き換え）に要らないため。
- 2026-10-25（設計レビューの反映）: 1 段目（reasoning-reviewer の R1〜R9、design-reviewer の D1〜D6）と Codex の X1〜X3 の指摘を
  すべて採った。変えたことと理由:
  - V2・V6 は HEAD ではなく、作業ツリーを写した一時のリポジトリで確かめる形に決めた。案 A では `update` の結果が未コミットなので、
    HEAD では置き換えた後の写しを試せないため（R1・X1）。2 回目の作業用のコミットは置かない。
  - 一時のリポジトリの写し方を 1 つの手順にまとめ（手順の節の冒頭）、削除済みの項目を除き、写しの失敗を無視しない形にした（X2）。
    V2・V6 の写しの変更はコミットの前に加え、本体の検査 12 の失敗が混ざらないようにした。
  - 準備の変更の実装レビュー（手順 4）を、作業用のコミットの前に置いた（X3）。
  - 由来の記録の試験に、K の試験と同じ git の付け方、`HARNESS_TODAY` の固定、変える前の状態の確かめを書き、V7〜V9 を NG の行の
    有無と終了コードの両方で判定する形にした（R2・D5）。`HARNESS_TODAY` を固定しても日付に左右されないよう、写すときに進行中の
    計画を除く。
  - 描いた物を版の印のひな形と手で比べる手順 9 を足した（R3）。`update` の計画を利用者に示して承認を得る関門の手順 7 を足した（R4）。
  - U3 の背景に、P9 の計画の変更として承認が要ることを書いた（R5）。V3 は比べの相手の版を固定する（R6。V6 は記録された版との
    照合で失敗するので固定しない）。行の範囲を直した（R7。`docs/PLANS.md` 26〜36 行、`AGENTS.md` 5〜8 行）。
    TD-6・TD-7 の見直しを手順 13 に足した（R8）。
  - `check-list.sh` は今の検査 12 の前半だけにし、後半とその試験 1 件は K の正本で確かめるべき項目として持ち越す（D1・R9）。
    この扱いは、下の「利用者の決定」の行の U3 の (iii) で置き換えた（監督の会話への報告に書き、対応づけ済みと数える）。
  - `harness.yml` は 1 本のまま保ち、ADR 0007 にひな形との対応と差を見る手順を書く（D2）。写しの試験のつなぎは新しい検査を
    足さず ADR 0007 に手順を書く（D3）。ADR 0005 の本文は変えず、目録の状態と注記で 0007 を指す（D4）。ADR 0007 に括弧書きの
    直しと追加の検査の並びを書く（D6）。
  - `update` は文書の検査が失敗すると試験を流さないので、全試験の結果は手順 14 で確かめる。秘匿値の検査の写しから ADR 0002 への
    注釈が消えるので ADR 0007 で補う。早期通知の所要時間を手順 14 で 1 回測る（Codex の補足）。
  - 手順の番号を振り直した（手順 4・7・9 を足したため。前の手順 4〜17 は、今の手順 5・6・8・10〜20 に当たる）。
- 2026-10-25（手順 2）: 基準の記録は、手順 2 の指定のとおり P9 の証拠の置き場の `c11/` に置き、この作業の分と分かるよう
  ファイル名の頭を `t-engine-before-` にした（手順 15 の対応表も同じ置き場に置くため）。スクリプトの境目は、出力の
  「<名前>.test: N 件中 N 件が期待どおり」の行で分け、各ファイルの行数が N と一致することを確かめた。
- 2026-10-25（手順 3）: 設定のファイルの注釈「敷いたひな形の規約の版」の行は、`template_version` の行を書かないので、ファイルの
  末尾に置いた。`update` は `template_version` の行が無いとき末尾に足す（K の `harness-copies.sh` 459〜463 行）ので、足された行が
  この注釈の直後に来る。`node-harness` の断片は、K の断片のファイルの注釈の行ごと写した。
- 2026-10-25（手順 4）: 準備の変更の実装レビュー（impl-reviewer の 1 段）は必須 0・推奨 1。発見の欄の `docs/PLANS.md` と K の
  `assets/plans.md` の 2 つの違いは次のとおり扱う。
  - 不合格と持ち越しを書いて閉じた基準を失敗にしない旨の括弧書き: 推奨の指摘を採り、手順 13 の文書の箇条に足した。新しい
    検査（K の `assets/harness/check-docs.sh` 792〜797 行）の振る舞いを文書に書くため。
  - 絶対パスの形の書き方: 直さない。K の `check-docs.sh` 730 行も今の `check-docs.sh` 552 行も同じ 5 つの形を検査し、
    `docs/PLANS.md` の文はそれを列挙していて正しいため。
- 2026-10-25（手順 4）: 手順 2 の基準の記録の置き場は、計画の指定どおり `c11/` のままとする（まとめ役の確認）。
- 2026-10-25（利用者の決定）: 未決だった U1〜U3 は、利用者の決定（2026-10-25T13:5xZ ごろ）で決まった。記録の正本は P9 の計画の
  10 節「2026-10-25 手順 15（T-engine）で決めたこと（会話 910f67f4）」で、P9 の計画の側では判断 1〜4 と呼ぶ。
  - U1（P9 の計画の判断 1、案 A）: このプロジェクトだけの試験 `scripts/harness/harness-log-map.test.sh` に C12 の 3 つの場合を置く。
    この計画の案 2 に当たる。P9 の計画の C12 の文の「`check-docs.test.sh` に足す」は、この試験に置くと読み替える。
    - 外した案: `checks.d/` に試験だけを置く（この計画の案 1）。`checks.d/` の「試験は同じ名前の検査と組にする」決まりから外れるため。
    - 外した案: 正本の試験の同じ形の 3 件で足りると読む（案 3）。このプロジェクトの地図を読まないため。
    - 外した案: K の正本の試験に足す。K を変えない決まりに反するため。
  - U2（P9 の計画の判断 3）: `scripts/harness/harness.conf`・`docs/PLANS.md`・この計画のファイルの 3 つを、作業用のコミットにする
    指示が出た。この計画の案 A に当たる。コミットはまとめ役が行い、push・PR は含まない。
    - 外した案: 一時の複製で `update` を流して結果を写す（案 B）。この worktree のファイルを確かめたことにならないため。
  - U3（P9 の計画の判断 2、案 A）: C11 (5) は、置き換えの前の試験の項目を 1 件ずつ (i)〜(iv) に分けた対応表で読む。
    この計画の案 i に当たる。分け方は目的の節の「決まった点」の U3 のとおり。(iii) は、起票のときの「K の試験へ足すことを
    持ち越す」から、「K で正本の試験に足す作業として監督の会話への報告に書き、C11 (5) の上は対応づけ済みと数える」に変わった。
    P9 の計画の C11 (5) の「すべて合格」は、「すべて合格か、根拠つきで対応づけた」と読み替える。
    - 外した案: 対応の無い項目ごとに止めて尋ねる（案 ii）。1 件ごとに止めると作業が進まないため。
  - 費用（P9 の計画の判断 4、案 A）: 手順 15 の上限を 45 ドルから 85 ドルに上げ、68 ドルを超えたら続ける前に尋ねる。費用は
    P9 の計画の費用の表で見張る。この計画には費用の節が無いので、費用の値は書かない。
    - 外した案: 45 ドルのままにする（案 B）。新しい会話へ引き継ぐ（案 C）。
- 2026-10-25（`.claude/settings.json` の書き方）: K の写しの `notify.test.sh` の項目 11 が探す書き方に合わせ、このプロジェクトの
  `.claude/settings.json` の `command` を K のひな形の形に直す（手順 11）。外した案: K の正本の試験を直す。`.claude/settings.json` は
  各プロジェクトが持つ描いた物で、K のひな形はすでに試験が探す書き方になっている。外れているのはこのプロジェクトの側なので、
  正本を直す必要は無い。
- 2026-10-25（手順 7 の利用者の決定）: 利用者が、`update --apply` でこのプロジェクトのファイルを書き換えることを承認し、書き込みの
  直前に残る計画のファイルの未コミットの変更は案 A で扱うと決めた（会話 910f67f4 の発言番号 6）。案 A: 書き込みの直前に計画の
  ファイルを一時フォルダに控え、計画のファイルを `87beb0d` の中身に戻し、書き込みが終わったらすぐに控えから戻す。そのとおりに行い、
  戻した後の計画の差分が控える前と同じであることを確かめた。
- 2026-10-25（手順 9）: 描いた物 7 組を、版の印 `rules-2026.10.25-1` のひな形と比べた（差分は作業担当の一時の置き場に置いた）。
  差ごとの扱い:
  - `agents.md` と `AGENTS.md`: プレースホルダーと、このプロジェクトの内容（アプリの説明、決定、秘匿値の追加の決まり、落とし穴）の
    ほかの差は、導入済みの印の説明（手順 13 で直すと決めてある）と、文書の地図の「定期の走査」の行（手順 13 で部品の断片の形に
    直すと決めてある）だけ。新しく取り込むものは無い。地図の「検査」の行は、このプロジェクトの行のほうが、検査を定めるファイルを
    多く並べているので残す（本体の検査 12 は、この行の 2 列目を読む）。
  - `codex-hooks.json` と `.codex/hooks.json`: 手順 11 で直すと決めてある差（`notify-paths.mjs` の確かめを外し、未追跡のファイルの
    確かめを足す）のほかに、最初の `git worktree list` に `-c core.fsmonitor=false` を付ける差がある。取り込む（手順 11 で K の
    `command` をそのまま使う）。ほかの git の呼び出しと同じく、作業ツリーの設定のファイルの監視のプログラムを起動しないため。
  - `claude-settings.json` と `.claude/settings.json`: `command` の引用符の位置（手順 11 で取り込むと決めてある）のほかは、
    このプロジェクトの `permissions` の行だけ。`permissions` は残す。
  - 部品の `drift-scan.yml` と `.github/workflows/drift-scan.yml`: pull request の `paths`（手順 13 で `scripts/harness/**` にすると
    決めてある）のほかに、同時実行の制御・保存期間（予定実行 90 日、ほかは 7 日）・成果物の名前・`node-version-file` と
    `cache: npm` が違う。どれも取り込まない。保存期間と同時実行の制御は ADR 0006 の決定（54 行）で、成果物の名前と Node の版の
    指定はこのプロジェクトの `harness.yml` と合わせたもの。`cache: npm` は、K のひな形が「ほかのワークフローが書いた cache を、
    公開する前の確かめの道具に混ぜない」ために使わない形だが、このプロジェクトでは `harness.yml` も同じ `cache: npm` を使い、
    `npm ci` が `package-lock.json` の integrity で中身を照らすので、この作業では変えない。`paths` の `.secretlintrc.json` の行は、
    走査が公開の前の確かめで秘匿値の検査（`.secretlintrc.json` を読む）を使うので残す。
  - `ci-harness.yml` と部品の `ci-secrets.yml` と `.github/workflows/harness.yml`: 1 本にまとめた形（棚卸しの表の CI の行）の
    ほかの差は、取得の段の `fetch-depth: 0` の注釈（K は本体の検査 12 の merge-base のためと書く）と、変更の範囲の起点の読み方
    （K は GitHub の式を使わずイベントの JSON から読む。ひな形のプレースホルダーと形が重ならないための書き方）。前者は手順 13 で
    注釈だけ取り込む。後者は取り込まない（このプロジェクトの書き方で同じ値を読めているため）。
  - 部品の `secretlintrc.json` と `.secretlintrc.json`: `Anthropic OAuth token` の規則の正規表現を `(?:…)` で囲む差だけ。意味は
    変わらないが、ひな形と中身をそろえるため、手順 13 で取り込む。
- 2026-10-25（手順 10）: 3 つの追加の検査と試験の移し方。
  - `AGENTS.md`（検査のコマンドの表の文書の行）と `docs/QUALITY_SCORE.md`（目標の表の測る項目）の括弧書きは、手順 13 ではなく
    手順 10 で直した。`check-list.sh` を置いた時点で、古い括弧書きを検査が失敗にし、手順 10 の終わりの `npm run check:docs` が
    通らないため。名前の順は手順 10 の設計のとおり。
  - 試験は、本体の `check-docs.sh` を通さずに、追加の検査のファイルを本体と同じ呼び方（作業ディレクトリを検査する根にし、
    `HARNESS_ROOT` と `HARNESS_ENGINE_DIR` を渡し、標準入力を `/dev/null` にする）で直接動かす。一時の根には、その検査が読む
    ファイルだけを置く。手順 15 の対応表で前の項目と並べられるよう、場合の名前は置き換えの前の試験と同じにした。
  - 置き換えの前の試験で本体の件数の行（「check-docs: 2 件の問題があります」「check-docs: 1 件の問題があります」）を確かめていた
    2 件は、`check-docs: NG: ` の行の数（2 と 1）を確かめる形にした。追加の検査は件数の行を出さず、本体が NG の行を数えるため。
  - 文言から検査の番号を外した（例:「eslint.config.mjs がありません（検査 13 が」を「（通信の名前の一覧の検査が」に）。追加の
    検査には番号が無いため。直し方が指すファイルは、`scripts/harness/check-docs.sh` から各追加の検査のファイルに直した。
  - `check-list.sh` は、名前の一覧を読めないとき（本体の `--print checks` が失敗するか何も出さないとき）を失敗にする。置き換えの
    前の `CHECK_NAMES` には無かった場合で、試験は足していない（本体の写しを壊す見本を作れないため）。
- 2026-10-25（手順 11）: ADR 0005 の注記と目録の状態では、0007 をリンクにせず番号だけで書いた。0007 のファイルは手順 13 で作るので、
  手順 11 の終わりにリンクを書くと、文書の検査（リンク）が通らないため。手順 13 で 0007 を作るときに、0005 の注記の「0007」を
  `docs/adr/0007-harness-engine-copies.md` へのリンクにする（目録の状態の列は、0001 の前例と同じく番号だけのまま）。
- 2026-10-25（手順 12）: `harness-log-map.test.sh` の書き方。
  - 一時のリポジトリは、場合ごとに作り直す（`checkout` と `clean` で戻す形は使わない。戻し忘れで場合どうしが影響し合わないため）。
    写す一覧は最初に 1 回だけ作る。
  - 本体の検査 12 の NG の行は、「check-docs: NG: 」で始まり「検査の由来の記録」を含む行とした（本体の検査 12 の 2 つの NG の文言が、
    どちらもこの語を含む。写しの `scripts/harness/check-docs.sh` の 1307 行と 1353 行）。
  - V7 の変更は `.dependency-cruiser.cjs` の末尾へのコメントの行の追加、V8 の記録の行は 5 列の表に合わせた 1 行、V9 の変更は
    一時のリポジトリの `src/` の下の最初の `.ts` のファイルの末尾へのコメントの行の追加にした。
- 2026-10-25（手順 13）: 箇条のほかに決めたこと。
  - `eslint.config.mjs` は、箇条の 11 行・13 行に加えて、17 行のコメント（「npm run check:docs の検査 13 が読み取る」）も
    `scripts/harness/checks.d/network-names.sh` に直した。同じ検査を指すコメントで、残すと番号の無い追加の検査を古い番号で
    指したままになるため（コメントだけで、振る舞いは変わらない）。
  - `docs/QUALITY_SCORE.md` 9〜10 行の走査の側の記述は、K の `drift-scan.sh`（冒頭の説明の 4。表を見出しの列の名前で読み、ほかの
    列があってもよい）と合わない「同じ変更で走査と検査 14 の両方を直す」を、「同じ変更で `layer-ratings.sh` を直し、走査が要る
    列を残す（走査は写しで手で変えないため）」に直した。7 行の「見出しの行の文字列と列の数を変えない」の決まりは、
    `layer-ratings.sh` が表 1 の見出しの行を文字列で比べるので残した。
  - TD-6 は消した。K の写しの `notify.test.sh` に `前後で変わらない`・`snapshot`・`ls -la` を `grep` して 0 件で、問題の試験 15 が
    置き換えで無くなったため。TD-7 は残し、場所を写しの `scripts/harness/drift-scan.sh` 466〜535 行に、検査 14 への参照を
    `scripts/harness/checks.d/layer-ratings.sh` に直した。K の `drift-scan.sh` も、縦線で始まらない行で表を閉じる（527 行の
    `{ intable = 0`）ので、問題は残る。写しなのでこのプロジェクトでは直せず、直すなら K の正本で直す（監督の会話への報告の候補）。
  - `docs/harness-log.md` は、検査 12〜14 の元の 3 行の「外した変更」の列を埋め、移した 3 つの検査・早期通知の付け替え・由来の
    記録の試験の 5 行を足した。検査 12 の行には、移さなかった後半（冒頭の一覧の数と `CHECK_NAMES` の数の照合）と理由を書いた。
    由来の記録の試験の行の出どころは、決まった点の U1 の 1 件で、目安に満たないが利用者が選んだ形で書いた。
  - `docs/PLANS.md` の括弧書きは、K の `assets/plans.md` 209〜210 行の文をそのまま使った。同じ段落の絶対パスの形の並び
    （K は「ホームの下と一時ディレクトリの下の絶対パス」と書く）は、箇条に無いので変えていない。
  - `AGENTS.md` は 117 行（上限 120）。
- 2026-10-25（実行の許可。まとめ役の決定）: `update --apply` で外れた `scripts/harness/check-docs.sh`・`check-secrets.sh`・`notify.sh` の
  実行の許可は、まとめ役が `chmod +x` で `87beb0d` の 100755 に戻した（`git diff --summary` に許可の変更が無いことを確かめ済み）。
  写しの照合（比べる道具の `verify` と本体の検査 13）は許可を見ないので合否に影響せず、このプロジェクトの既存の許可を変える
  理由が無いため。手順 14 以降も `git diff --summary` で許可が変わっていないことを確かめる。発見の欄の、K の道具の改善の候補
  （置き換えるときに元の許可を保つ）はそのまま残す。
- 2026-10-26（手順 15）: 対応表の作り方と、(i) の置き場。
  - 名前の突き合わせは、`ok: ` の行の全体が同じものを同じ名前とし、残りは、括弧の中の期待（「（通る）」「（失敗する: …）」）を
    除いた名前で後の項目と比べた。期待の文言だけが違う 8 件（手順 10 で検査の番号と件数の行を変えた 3 件と、写しの試験の見本の
    計画の名前が変わった 5 件）は、同じ名前の項目が合格したものとして数えた。
  - (i) の 5 件（`templates/` のパスの 2 件、定期の走査が実物の文書を読める 1 件、フックの設定の形と `.codex/config.toml` の 2 件）は、
    新しい試験 `scripts/harness/project-config.test.sh`（写しでない）に、前と同じ場合の名前で足し、`package.json` の `test:harness`
    の最後につないだ。`harness-log-map.test.sh` は C12 の試験として名前を決めたので、別のファイルにした。`templates/` の無いパスの
    場合は、一時のリポジトリに `templates/module/` が実在するので、`templates/no-such-module/` にした。定期の走査の場合は、
    報告を公開する前の秘匿値の検査が依存を使うので、一時のリポジトリに作業ツリーの `node_modules` を指すリンクを置いた
    （`/node_modules` は `.gitignore` で除く）。あわせて `AGENTS.md` の検査の試験の行、`harness.yml` の段の名前、
    `docs/harness-log.md` に 1 行を足した。
  - (iii) の 181 件は、置き換えの前のこのプロジェクトの `notify.sh`・`drift-scan.sh`・`check-docs.sh` の振る舞いの試験で、
    同じ振る舞いが K の写しにある（対応表の根拠の列に写しのファイルと行）のに、K の写しの試験に項目が無いもの。K の正本の
    試験に足す作業として、監督の会話への報告に書く（まとめ役が書く）。
- 2026-10-26（手順 16）: V6 の `verify` は、V6 の操作の文のとおり比べの相手の版を固定せずに流した（`HARNESS_COPIES_CMP_TAG` を
  付けたのは V3 だけ）。V6 の「不一致」は冒頭に記録された版の正本との照合で決まるので、固定の有無で結果は変わらない。
- 2026-10-26（手順 17 の 1 段目の指摘の反映）: 実装レビューの 1 段目（impl-reviewer・design-reviewer・security-reviewer。重大 0）の
  指摘のうち、まとめ役が採った 8 件を反映した。(1) `docs/harness-log.md` の試験「写し 1」の行の「外した変更」を埋めた。
  (2) `tech-debt-tracker.md` の「同じ変更で走査も直す」を、走査が読む見出しの行（写しの `TD_HEADER`）のまま保つ、に直した。
  (3) `harness-log-map.test.sh` と `project-config.test.sh` の冒頭に、一時のリポジトリの作り方が同じで両方を同じ変更で直すことと、
  進行中の計画を写さない理由（基準の日を固定するので、後で起票した計画を本体の検査 11 が判定できず落ちる）を書いた（共通の部品
  には切り出さない）。(4)(5) ADR 0007 の「更新のたびに行うこと」に 3 つの箇条、「結果と限界」に、フックが確認なしに実行する範囲に
  `checks.d/*.sh` が入ることを足した（Claude Code は会話を始めた作業ツリーのもの、Codex は本体の HEAD と同じときだけ本体のもの）。
  (6) `project-config.test.sh` の走査の場合に、報告に層 `src/domain/` の行（`check:arch=成功`）と領域「秘匿値がリポジトリに無い」の行
  （`check:secrets:push=照合しない`）が有ることの照合を足した。(7) 同じ試験に、`scripts/harness/` の直下の `*.test.sh`・`*.test.mjs` が
  すべて `test:harness` にあることの場合を足した（`checks.d/` の下は、写しの `check-docs.test.sh` の 1118〜1127 行が流すので除く）。
  (8) `checks.d/check-list.test.sh` の本体の検査の名前を、`--print checks` の出力から位置（末尾・中ほど・7 番目・2 番目と 3 番目）で
  選ぶ形にした。7 番目は本体の検査 7 で、場合の名前「検査 7 を欠く」の意図を保つ。採らなかったもの: `.codex/hooks.json` の
  `--exclude-standard`（K のひな形と同じ形で、このプロジェクトだけ変えると K と食い違うため。まとめ役が K の改善の候補として
  監督の会話へ報告する）と、`check-secrets.mjs`・`notify.sh` の写しへの指摘（写しは手で変えないため）。反映の後の `npm run check` は
  終了コード 0 で、`project-config.test.sh` は 6 件中 6 件。`git diff --summary` に許可の変更は無い。
- 2026-10-26（手順 17 の 2 段目（Codex）の指摘の反映）: Codex の第二レビューの指摘 3 件を反映した。(1) `project-config.test.sh` の
  設定の場合に、規約のひな形 `rules-2026.10.25-1` の `assets/codex-hooks.json` の中身をそのまま写して持ち（CI では規約のリポジトリを
  読めないので実行のときに読まない）、`.codex/hooks.json` の各フックの command がその command と一字一句同じであることを照らす形にした
  （`.claude/settings.json` の command は、前から全文の期待値で照らしている）。ひな形が変わったときに期待値を直すことは、ADR 0007 の
  「更新のたびに行うこと」の「フックの設定の期待値を直す」の箇条が受け持つ。C11 (5) の対応表の `notify.test` 17 の (iii) の行の根拠に
  「起動の文字列は `scripts/harness/project-config.test.sh` で全文を照らす」を足した（分け方は変えない）。(2) 同じ試験の走査の場合に、
  実物の `tech-debt-tracker.md` の各 TD の行について、報告に `3/<識別子>` と場所のパスの行（写しの `drift-scan.sh` 450 行の形）が
  有ることの照合を足した（行が無ければ `3/なし` を求める）。(3) ADR 0007 の「結果と限界」の Codex の起動元の条件を、34〜35 行に
  合わせて「除外されていない未追跡のファイルも無いとき」に直した。反映の後の `npm run check` は終了コード 0 で、
  `project-config.test.sh` は 6 件中 6 件。`git diff --summary` に許可の変更は無い。
- 2026-10-26（(iii) の 181 件の扱い）: 対応表の (iii) の 181 件は、この会話では K の正本の試験に足さず、監督の会話に渡す。利用者が
  発言番号 13（2026-10-25、会話 910f67f4）で推奨どおりとした。理由は、この会話の作業の範囲が T だけで、K の正本と写しはここでは
  変えないことなど。

## 結果と振り返り
