#!/usr/bin/env bash
# バックアップから戻せるかの確認（デプロイ設計書 4章）
# 別のコンテナの PostgreSQL にダンプを戻し、利用者・猫・記録の件数と写真の数が、動いている DB と写真に合うかを確かめる
#   使い方：deploy/restore-check.sh [置き場所]（既定は BACKUP_DIR、なければ /var/backups/meowscope。いちばん新しい世代を使う）
#   バックアップの後に記録が増えると合わなくなるので、バックアップの直後に動かす
set -euo pipefail
export MSYS_NO_PATHCONV=1 # Git Bash（PC）でコンテナの中のパスを書き換えさせない

cd "$(dirname "$0")/.."
DIR=${1:-${BACKUP_DIR:-/var/backups/meowscope}}
NAME=meowscope-restore-check
DUMP=$(find "$DIR" -maxdepth 1 -name 'db-*.dump' | sort | tail -n 1)
STAMP=${DUMP##*/db-}
STAMP=${STAMP%.dump}
PHOTOS="$DIR/photos-$STAMP.tar.gz"
[ -n "$DUMP" ] && [ -f "$PHOTOS" ] || { echo "バックアップが見つかりません：$DIR" >&2; exit 1; }

trap 'docker rm -f "$NAME" > /dev/null 2>&1 || true' EXIT
docker rm -f "$NAME" > /dev/null 2>&1 || true
docker run -d --name "$NAME" -e POSTGRES_PASSWORD=restore-check -e POSTGRES_DB=meowscope postgres:18.6 > /dev/null
for _ in $(seq 60); do
  docker exec "$NAME" pg_isready -U postgres -d meowscope > /dev/null 2>&1 && break
  sleep 1
done
docker exec -i "$NAME" pg_restore -U postgres -d meowscope --no-owner --no-privileges < "$DUMP"

SQL="SELECT (SELECT count(*) FROM users) || ' ' || (SELECT count(*) FROM cats) || ' ' || (SELECT count(*) FROM records)"
restored=$(docker exec "$NAME" psql -U postgres -d meowscope -tAc "$SQL")
live=$(docker compose exec -T db psql -U "${DB_USER:-meowscope}" -d meowscope -tAc "$SQL")
photos_backup=$(tar tzf "$PHOTOS" | grep -cv '/$' || true)
photos_live=$(docker compose exec -T server find /data/photos -type f | wc -l)

echo "世代 $STAMP"
echo "利用者・猫・記録：戻したもの $restored ／ 動いているもの $live"
echo "写真：バックアップ $photos_backup ／ 動いているもの $photos_live"
if [ "$restored" = "$live" ] && [ "$photos_backup" -eq "$photos_live" ]; then
  echo "合っています"
else
  echo "合いません" >&2
  exit 1
fi
