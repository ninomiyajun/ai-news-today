# アプリの開発環境の定義（Docker）。部品 node-compose のひな形から作った。検査: bash scripts/harness/check-compose.sh
#
# - 土台は Debian 系（bookworm）の Node の公式のイメージで、版は .nvmrc に合わせ、ダイジェストで固定する。
# - 実行の利用者は node（UID 1000、GID 1000。土台のイメージが作る）。ENTRYPOINT は置かない。
# - build の context からファイルを読まない（context からの COPY、ADD、from の無い RUN --mount=type=bind を書かない）。
#   ソースは compose.override.yaml の bind か、エージェントの実行環境が重ねる作業場所から入る。
# - 先頭の syntax の指示は書かない（build の frontend に外部のイメージを使わせないため）。
FROM node:26.13.1-bookworm-slim@sha256:5df79989ed685e09f0a98019db4cebfb22fb9df1a53c0161664a011f7ff6b0f1 AS base

FROM base AS dev
# git は、検査のスクリプト（秘匿値の検査など）が使う。node_modules と .next は名前付き volume の置き場で、空の volume が
# 持ち主を受け継ぐように、node の持ち主で作る
RUN apt-get update \
 && apt-get install -y --no-install-recommends git \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /app/node_modules /app/.next \
 && chown -R node:node /app
USER node
WORKDIR /app
