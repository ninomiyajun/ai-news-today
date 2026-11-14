# ai-news-today

AI に関する今日のニュースを表示する Next.js のアプリ（手元の PC で本人だけが見る）。現在は土台だけで、機能は未実装。

## 使い方

```bash
npm ci
npm run dev     # http://127.0.0.1:3000
npm run check   # lint、型、試験、文書、依存の向き、秘匿値、開発環境の定義の検査（CI と同じ）
```

Docker の開発環境（`compose.yaml`、`compose.override.yaml`、`Dockerfile`）を使う場合:

```bash
docker compose up app               # 起動（http://127.0.0.1:3000）
docker compose down                 # 停止
docker compose run --rm app npm ci  # 依存の入れ直し
```

開発の決まり、設計、文書の置き場所は [AGENTS.md](AGENTS.md) と [ARCHITECTURE.md](ARCHITECTURE.md) にある。
