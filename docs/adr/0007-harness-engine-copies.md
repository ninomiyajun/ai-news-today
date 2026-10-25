# 0007 検査の本体を規約の正本の写しにすることと、設定・追加の検査の口・早期通知・CI の扱い

## 背景

このプロジェクトの検査のスクリプト（`scripts/harness/` の文書の検査、早期通知、定期の走査、秘匿値の検査と、その試験）は、
ハーネスの規約のひな形から敷いた後、このプロジェクトの中で直してきた。同じ働きの検査を持つほかのプロジェクトとの間で
中身が分かれ、規約の側で直した誤りや足した検査が、このプロジェクトに届かなかった。

規約の側に、検査の本体を 1 つの正本にし、各プロジェクトには写しを置き、プロジェクトごとの違いは設定のファイルと
追加の検査の口に分ける仕組みができたので、このプロジェクトの検査をその写しに置き換えた。

## 判断

- **検査の本体は規約の正本の写しにする。** 写しは、冒頭に `harness-copy` の行（正本の場所・版の印・中身の SHA-256）がある
  ファイルで、`scripts/harness/` の `check-docs.sh`・`check-docs.test.sh`・`notify.sh`・`notify.test.sh`・`drift-scan.sh`・
  `drift-scan.test.sh`・`check-secrets.sh`・`check-secrets.mjs`・`stack-adapter.sh`・`stack-adapter.test.sh`・`checks.d/README.md`
  と、`docs/PLANS.md` の 2 つの区画（`plan-status-spec`・`plan-cost-spec` の印で囲んだ部分）である。写しは手で変えない。
  文書の検査（写しの中身）が、冒頭の SHA-256 と中身の一致を確かめる。
- **更新は、規約のリポジトリの `harness-copies.sh update` で行う。** まず `--apply` なしで流して置き換えの計画を見て、
  よければ `--apply` を付けて流す。道具は、置き換えた版を設定の `template_version` に書き、検査の由来の記録
  （`docs/harness-log.md`）に行を足す。
- **プロジェクトごとの違いは、設定のファイルと追加の検査の口に分ける。**
  - 設定のファイル `scripts/harness/harness.conf` はこのプロジェクトが正本で、手で書く。必須のファイルの一覧
    （`required.<版>`）、`AGENTS.md` の行数の上限、`ARCHITECTURE.md` に書いたパスの拾い方、採用した部品、由来の記録を
    求めない行の形を持つ。`claude_md_exact=yes` で、`CLAUDE.md` が「@AGENTS.md」の 1 行と完全に一致することを保つ
    （置き換えの前の文書の検査と同じ振る舞い）。
  - このプロジェクトだけの文書の検査は、`scripts/harness/checks.d/` に置く。置き換えの前の文書の検査の 12〜14
    （文書の検査の一覧、通信の名前の一覧、層の評価の上限）を、`check-list.sh`・`network-names.sh`・`layer-ratings.sh` に
    移した。試験は同じ置き場の `<名前>.test.sh` で、`check-docs.test.sh` が最後に流す。
- **早期通知が実行するプログラムの範囲を、[0005](0005-early-notify-hooks.md) から次のとおりに置き換える。** 実行するのは、
  起動元の `scripts/harness/notify.sh` と `check-docs.sh` と、起動元の `scripts/harness/checks.d/` の追加の検査だけで、
  ほかに起動するのは perl・git などのプログラムだけである（`notify.sh` の冒頭の「安全の決まり」）。入力の変換は `notify.sh`
  の中の perl で行うので、`notify-paths.mjs` は消した。`.codex/hooks.json` と `.claude/settings.json` のフックは、規約の
  ひな形と同じ書き方にした（Codex のフックは、`notify-paths.mjs` の有無ではなく、`scripts/harness/` に除外されていない
  未追跡のファイルが無いことを、起動の前に確かめる）。
- **CI は 1 本の `.github/workflows/harness.yml` のまま保つ。** 規約のひな形は 2 本（文書の検査の `ci-harness.yml`、敷いたときの
  置き先は `.github/workflows/harness-docs.yml`。部品 node-secrets の `ci-secrets.yml`、同じく `.github/workflows/harness-secrets.yml`）
  だが、このプロジェクトでは秘匿値の検査の 2 段を、ほかのスクリプトより先に 1 本の中で動かす（[0002](0002-secret-scan-scope.md)）。
  2 本に分けても、同じ検査を 2 回動かし、秘匿値の検査の後に動く段が 2 本に分かれるだけで、得が無いためである。

### 更新のたびに行うこと

- **CI のひな形の差を手で見る。** 2 つのひな形の置き先にファイルが無いので、`update` はひな形の差を知らせない。更新のたびに、
  規約のリポジトリで次を流して 2 つのひな形の差を見て、`harness.yml` に取り込むかを決める:
  `git -C ~/.agent-rules diff <前の版の印> <新しい版の印> -- home/agents/skills/project-harness-init/assets/ci-harness.yml home/agents/skills/project-harness-init/assets/parts/node-secrets/assets/ci-secrets.yml`
- **新しく作られた写しの試験をつなぐ。** 写しの試験（`*.test.sh`）は、`package.json` の `test:harness` に自動ではつながらない。
  `update` の出力の「作る」の行に試験があれば、同じ変更で `test:harness` に足す。
- **検査の名前の括弧書きを直す。** 規約の側で本体の検査が増えて `bash scripts/harness/check-docs.sh --print checks` の名前が
  増えたら、`AGENTS.md` の検査のコマンドの表の文書の行と、`docs/QUALITY_SCORE.md` の目標「文書が実物と合っている」の
  測る項目の 2 つの括弧書きを、同じ変更で直す（直さないと `checks.d/check-list.sh` が失敗して知らせる）。追加の検査の名前は、
  本体の 13 個の後に、`checks.d/` のファイル名の `LC_ALL=C` の順で並ぶ。
- **このプロジェクトだけの試験を流して直す。** `update --apply` の後に `npm run test:harness` を流す。このプロジェクトだけの
  試験（`scripts/harness/harness-log-map.test.sh`・`scripts/harness/project-config.test.sh`）が、写しの文言や報告の形に依って
  落ちたら、その試験を直す（写しは直さない）。
- **追加の検査の決まりの差を見る。** `scripts/harness/checks.d/README.md`（写し）が置き換わったら、前の版との差を見て、
  このプロジェクトの 3 つの追加の検査（`check-list.sh`・`layer-ratings.sh`・`network-names.sh`）とその試験を、新しい決まりに合わせる。
- **フックの設定の期待値を直す。** 規約の側のフックの設定のひな形（`assets/claude-settings.json`・`assets/codex-hooks.json`）が
  変わって `.claude/settings.json`・`.codex/hooks.json` に取り込んだら、`scripts/harness/project-config.test.sh` の期待値も同じ変更で直す。

## 検討した代わりの案

- **置き換えの前の検査を残しつつ、写しも置く。** 同じ検査が 2 つになり、写しの中身の照合の対象が分かれる。中身を 1 つに
  するという写しの目的に反するので採らない。
- **`update` を使わず、手で写す。** 冒頭の `harness-copy` の行の版と中身の照合を人が作ることになり、誤りの余地が増えるので
  採らない。
- **置き換えの前の `check-docs.sh` を直して、設定を読ませる。** 規約の正本を正本にするという目的に届かないので採らない。
- **検査 12〜14 を規約の正本の本体へ移す。** 本体へ移すのは、2 つ以上のプロジェクトで同じ働きの検査が要るときに限る
  （`checks.d/README.md` の「本体へ移すとき」）。いまはこのプロジェクトだけなので、追加の検査の口に置く。

## 結果と限界

- 検査の本体の誤りの修正や検査の追加は、規約の側で直して `update` で置き換えると届く。このプロジェクトで写しを直すことは
  できない。直したいときは、規約の正本を直す。
- 置き換えの前の文書の検査 12 のうち、冒頭の「確かめること」の番号と検査の名前の一覧の数を照らす部分は移さなかった。
  写しの注釈の形に依って本体の中身を確かめるもので、このプロジェクトでは写しを直せないためである。
- 秘匿値の検査の写し（`check-secrets.sh`・`check-secrets.mjs`）には、道具の選び方と限界の理由を指す注釈が無い。その理由は
  [0002](0002-secret-scan-scope.md) にある。
- CI のひな形の差は、上の「更新のたびに行うこと」のとおり人が見るので、見落とすとひな形の直しが届かない。
- Claude Code と Codex のフックが確認なしに実行するスクリプトの範囲に、起動元の `scripts/harness/checks.d/*.sh` が入る。
  Claude Code のフックは、会話を始めた作業ツリー（`$CLAUDE_PROJECT_DIR`）の `notify.sh` を起動元にするので、別のブランチが
  書き換えた `checks.d/` のスクリプトがある worktree で会話を始めると、そのスクリプトが利用者の権限で実行される。Codex のフックは、
  本体の作業ツリーの `scripts/harness/` が HEAD と同じで、除外されていない未追跡のファイルも無いときだけ、本体の `notify.sh` を起動元にする
  （`.codex/hooks.json`）。
