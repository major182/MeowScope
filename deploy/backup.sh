#!/usr/bin/env bash
# 毎日のバックアップ（デプロイ設計書 4章）。DB のダンプと写真を固め、新しいものから KEEP 世代を残す
#   AWS：cron から root で動かす。PC：タスクスケジューラーから Git Bash で、本番のフォルダー（.env の COMPOSE_FILE で本番を指す）にあるこのスクリプトを動かす
#   使い方：deploy/backup.sh [置き場所]（既定は BACKUP_DIR、なければ /var/backups/meowscope）
set -euo pipefail
export MSYS_NO_PATHCONV=1 # Git Bash（PC）でコンテナの中のパスを書き換えさせない

cd "$(dirname "$0")/.."
DIR=${1:-${BACKUP_DIR:-/var/backups/meowscope}}
KEEP=${KEEP:-7}
STAMP=$(date +%Y%m%d-%H%M%S)
mkdir -p "$DIR"

log() { echo "$(date '+%F %T') backup: $*"; }
trap 'log "失敗しました（終了コード $?）"' ERR

# DB：1つのファイル（-Fc）に。途中で失敗したら .part のまま残し、世代には数えない
docker compose exec -T db pg_dump -U "${DB_USER:-meowscope}" -d meowscope -Fc > "$DIR/db-$STAMP.dump.part"
mv "$DIR/db-$STAMP.dump.part" "$DIR/db-$STAMP.dump"

# 写真：サーバーのコンテナの中から固めて取り出す（ボリュームの名前に頼らない）
docker compose exec -T server tar czf - -C /data/photos . > "$DIR/photos-$STAMP.tar.gz.part"
mv "$DIR/photos-$STAMP.tar.gz.part" "$DIR/photos-$STAMP.tar.gz"

# 古い世代を消す
for prefix in db photos; do
  find "$DIR" -maxdepth 1 -name "$prefix-*" ! -name '*.part' -printf '%f\n' | sort -r | tail -n +$((KEEP + 1)) |
    while read -r old; do rm -f "$DIR/$old"; done
done
rm -f "$DIR"/*.part

photos=$(tar tzf "$DIR/photos-$STAMP.tar.gz" | grep -cv '/$' || true)
log "完了 $STAMP（DB $(wc -c < "$DIR/db-$STAMP.dump") バイト、写真 $photos 件、DB の世代 $(find "$DIR" -maxdepth 1 -name 'db-*.dump' | wc -l)）"
