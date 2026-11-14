#!/usr/bin/env bash
# harness-copy: source=home/agents/skills/project-harness-init/assets/parts/node-compose/assets/check-compose.test.sh
# harness-copy: version=rules-2026.11.13-1
# harness-copy: sha256=4e4c7a81f53f44a91b0615f73372caa79e503c0da1ffc60a09d52669e9d99174
# harness-copy: この 4 行と本体は手で変えない。正本を直して project-harness-init の「導入済みのプロジェクトの更新」で置き換える
# check-compose.sh の試験。Docker の CLI と daemon は使わない（node と node_modules の yaml だけを使う）。
#
#   bash scripts/harness/check-compose.test.sh
#
# 下の見本を 1 つずつ一時の根に描き、check-compose.sh --root <一時の根> を実行して確かめる。
#   - 悪い見本（bad）: すべて不合格（終了コード 1）になり、出力が見本の @@expect の正規表現（grep -E）に合う。
#   - 良い見本（good）: すべて合格（終了コード 0）になる。
#   - この根の定義（compose.yaml・compose.override.yaml・Dockerfile・.dockerignore の組）と、compose.yaml だけの定義
#     （エージェントの実行環境が使う形）が合格する。
# 見本の組（2 つ目の語）: stage0（設計の段階 0 の見本）、design（設計の 5.1 の見本）、dockerfile（Dockerfile の build の
# 入力の見本）、extra（読み取りの設定と、読み方の揺れを確かめる見本）、review（実装レビューの指摘から足した見本）、review2（第二レビューの指摘から足した見本）、
# project（この根の定義）。
# 見本の書き方: 「@@case <bad|good> <組> <名前>」で始め、「@@expect <正規表現>」（bad だけ）、「@@file <根からのファイル名>」
# の後にそのファイルの中身を書き、「@@end」で終える。Dockerfile を書かない見本には、下の既定の Dockerfile と .dockerignore を置く。
# 中身の <<CR>>・<<NEL>>・<<LS>>・<<PS>>・<<BOM>> は、それぞれ CR・U+0085・U+2028・U+2029・U+FEFF の文字に直して書く。
# 終了コード: 0 = すべて期待どおり / 1 = 期待と違う見本がある / 2 = 道具の不足
set -u

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
root="$(cd "$here/../.." && pwd -P)"
check="$here/check-compose.sh"
work="$(mktemp -d "${TMPDIR:-/tmp}/check-compose-test.XXXXXX")" || { echo "一時の置き場を作れません" >&2; exit 2; }
trap 'rm -rf "$work"' EXIT

pass=0; fail=0
ok() { echo "ok   $*"; pass=$((pass + 1)); }
ng() { echo "FAIL $*"; fail=$((fail + 1)); }

# 既定の Dockerfile（build の context から読まない、ダイジェストで固定した形）と .dockerignore
default_dockerfile() {
  cat <<'EOF'
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
RUN mkdir -p /app/node_modules /app/.next && chown -R node:node /app
USER node
WORKDIR /app
EOF
}

# 見本を $work/cases/<番号>/ に描く。meta に「種類<TAB>組<TAB>名前<TAB>期待」を書く
fixtures() {
  cat <<'FIXTURES'
@@case bad stage0 bind-home
@@expect volumes に bind
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    volumes:
      - /Users:/host-users:ro
@@end
@@case bad stage0 bind-long
@@expect volumes に bind
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    volumes:
      - type: bind
        source: /etc
        target: /host-etc
@@end
@@case bad stage0 bind-short
@@expect volumes に bind
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    volumes:
      - .:/app
@@end
@@case bad stage0 build-additional-contexts
@@expect build.additional_contexts は許可されていません
@@file compose.yaml
services:
  app:
    build:
      context: .
      additional_contexts:
        home: /Users
@@end
@@case bad stage0 build-args-passthrough
@@expect build.args は文字の値だけ
@@file compose.yaml
services:
  app:
    build:
      context: .
      args:
        - NPM_TOKEN
@@end
@@case bad stage0 build-context-abs
@@expect build.context は . だけ
@@file compose.yaml
services:
  app:
    build:
      context: /etc
@@end
@@case bad stage0 build-context-parent
@@expect build.context は . だけ
@@file compose.yaml
services:
  app:
    build:
      context: ..
@@end
@@case bad stage0 build-context-url
@@expect build.context は . だけ
@@file compose.yaml
services:
  app:
    build:
      context: https://github.com/example/repo.git
@@end
@@case bad stage0 build-dockerfile-abs
@@expect build.dockerfile は context の中の相対のパス
@@file compose.yaml
services:
  app:
    build:
      context: .
      dockerfile: /etc/Dockerfile
@@end
@@case bad stage0 build-dockerfile-parent
@@expect build.dockerfile は context の中の相対のパス
@@file compose.yaml
services:
  app:
    build:
      context: .
      dockerfile: ../Dockerfile
@@end
@@case bad stage0 build-secrets
@@expect secrets・configs は使えません
@@file compose.yaml
services:
  app:
    build:
      context: .
      secrets: [npmrc]
@@end
@@case bad stage0 build-ssh
@@expect build.ssh は許可されていません
@@file compose.yaml
services:
  app:
    build:
      context: .
      ssh: [default]
@@end
@@case bad stage0 cap-add-helper
@@expect サービス helper の cap_add は許可されていません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
  helper:
    image: busybox@sha256:1111111111111111111111111111111111111111111111111111111111111111
    cap_add: [NET_ADMIN]
@@end
@@case bad stage0 cap-add
@@expect cap_add は許可されていません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    cap_add: [SYS_ADMIN]
@@end
@@case bad stage0 cgroup-parent
@@expect cgroup_parent は許可されていません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    cgroup_parent: /
@@end
@@case bad stage0 configs
@@expect secrets・configs は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
configs:
  c:
    file: /etc/hosts
@@end
@@case bad stage0 devices
@@expect devices は許可されていません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    devices: ["/dev/fuse:/dev/fuse"]
@@end
@@case bad stage0 docker-sock
@@expect volumes に bind
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
@@end
@@case bad stage0 entrypoint
@@expect entrypoint は許可されていません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    entrypoint: ["/bin/sh", "-c", "id"]
@@end
@@case bad stage0 env-file-escaped-key
@@expect 逆斜線は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    "\x65nv_file": [/etc/hosts]
@@end
@@case bad stage0 env-file-helper
@@expect env_file は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
  helper:
    image: busybox@sha256:1111111111111111111111111111111111111111111111111111111111111111
    env_file: .env
@@end
@@case bad stage0 env-file
@@expect env_file は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    env_file: [/etc/hosts]
@@end
@@case bad stage0 env-interpolation-default
@@expect \$ による展開
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    volumes:
      - ${HOME:-/}:/host
@@end
@@case bad stage0 env-interpolation
@@expect \$ による展開
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    environment:
      TOKEN: ${GH_TOKEN}
@@end
@@case bad stage0 env-passthrough
@@expect environment に文字でない値
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    environment:
      - GH_TOKEN
@@end
@@case bad stage0 extends
@@expect extends は使えません
@@file compose.yaml
services:
  app:
    extends:
      file: /tmp/other.yaml
      service: base
@@end
@@case bad stage0 extra-hosts
@@expect extra_hosts は許可されていません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    extra_hosts: ["host.docker.internal:host-gateway"]
@@end
@@case bad stage0 image-no-digest
@@expect ダイジェスト
@@file compose.yaml
services:
  app:
    image: node:24-bookworm-slim
@@end
@@case bad stage0 include
@@expect include は使えません
@@file compose.yaml
include:
  - /etc/other-compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@end
@@case bad stage0 ipc-host
@@expect ipc は許可されていません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    ipc: host
@@end
@@case bad stage0 labels
@@expect labels は許可されていません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    labels: { a: b }
@@end
@@case bad stage0 network-external
@@expect network outside の external
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    networks: [outside]
networks:
  outside:
    external: true
@@end
@@case bad stage0 network-mode-host
@@expect network_mode は許可されていません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    network_mode: host
@@end
@@case bad stage0 pid-host
@@expect pid は許可されていません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    pid: host
@@end
@@case bad stage0 ports-all-interfaces
@@expect ports は 127.0.0.1 だけ
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    ports: ["3000:3000"]
@@end
@@case bad stage0 ports-any-ip
@@expect ports は 127.0.0.1 だけ
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    ports: ["0.0.0.0:3000:3000"]
@@end
@@case bad stage0 privileged
@@expect privileged は許可されていません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    privileged: true
@@end
@@case bad stage0 secrets
@@expect secrets・configs は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
secrets:
  key:
    file: /etc/ssh/ssh_host_rsa_key
@@end
@@case bad stage0 security-opt
@@expect security_opt は許可されていません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    security_opt: ["seccomp:unconfined"]
@@end
@@case bad stage0 sysctls
@@expect sysctls は許可されていません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    sysctls:
      net.ipv4.ip_unprivileged_port_start: "0"
@@end
@@case bad stage0 tmpfs
@@expect volumes に tmpfs
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    volumes:
      - type: tmpfs
        target: /scratch
@@end
@@case bad stage0 user-root
@@expect user に root
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    user: "0:0"
@@end
@@case bad stage0 userns-mode
@@expect userns_mode は許可されていません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    userns_mode: host
@@end
@@case bad stage0 volume-driver-opts
@@expect volume nm の driver
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    volumes: [nm:/app/node_modules]
volumes:
  nm:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /Users
@@end
@@case bad stage0 volume-external
@@expect volume nm の external
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    volumes: [nm:/app/node_modules]
volumes:
  nm:
    external: true
@@end
@@case bad stage0 volumes-from
@@expect volumes_from は許可されていません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    volumes_from: [other]
  other:
    image: busybox@sha256:1111111111111111111111111111111111111111111111111111111111111111
@@end
@@case bad stage0 x-extension
@@expect x- で始まる項目
@@file compose.yaml
x-common: &common
  init: true
services:
  app:
    <<: *common
    build: { context: ., target: dev }
@@end
@@case bad stage0 yaml-tag
@@expect 型の印
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    ports: !reset []
@@end
@@case good stage0 app-with-helper
@@file compose.yaml
# 通るべき見本: app と、ダイジェスト付きの補助のサービス
services:
  app:
    user: "1000:1000"
    build:
      context: .
      target: dev
    depends_on:
      db:
        condition: service_healthy
    ports:
      - "127.0.0.1:3000:3000"
    networks: [default]
  db:
    user: "1000:1000"
    image: postgres@sha256:0000000000000000000000000000000000000000000000000000000000000000
    environment:
      POSTGRES_PASSWORD: dev-only
    healthcheck:
      test: ["CMD", "pg_isready"]
      interval: 2s
      retries: 30
    volumes:
      - dbdata:/var/lib/postgresql/data
volumes:
  dbdata: {}
networks:
  default: {}
@@end
@@case good stage0 app
@@file compose.yaml
# 通るべき見本: L1 の app（bind の無い形）
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
      target: dev
      args:
        NODE_ENV: development
    working_dir: /app
    user: "1000:1000"
    command: ["sh", "-c", "npm ci && npm run dev -- -H 0.0.0.0 -p 3000"]
    environment:
      NEXT_TELEMETRY_DISABLED: "1"
    init: true
    ports:
      - "127.0.0.1:3000:3000"
    volumes:
      - node_modules:/app/node_modules
      - next:/app/.next
volumes:
  node_modules: {}
  next: {}
@@end
@@case bad design compose-app-bind
@@expect compose\.yaml: サービス app の volumes に bind
@@file compose.yaml
services:
  app:
    build:
      context: .
      target: dev
    working_dir: /app
    command: ["sh", "-c", "npm ci && npm run dev -- -H 0.0.0.0 -p 3000"]
    init: true
    ports:
      - "127.0.0.1:3000:3000"
    volumes:
      - .:/app
      - node_modules:/app/node_modules
      - next:/app/.next
volumes:
  node_modules: {}
  next: {}
@@end
@@case bad design override-other-bind
@@expect compose\.override\.yaml: サービス app の volumes は \.:/app の bind 1 つだけ
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file compose.override.yaml
services:
  app:
    volumes:
      - .:/app
      - /Users:/host-users
@@end
@@case bad design override-ports
@@expect compose\.override\.yaml: サービス app の ports は許可されていません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file compose.override.yaml
services:
  app:
    volumes:
      - .:/app
    ports:
      - "0.0.0.0:3000:3000"
@@end
@@case bad design build-dockerfile-name
@@expect build\.dockerfile は context の中の相対のパスの、直下の Dockerfile だけ
@@file compose.yaml
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile.dev
      target: dev
@@end
@@case bad design dockerignore-per-dockerfile
@@expect Dockerfile\.dockerignore: Dockerfile ごとの ignore ファイルは使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile.dockerignore
node_modules
@@end
@@case bad dockerfile copy-context
@@expect Dockerfile: 3 行目: build の context からの COPY は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
COPY . /app
USER node
@@end
@@case bad dockerfile add
@@expect Dockerfile: 3 行目: ADD は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
ADD https://example.com/tool.tar.gz /opt/
USER node
@@end
@@case bad dockerfile run-mount-bind
@@expect Dockerfile: 3 行目: from を付けない RUN --mount=type=bind は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
RUN --mount=type=bind,target=/x ls /x
USER node
@@end
@@case bad extra dockerfile-syntax
@@expect Dockerfile: 1 行目: 先頭の syntax の指示は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
# syntax=docker/dockerfile:1
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
USER node
@@end
@@case bad extra dockerfile-syntax-digest-upper
@@expect Dockerfile: 1 行目: 先頭の syntax の指示は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
#  SYNTAX = docker/dockerfile:1@sha256:2222222222222222222222222222222222222222222222222222222222222222
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
USER node
@@end
@@case bad extra dockerfile-escape
@@expect Dockerfile: 1 行目: escape の指示は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
# escape=`
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
USER node
@@end
@@case bad extra dockerfile-buildkit-syntax-arg
@@expect Dockerfile: BUILDKIT_SYNTAX は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
ARG BUILDKIT_SYNTAX=docker/dockerfile:1
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
USER node
@@end
@@case bad extra build-args-buildkit-syntax
@@expect build\.args の BUILDKIT_SYNTAX は使えません
@@file compose.yaml
services:
  app:
    build:
      context: .
      target: dev
      args:
        BUILDKIT_SYNTAX: docker/dockerfile:1
@@end
@@case bad extra build-args-buildkit-syntax-list
@@expect build\.args の BUILDKIT_SYNTAX は使えません
@@file compose.yaml
services:
  app:
    build:
      context: .
      target: dev
      args:
        - BUILDKIT_SYNTAX=docker/dockerfile:1
@@end
@@case bad extra dockerfile-copy-lowercase
@@expect Dockerfile: 3 行目: build の context からの COPY は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
from base as dev
copy --chown=node:node . /app
USER node
@@end
@@case bad extra dockerfile-copy-continuation
@@expect Dockerfile: 3 行目: build の context からの COPY は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
CoPy \
  # 継続の途中の注釈は命令の一部にならない
  --chown=node:node \
  . /app
USER node
@@end
@@case bad extra dockerfile-add-lowercase-continuation
@@expect Dockerfile: 3 行目: ADD は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
add \
  package.json /app/
USER node
@@end
@@case bad extra dockerfile-run-mount-default-type
@@expect from を付けない RUN --mount=type=bind は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
run --mount=target=/x,source=. ls /x
USER node
@@end
@@case bad extra dockerfile-run-mount-continuation
@@expect Dockerfile: 4 行目: from を付けない RUN --mount=type=bind は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
RUN --mount=type=cache,target=/root/.npm \
    --mount=type=bind,source=package.json,target=/tmp/package.json \
    cat /tmp/package.json
USER node
@@end
@@case bad extra dockerfile-onbuild-copy
@@expect ONBUILD: build の context からの COPY は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
ONBUILD COPY . /app
USER node
@@end
@@case bad extra dockerfile-entrypoint
@@expect ENTRYPOINT は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
USER node
ENTRYPOINT ["sh", "-c", "id"]
@@end
@@case bad extra dockerfile-from-no-digest
@@expect FROM の土台のイメージはダイジェスト
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24-bookworm-slim AS base
FROM base AS dev
USER node
@@end
@@case bad extra dockerfile-user-root
@@expect USER に root は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
USER root
@@end
@@case bad extra dockerfile-missing
@@expect Dockerfile: ありません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file .dockerignore
node_modules
@@end
@@case bad extra yaml-duplicate-key
@@expect DUPLICATE_KEY
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    init: true
    init: false
@@end
@@case bad extra yaml-anchor-alias
@@expect YAML の anchor（&b）は使えません
@@file compose.yaml
services:
  app:
    build: &b { context: ., target: dev }
  worker:
    build: *b
@@end
@@case bad extra yaml-merge-key
@@expect merge key（<<）は使えません
@@file compose.yaml
services:
  helper: &h
    image: busybox@sha256:1111111111111111111111111111111111111111111111111111111111111111
  app:
    <<: *h
    privileged: true
@@end
@@case bad extra yaml-std-tag
@@expect YAML の型の印（tag:yaml\.org,2002:bool）は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    init: !!bool true
@@end
@@case bad extra yaml-multi-doc
@@expect YAML の文書は 1 つだけにしてください
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
---
services:
  app:
    privileged: true
@@end
@@case bad extra yaml-unreadable
@@expect YAML として読めません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev
@@end
@@case bad extra yaml-tag-directive
@@expect YAML の指示（%YAML・%TAG）は使えません
@@file compose.yaml
%TAG !e! tag:example.com,2000:
---
services:
  app:
    build: { context: ., target: dev }
@@end
@@case bad extra yaml-nonstring-key
@@expect 項目の名前は文字だけにしてください
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    1: x
@@end
@@case bad extra compose-alt-name
@@expect docker-compose\.yml: ほかの名前の Compose の定義は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file docker-compose.yml
services:
  app:
    privileged: true
@@end
@@case bad extra compose-top-name
@@expect 最上位の name は許可されていません
@@file compose.yaml
name: other-project
services:
  app:
    build: { context: ., target: dev }
@@end
@@case bad extra volume-name
@@expect volume nm の name は許可されていません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    volumes: [nm:/app/node_modules]
volumes:
  nm:
    name: agent-claude-1
@@end
@@case bad extra network-name
@@expect network n の name は許可されていません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    networks: [n]
networks:
  n:
    name: agent-net-1
@@end
@@case bad extra build-dockerfile-inline
@@expect build\.dockerfile_inline は許可されていません
@@file compose.yaml
services:
  app:
    build:
      context: .
      dockerfile_inline: "FROM busybox"
@@end
@@case bad extra build-string-context
@@expect build\.context は \. だけです
@@file compose.yaml
services:
  app:
    build: ..
@@end
@@case bad extra bind-long-relative
@@expect volumes に bind があります
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    volumes:
      - type: bind
        source: .
        target: /app
@@end
@@case bad extra anonymous-volume
@@expect 名前の無い volume は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    volumes:
      - /app/cache
@@end
@@case bad extra ports-number
@@expect ports は 127\.0\.0\.1 だけです
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    ports: [3000]
@@end
@@case bad extra override-other-service
@@expect compose\.override\.yaml: サービス db は書けません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file compose.override.yaml
services:
  app:
    volumes:
      - .:/app
  db:
    image: postgres@sha256:0000000000000000000000000000000000000000000000000000000000000000
@@end
@@case good extra dockerfile-allowed-forms
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    user: "1000:1000"
@@file Dockerfile
# 通るべき見本: --from を付けた COPY、from を付けた bind、cache の mount、行の継続と小文字の命令
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS tools
run mkdir -p /opt/tools
FROM base AS dev
COPY --from=tools /opt/tools /opt/tools
RUN --mount=type=cache,target=/root/.npm \
    --mount=type=bind,from=tools,source=/opt/tools,target=/mnt/tools \
    ls /mnt/tools
USER node
WORKDIR /app
@@end
@@case bad review yaml-cr-comment
@@expect compose\.yaml: CR（復帰
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    working_dir: /app # note<<CR>>    privileged: true<<CR>>    volumes:<<CR>>      - /:/host
@@end
@@case bad review yaml-crlf
@@expect compose\.yaml: CR（復帰
@@file compose.yaml
services:<<CR>>
  app:<<CR>>
    build: { context: ., target: dev }<<CR>>
@@end
@@case bad review yaml-cr-override
@@expect compose\.override\.yaml: CR（復帰
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file compose.override.yaml
services:
  app:
    volumes: # x<<CR>>      - ~/.ssh:/ssh<<CR>>      - /:/host
      - .:/app
@@end
@@case bad review yaml-nel-comment
@@expect compose\.yaml: U\+0085
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    working_dir: /app # note<<NEL>>    privileged: true
@@end
@@case bad review yaml-ls-comment
@@expect compose\.yaml: U\+2028
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    working_dir: /app # note<<LS>>    privileged: true
@@end
@@case bad review yaml-ps-comment
@@expect compose\.yaml: U\+2028・U\+2029
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    working_dir: /app # note<<PS>>    privileged: true
@@end
@@case bad review yaml-bom
@@expect compose\.yaml: U\+FEFF
@@file compose.yaml
<<BOM>>services:
  app:
    build: { context: ., target: dev }
@@end
@@case bad review dockerfile-crlf
@@expect Dockerfile: CR（復帰
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
USER node<<CR>>
@@end
@@case bad review split-add
@@expect Dockerfile: 3 行目: ADD は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
AD\
D https://example.com/x /x
USER node
@@end
@@case bad review split-copy
@@expect Dockerfile: 3 行目: build の context からの COPY は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
CO\
PY . /app
USER node
@@end
@@case bad review split-entrypoint
@@expect Dockerfile: 3 行目: ENTRYPOINT は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
ENTRY\
POINT ["id"]
USER node
@@end
@@case bad review split-from
@@expect Dockerfile: 1 行目: FROM の土台のイメージはダイジェスト（@sha256:…）付きにしてください（node:latest）
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FR\
OM node:latest AS base
FROM base AS dev
USER node
@@end
@@case bad review split-mount
@@expect Dockerfile: 3 行目: from を付けない RUN --mount=type=bind は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
RUN --mo\
unt=type=bind,target=/x ls /x
USER node
@@end
@@case bad review split-user
@@expect Dockerfile: 4 行目: USER に root は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
USER node
USER r\
oot
@@end
@@case bad review continuation-no-space
@@expect Dockerfile: 3 行目: 行の継続の逆斜線の直前は空白にしてください
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
RUN echo a\
  b
USER node
@@end
@@case bad review case-override-yml
@@expect Compose\.Override\.yml: ほかの名前の Compose の定義は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Compose.Override.yml
services:
  app:
    privileged: true
@@end
@@case bad review case-docker-compose
@@expect Docker-Compose\.YAML: ほかの名前の Compose の定義は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Docker-Compose.YAML
services: {}
@@end
@@case bad review case-compose-yaml
@@expect Compose\.yaml: 名前の大文字・小文字が違います
@@file Compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@end
@@case bad review case-dockerfile
@@expect DockerFile: 名前の大文字・小文字が違います
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file DockerFile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
USER node
@@file .dockerignore
node_modules
@@end
@@case bad review case-per-dockerfile-ignore
@@expect Dockerfile\.DockerIgnore: Dockerfile ごとの ignore ファイルは使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile.DockerIgnore
node_modules
@@end
@@case bad review env-compose-file
@@expect \.env: 2 行目: COMPOSE_・DOCKER_ で始まる変数は書けません（COMPOSE_FILE
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file .env
PORT=3000
COMPOSE_FILE=compose.yaml:evil.yaml
@@end
@@case bad review env-export-docker-host
@@expect \.env: 1 行目: COMPOSE_・DOCKER_ で始まる変数は書けません（DOCKER_HOST
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file .env
export DOCKER_HOST=tcp://example.com:2375
@@end
@@case bad review env-compose-lowercase
@@expect \.env: 1 行目: COMPOSE_・DOCKER_ で始まる変数は書けません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file .env
  compose_profiles=evil
@@end
@@case bad review env-cr
@@expect \.env: CR（復帰
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file .env
PORT=3000<<CR>>COMPOSE_FILE=evil.yaml
@@end
@@case bad review from-var
@@expect Dockerfile: 2 行目: FROM に \$ は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
ARG B=node:24@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9
FROM $B AS base
FROM base AS dev
USER node
@@end
@@case bad review user-var
@@expect Dockerfile: 4 行目: USER に \$ は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
ARG U=node
USER $U
@@end
@@case bad review copy-flag-var
@@expect Dockerfile: 4 行目: COPY の設定に \$ と逆斜線は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
ARG O=root
COPY --from=base --chown=$O /etc/hostname /x
USER node
@@end
@@case bad review mount-var
@@expect Dockerfile: 4 行目: --mount の設定に \$・引用符・逆斜線は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
ARG T=bind
RUN --mount=type=$T,target=/x ls /x
USER node
@@end
@@case bad review copy-from-var
@@expect Dockerfile: 4 行目: COPY の設定に \$
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
ARG E=base
COPY --from=$E /etc/hostname /x
USER node
@@end
@@case bad review copy-from-empty-quoted
@@expect Dockerfile: 3 行目: COPY の --from は、値が空です
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
COPY --from="" . /app
USER node
@@end
@@case bad review copy-from-empty
@@expect Dockerfile: 3 行目: COPY の --from は、値が空です
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
COPY --from= . /app
USER node
@@end
@@case bad review copy-from-no-value
@@expect Dockerfile: 3 行目: build の context からの COPY は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
COPY --from . /app
USER node
@@end
@@case bad review copy-dashdash
@@expect Dockerfile: 3 行目: build の context からの COPY は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
COPY -- --from=base . /app
USER node
@@end
@@case bad review copy-from-external
@@expect Dockerfile: 3 行目: COPY の --from は、それより前の段の名前か、ダイジェスト
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
COPY --from=alpine:latest /etc/hostname /x
USER node
@@end
@@case bad review copy-from-later-stage
@@expect Dockerfile: 3 行目: COPY の --from は、それより前の段の名前か
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
COPY --from=later /x /x
USER node
FROM base AS later
USER node
@@end
@@case bad review copy-from-self
@@expect Dockerfile: 3 行目: COPY の --from は、それより前の段の名前か
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
COPY --from=dev /x /y
USER node
@@end
@@case bad review mount-from-external
@@expect Dockerfile: 3 行目: --mount の from は、それより前の段の名前か
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
RUN --mount=type=bind,from=alpine:latest,target=/x ls /x
USER node
@@end
@@case bad review mount-from-empty-quoted
@@expect Dockerfile: 3 行目: --mount の設定に \$・引用符・逆斜線は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
RUN --mount=type=bind,target=/x,from="" ls /x
USER node
@@end
@@case bad review mount-from-empty
@@expect Dockerfile: 3 行目: from を付けない RUN --mount=type=bind は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
RUN --mount=type=bind,target=/x,from= ls /x
USER node
@@end
@@case bad review mount-cache-from-external
@@expect Dockerfile: 3 行目: --mount の from は、それより前の段の名前か
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
RUN --mount=type=cache,from=alpine:latest,target=/x ls /x
USER node
@@end
@@case bad review user-00
@@expect Dockerfile: 3 行目: USER に root は使えません（00
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
USER 00
@@end
@@case bad review user-plus0
@@expect Dockerfile: 3 行目: USER に 名前か番号
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
USER +0
@@end
@@case bad review user-minus0
@@expect Dockerfile: 3 行目: USER に 名前か番号
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
USER -0
@@end
@@case bad review user-quoted-root
@@expect Dockerfile: 3 行目: USER に 名前か番号
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
USER "root"
@@end
@@case bad review user-group0
@@expect Dockerfile: 3 行目: USER に グループに root（0）は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
USER node:0
@@end
@@case bad review user-group-root
@@expect Dockerfile: 3 行目: USER に グループに root（0）は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
USER 1000:root
@@end
@@case bad review c-user-00
@@expect サービス app の user に root は使えません.*00
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    user: "00"
@@end
@@case bad review c-user-plus0
@@expect サービス app の user に root は使えません.*\+0
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    user: "+0"
@@end
@@case bad review c-user-minus0
@@expect サービス app の user に root は使えません.*-0
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    user: "-0"
@@end
@@case bad review c-user-group0
@@expect サービス app の user に root は使えません.*グループに root
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    user: "1000:0"
@@end
@@case bad review final-user-missing
@@expect Dockerfile: build\.target の段 dev（2 行目の FROM から）の最後の利用者が root です
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
RUN true
@@end
@@case bad review final-user-root-after-node
@@expect 最後の利用者が root です
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
USER node
USER root
@@end
@@case bad review final-user-last-stage
@@expect Dockerfile: 最後の段（4 行目の FROM から）の最後の利用者が root です
@@file compose.yaml
services:
  app:
    build: .
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
USER node
FROM base AS dev
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS other
@@end
@@case bad review target-missing
@@expect Dockerfile: build\.target の段 prod がありません
@@file compose.yaml
services:
  app:
    build: { context: ., target: prod }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
USER node
@@end
@@case bad review final-user-var
@@expect 最後の利用者が root です
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
ARG U=node
USER $U
@@end
@@case bad review inst-shell
@@expect Dockerfile: 3 行目: SHELL は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
SHELL ["/bin/bash", "-c"]
USER node
@@end
@@case bad review inst-onbuild-run
@@expect Dockerfile: 3 行目: ONBUILD は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
ONBUILD RUN id
USER node
@@end
@@case bad review inst-volume
@@expect Dockerfile: 3 行目: VOLUME は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
VOLUME /data
USER node
@@end
@@case bad review inst-healthcheck
@@expect Dockerfile: 3 行目: HEALTHCHECK は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
HEALTHCHECK CMD true
USER node
@@end
@@case bad review inst-cmd
@@expect Dockerfile: 4 行目: CMD は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
USER node
CMD ["id"]
@@end
@@case bad review inst-stopsignal
@@expect Dockerfile: 3 行目: STOPSIGNAL は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
STOPSIGNAL SIGKILL
USER node
@@end
@@case bad review inst-unknown
@@expect Dockerfile: 3 行目: 命令 FOO は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
FOO bar
USER node
@@end
@@case bad review inst-lowercase-shell
@@expect Dockerfile: 3 行目: SHELL は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
shell ["/bin/sh", "-c"]
USER node
@@end
@@case bad review inst-before-from
@@expect Dockerfile: 1 行目: 最初の FROM の前に書けるのは ARG だけです
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
RUN id
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
USER node
@@end
@@case bad review env-path
@@expect Dockerfile: 3 行目: ENV の PATH は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
ENV PATH=/tmp/evil:/usr/bin
USER node
@@end
@@case bad review env-path-legacy
@@expect Dockerfile: 3 行目: ENV の PATH は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
ENV PATH /tmp/evil
USER node
@@end
@@case bad review env-ld-preload
@@expect Dockerfile: 3 行目: ENV の LD_PRELOAD は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
ENV A=1 LD_PRELOAD=/x.so
USER node
@@end
@@case bad review env-node-options
@@expect Dockerfile: 3 行目: ENV の NODE_OPTIONS は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
ENV NODE_OPTIONS=--require=/x.js
USER node
@@end
@@case bad review env-bash-env
@@expect Dockerfile: 3 行目: ENV の BASH_ENV は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
ENV BASH_ENV=/x.sh
USER node
@@end
@@case bad review env-env
@@expect Dockerfile: 3 行目: ENV の ENV は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
ENV ENV=/x.sh
USER node
@@end
@@case bad review env-npm-config
@@expect Dockerfile: 3 行目: ENV の npm_config_script_shell は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
ENV npm_config_script_shell=/x.sh
USER node
@@end
@@case bad review env-quoted-name
@@expect Dockerfile: 3 行目: ENV の PATH は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
ENV "PATH"=/tmp/evil
USER node
@@end
@@case bad review env-var
@@expect Dockerfile: 3 行目: ENV に \$ は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
ENV P=$PATH
USER node
@@end
@@case bad review run-network
@@expect Dockerfile: 3 行目: RUN の設定 --network は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
RUN --network=host id
USER node
@@end
@@case bad review run-security
@@expect Dockerfile: 3 行目: RUN の設定 --security は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
RUN --security=insecure id
USER node
@@end
@@case bad review run-heredoc
@@expect Dockerfile: 3 行目: RUN のヒアドキュメント
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
RUN <<EOF
id
EOF
USER node
@@end
@@case bad review copy-heredoc
@@expect Dockerfile: 3 行目: COPY のヒアドキュメント
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
COPY --from=base <<EOF /x
USER root
EOF
USER node
@@end
@@case bad review c-windrive
@@expect サービス app の volumes に bind があります（Windows のドライブの形
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    volumes:
      - c:/Users:ro
volumes:
  c: {}
@@end
@@case bad review c-windrive-upper
@@expect サービス app の volumes に bind があります（Windows のドライブの形
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    volumes:
      - C:/x
volumes:
  C: {}
@@end
@@case bad review c-volume-one-letter
@@expect volume の名前 d は 1 文字にできません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    volumes:
      - type: volume
        source: d
        target: /x
volumes:
  d: {}
@@end
@@case bad review escape-upper
@@expect Dockerfile: 1 行目: escape の指示は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
# ESCAPE=`
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
USER node
@@end
@@case bad review escape-nospace
@@expect Dockerfile: 1 行目: escape の指示は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
#escape=`
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
USER node
@@end
@@case bad review escape-spaces
@@expect Dockerfile: 1 行目: escape の指示は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
#   escape   =   `
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
USER node
@@end
@@case bad review escape-tab
@@expect Dockerfile: 1 行目: escape の指示は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
#	Escape	=	`
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
USER node
@@end
@@case bad review escape-indented
@@expect Dockerfile: 1 行目: escape の指示は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
   # escape=`
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
USER node
@@end
@@case bad review escape-after-comment
@@expect Dockerfile: 2 行目: escape の指示は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
# 注釈
# escape=`
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
USER node
@@end
@@case bad review escape-after-blank
@@expect Dockerfile: 2 行目: escape の指示は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile

# escape=`
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
USER node
@@end
@@case bad review escape-after-syntax
@@expect Dockerfile: 2 行目: escape の指示は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
# check=skip=all
# escape=`
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
USER node
@@end
@@case bad review escape-backslash
@@expect Dockerfile: 1 行目: escape の指示は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
# escape=\
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
USER node
@@end
@@case good review inherit-user-from-stage
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    user: "1000:1000"
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
USER node
FROM base AS dev
RUN true
@@end
@@case good review copy-from-digest
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    user: "1000:1000"
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
COPY --from=alpine:3@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 /etc/hostname /tmp/hostname
COPY --from=0 --chown=node:node /etc/hostname /tmp/h2
USER node
@@end
@@case good review env-label-expose
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    user: "1000:1000"
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
ENV NEXT_TELEMETRY_DISABLED=1 TZ=UTC
LABEL org.example.note="dev"
EXPOSE 3000
ARG NODE_ENV=development
USER 1000:1000
@@end
@@case good review continuation-with-space
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    user: "1000:1000"
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
RUN true \
  # 継続の途中の注釈

  && true
USER node
@@end
@@case good review dotenv-plain
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    user: "1000:1000"
@@file .env
PORT=3000
NEXT_PUBLIC_X=1
# COMPOSE_FILE は注釈の中
@@end
@@case good review user-non-root-forms
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    user: "1000:1000"
@@end
@@case bad review2 flag-quoted-fake-from
@@expect Dockerfile: 3 行目: COPY の設定に引用符は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    user: "1000:1000"
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
COPY --exclude=" --from=base " . /app
USER node
@@end
@@case bad review2 flag-single-quote
@@expect Dockerfile: 3 行目: COPY の設定に引用符は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    user: "1000:1000"
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
COPY --from=base --chown='node' /etc/hostname /x
USER node
@@end
@@case bad review2 flag-quoted-mount
@@expect Dockerfile: 3 行目: RUN の設定に引用符は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    user: "1000:1000"
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
RUN --mount="type=cache,target=/x" true
USER node
@@end
@@case bad review2 flag-quoted-platform
@@expect Dockerfile: 1 行目: FROM の設定に引用符は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    user: "1000:1000"
@@file Dockerfile
FROM --platform="linux/amd64" node:24@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
USER node
@@end
@@case bad review2 env-second-assign
@@expect \.env: 1 行目: \.env は 1 行に 1 つの「名前=値」だけ
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    user: "1000:1000"
@@file .env
X='' COMPOSE_FILE=evil.yaml
@@end
@@case bad review2 env-second-assign-unquoted
@@expect \.env: 1 行目: \.env は 1 行に 1 つの「名前=値」だけ
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    user: "1000:1000"
@@file .env
X=a COMPOSE_FILE=evil.yaml
@@end
@@case bad review2 env-quote-newline
@@expect \.env: 1 行目: \.env は 1 行に 1 つの「名前=値」だけ
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    user: "1000:1000"
@@file .env
X="a
COMPOSE_FILE=evil.yaml"
@@end
@@case bad review2 env-after-close-quote
@@expect \.env: 1 行目: \.env は 1 行に 1 つの「名前=値」だけ
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    user: "1000:1000"
@@file .env
X="a"COMPOSE_FILE=evil.yaml
@@end
@@case bad review2 env-no-equals
@@expect \.env: 1 行目: \.env は 1 行に 1 つの「名前=値」だけ
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    user: "1000:1000"
@@file .env
COMPOSE_FILE
@@end
@@case bad review2 target-mixed-last-root
@@expect Dockerfile: 最後の段（4 行目の FROM から）の最後の利用者が root です
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    user: "1000:1000"
  helper:
    build: .
    user: "1000:1000"
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
USER node
FROM base AS rootfinal
@@end
@@case bad review2 target-empty-last-root
@@expect Dockerfile: 最後の段（4 行目の FROM から）の最後の利用者が root です
@@file compose.yaml
services:
  app:
    build: { context: ., target: "" }
    user: "1000:1000"
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
USER node
FROM base AS rootfinal
@@end
@@case bad review2 user-missing-image-service
@@expect compose\.yaml: サービス db に user がありません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    user: "1000:1000"
  db:
    image: postgres:16@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9
@@end
@@case bad review2 user-missing-app
@@expect compose\.yaml: サービス app に user がありません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@end
@@case bad review2 user-name-form
@@expect サービス app の user に root は使えません.*数値の UID:GID の形ではありません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    user: node
@@end
@@case bad review2 user-uid-only
@@expect サービス app の user に root は使えません.*数値の UID:GID の形ではありません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    user: "1000"
@@end
@@case bad review2 user-number-type
@@expect サービス app の user に root は使えません.*文字だけにしてください
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    user: 1000
@@end
@@case bad review2 user-uid0-numeric
@@expect サービス app の user に root は使えません.*UID が 0 です
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    user: "000:1000"
@@end
@@case bad review2 passwd-edit-no-user
@@expect compose\.yaml: サービス app に user がありません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
RUN sed -i 's/^node:x:1000:1000:/node:x:0:0:/' /etc/passwd
USER node
@@end
@@case bad review2 override-user
@@expect compose\.override\.yaml: サービス app の user は許可されていません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    user: "1000:1000"
@@file compose.override.yaml
services:
  app:
    user: "0:0"
    volumes:
      - .:/app
@@end
@@case bad review2 override-adds-service
@@expect compose\.override\.yaml: サービス extra は書けません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    user: "1000:1000"
@@file compose.override.yaml
services:
  app:
    volumes:
      - .:/app
  extra:
    image: alpine@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9
@@end
@@case good review2 passwd-edit-numeric-user
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    user: "1000:1000"
@@file Dockerfile
FROM node:24.22.2-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 AS base
FROM base AS dev
RUN sed -i 's/^node:x:1000:1000:/node:x:0:0:/' /etc/passwd
USER node
@@end
@@case good review2 helper-with-user
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    user: "1000:1000"
  db:
    image: postgres:16@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9
    user: "999:999"
@@end
@@case good review2 dotenv-forms
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    user: "1000:1000"
@@file .env
A=1
export B=two
C='x y'  # 注釈
D="q r"
E=

# 注釈
@@end
@@case bad review2 env-single-quote-backslash
@@expect \.env: 1 行目: \.env に逆斜線は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    user: "1000:1000"
@@file .env
A='\'
B=' COMPOSE_FILE=evil.yaml #'
C=ok
@@end
@@case bad review2 env-double-quote-backslash
@@expect \.env: 1 行目: \.env に逆斜線は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    user: "1000:1000"
@@file .env
X="a\"
COMPOSE_FILE=evil.yaml"
@@end
@@case bad review2 env-unquoted-backslash
@@expect \.env: 1 行目: \.env に逆斜線は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    user: "1000:1000"
@@file .env
X=a\
@@end
@@case bad review2 env-comment-backslash
@@expect \.env: 1 行目: \.env に逆斜線は使えません
@@file compose.yaml
services:
  app:
    build: { context: ., target: dev }
    user: "1000:1000"
@@file .env
# 注釈\
A=1
@@end
FIXTURES
}

mkdir "$work/cases"
fixtures | awk -v dir="$work/cases" '
  function close_file() { if (out != "") { close(out); out = "" } }
  /^@@case / { close_file(); n++; d = sprintf("%s/%03d", dir, n); system("mkdir -p \"" d "/root\""); kind = $2; group = $3; name = $4; expect = ""; next }
  /^@@expect / { expect = substr($0, 10); next }
  /^@@file / { close_file(); out = d "/root/" substr($0, 8); next }
  /^@@end$/ { close_file(); printf "%s\t%s\t%s\t%s\n", kind, group, name, expect > (d "/meta"); close(d "/meta"); next }
  # 見えない文字の印を、その文字に直して書く
  {
    if (out == "") next
    line = $0
    gsub(/<<CR>>/, "\r", line); gsub(/<<NEL>>/, "\302\205", line); gsub(/<<LS>>/, "\342\200\250", line)
    gsub(/<<PS>>/, "\342\200\251", line); gsub(/<<BOM>>/, "\357\273\277", line)
    print line > out
  }
'

run_case() { # <根> → 終了コードを返し、出力を $work/out に書く
  local rc=0
  bash "$check" --root "$1" > "$work/out" 2>&1 || rc=$?
  return "$rc"
}

echo "== 見本"
counts=""
for d in "$work"/cases/*/; do
  d="${d%/}"
  IFS="$(printf '\t')" read -r kind group name expect < "$d/meta"
  if [ ! -e "$d/root/Dockerfile" ] && [ ! -e "$d/root/.dockerignore" ]; then
    default_dockerfile > "$d/root/Dockerfile"
    printf 'node_modules\n.next\n.git\n.env*\n' > "$d/root/.dockerignore"
  fi
  counts="$counts$kind:$group"$'\n'
  rc=0; run_case "$d/root" || rc=$?
  if [ "$kind" = bad ]; then
    if [ "$rc" -ne 1 ]; then
      ng "bad/$group/$name: 終了コードが ${rc}（不合格の 1 を期待）: $(tr '\n' ' ' < "$work/out")"
    elif [ -z "$expect" ] || ! grep -qE -- "$expect" "$work/out"; then
      ng "bad/$group/$name: 不合格だが、理由が期待（${expect}）と違う: $(tr '\n' ' ' < "$work/out")"
    else
      ok "bad/$group/$name → $(grep -m1 -E -- "$expect" "$work/out" | sed 's/^check-compose: 不合格: //')"
    fi
  else
    if [ "$rc" -eq 0 ]; then ok "good/$group/$name"; else ng "good/$group/$name: 終了コード ${rc}: $(tr '\n' ' ' < "$work/out")"; fi
  fi
done

echo "== この根の定義"
proj_case() { # <名前> <ファイル…>: この根のファイルを一時の根へ写して確かめる
  local name="$1" f d="$work/project-$1" missing=""
  shift
  mkdir -p "$d"
  for f in "$@"; do
    if [ -f "$root/$f" ] && [ ! -L "$root/$f" ]; then cp "$root/$f" "$d/$f"; else missing="$missing $f"; fi
  done
  counts="${counts}good:project"$'\n'
  if [ -n "$missing" ]; then ng "good/project/$name: この根に通常のファイルとして無いもの:$missing"; return; fi
  if run_case "$d"; then ok "good/project/${name}（${*}）"; else ng "good/project/$name: $(tr '\n' ' ' < "$work/out")"; fi
}
proj_case pair compose.yaml compose.override.yaml Dockerfile .dockerignore
proj_case compose-only compose.yaml Dockerfile .dockerignore

echo "件数: $(printf '%s' "$counts" | awk -F ':' 'NF { c[$1 "/" $2]++ } END { for (k in c) print k "=" c[k] }' | sort | tr '\n' ' ')"
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
