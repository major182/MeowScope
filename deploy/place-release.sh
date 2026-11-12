#!/usr/bin/env bash
# アプリの新しい版をサーバーのボリュームに置く（デプロイ設計書 6.4）。サーバーの動いている所（EC2・PC）で動かす
#   使い方：deploy/place-release.sh <android か windows> <release.json とファイルのあるフォルダー> [compose の -f の指定…]
#   例（EC2）：deploy/place-release.sh android /tmp/meowscope-release/android -f compose.yaml -f deploy/compose.aws.yaml
# ファイルを先に置き、版の情報を最後に置き換える（端末が新しい版の情報で古いファイルを取らないように）
set -euo pipefail

PLATFORM=${1:?使い方：deploy/place-release.sh <android か windows> <フォルダー> [compose の -f の指定…]}
SRC=${2:?release.json とファイルのあるフォルダーを指定してください}
shift 2
case $PLATFORM in
  android) FILE=meowscope.apk ;;
  windows) FILE=meowscope-setup.exe ;;
  *) echo "android か windows を指定してください" >&2; exit 1 ;;
esac
[[ -f $SRC/release.json && -f $SRC/$FILE ]] || { echo "$SRC に release.json と $FILE がありません" >&2; exit 1; }

cd "$(dirname "$0")/.."
compose() { docker compose "$@"; }
DEST=/data/releases/$PLATFORM

# いったん別名で置いてから名前を替える（置いている途中のファイルを配らない）
compose "$@" exec -T -u root server mkdir -p "$DEST"
compose "$@" cp "$SRC/$FILE" "server:$DEST/.$FILE.new"
compose "$@" cp "$SRC/release.json" "server:$DEST/.release.json.new"
compose "$@" exec -T -u root server sh -c "
  chmod 644 '$DEST/.$FILE.new' '$DEST/.release.json.new' &&
  mv -f '$DEST/.$FILE.new' '$DEST/$FILE' &&
  mv -f '$DEST/.release.json.new' '$DEST/release.json'"

# サーバーから見えるファイルが、版の情報の SHA-256 と同じかを確かめる
EXPECTED=$(sed -n 's/.*"sha256": *"\([0-9a-f]*\)".*/\1/p' "$SRC/release.json")
ACTUAL=$(compose "$@" exec -T server sha256sum "$DEST/$FILE" | cut -d' ' -f1)
if [[ $EXPECTED != "$ACTUAL" ]]; then
  echo "置いたファイルの SHA-256 が版の情報と違います" >&2
  exit 1
fi
echo "置きました：$(compose "$@" exec -T server cat "$DEST/release.json")"
