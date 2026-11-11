#!/usr/bin/env bash
# サーバーの更新（デプロイ設計書 5.3）。EC2 でセッションマネージャーから root で動かす
#   使い方：deploy/update.sh <コミットの SHA>（server-image のワークフローで作ったイメージのタグ）
# リポジトリ（compose の定義とスクリプト）を最新にし、.env のイメージのタグを替えて起動し直す。DB の構造は Flyway が反映する
set -euo pipefail

TAG=${1:?使い方：deploy/update.sh <コミットの SHA>}
[[ $TAG =~ ^[0-9a-f]{40}$ ]] || { echo "コミットの SHA（40 文字）を指定してください" >&2; exit 1; }

cd "$(dirname "$0")/.."
git pull --ff-only
sed -i "s/^SERVER_IMAGE_TAG=.*/SERVER_IMAGE_TAG=$TAG/" .env
docker compose -f compose.yaml -f deploy/compose.aws.yaml pull server
docker compose -f compose.yaml -f deploy/compose.aws.yaml up -d
docker compose -f compose.yaml -f deploy/compose.aws.yaml ps
