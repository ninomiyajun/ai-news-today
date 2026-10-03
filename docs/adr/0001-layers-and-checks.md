# 0001 層の構成と、依存の向き・秘匿値の検査の道具

## 背景

ハーネスの導入の最初の段階（P1）で、層の依存の向きと秘匿値の混入を、CI と手元の両方で機械的に止める必要があった。
リポジトリは公開で、グローバルなインストールを要する道具は避けたい。

## 判断

- 層は `src/` の直下の 8 つ（app、ui、composition、services、sources、curation、ports、domain）とする。向きは
  `ARCHITECTURE.md` の表のとおり。外部への通信と現在時刻は `src/ports/` に集め、試験で差し替えられるようにする。
- 依存の向きの検査は dependency-cruiser（npm の開発用の依存）で行う。型だけの import も数える設定にする。
- 現在時刻と `fetch` の直接の使用は、ESLint の組み込みの規則（`no-restricted-globals` など）で拒否する。
- 秘匿値の検査は secretlint（npm の開発用の依存。推奨の規則の一式に、Claude Code の長期のトークンの形を足す）で、
  `git ls-files --cached --others --exclude-standard` が返す全ファイルに掛ける。手元と CI で同じコマンド
  （`npm run check:secrets`）を使う。
- 試験は Vitest で行う。

## 検討した代わりの案

- gitleaks: 履歴も調べられるが、手元で使うには単体の実行ファイルのインストールが要る。GitHub Actions のアクションも
  あるが、手元と CI で別の道具になる。履歴の検査が要るようになったら、CI に追加することを検討する。
- ESLint の `import/no-restricted-paths` での層の検査: 型だけの import や循環の検出は dependency-cruiser の方が
  直接書ける。

## 結果

- `npm ci` だけで、手元と CI が同じ版の道具で検査できる。
- secretlint はファイルの現在の中身だけを調べる。過去のコミットに入って後で消された秘匿値は検出しない。
  （この限界と一覧の取り方の穴は、[0002](0002-secret-scan-scope.md) でコミットの中身の検査を足して改めた。）
- 検出できる秘匿値の形は、規則にある形に限られる。
