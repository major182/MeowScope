#!/usr/bin/env bash
# アプリの新しい版を作り、サーバーに置く（デプロイ設計書 6.4）。手元の PC の Git Bash でリポジトリの直下から動かす
#   使い方：deploy/publish-release.sh <android か windows> <aws か pc>
#   - 先に app/pubspec.yaml の version を上げる（ビルド番号は必ず1つ上げる。BR-34）
#   - aws：terraform output からサーバーの URL・中継の S3 バケット・EC2 を読み、S3 → セッションマネージャーで EC2 に置く
#   - pc ：環境変数 API_BASE_URL（PC のサーバーの URL）を渡す。手元の Docker のボリュームに置く
#   - 問い合わせ先は環境変数 CONTACT_EMAIL で渡す（リポジトリには書かない）
# バケットの名前や EC2 の ID は画面に出さない（公開リポジトリの Actions などに貼らないため）
set -euo pipefail
export MSYS_NO_PATHCONV=1

PLATFORM=${1:?使い方：deploy/publish-release.sh <android か windows> <aws か pc>}
TARGET=${2:?aws か pc を指定してください}
case $PLATFORM in
  android) FILE=meowscope.apk ;;
  windows) FILE=meowscope-setup.exe ;;
  *) echo "android か windows を指定してください" >&2; exit 1 ;;
esac
[[ $TARGET == aws || $TARGET == pc ]] || { echo "aws か pc を指定してください" >&2; exit 1; }

# Windows の Git Bash では、Windows のプログラム（terraform など）に渡せる C:/... 形式にする
ROOT=$(cd "$(dirname "$0")/.." && (pwd -W 2>/dev/null || pwd))
tf() { terraform -chdir="$ROOT/deploy/terraform" "$@"; }

# 版の番号（例：1.0.1+3）。ビルド番号が数字でなければ止める
FULL=$(sed -n 's/^version: *\([^ ]*\).*/\1/p' "$ROOT/app/pubspec.yaml")
VERSION=${FULL%+*}
BUILD=${FULL#*+}
[[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && $BUILD =~ ^[0-9]+$ ]] \
  || { echo "pubspec.yaml の version は 1.0.1+3 の形にしてください" >&2; exit 1; }

if [[ $TARGET == aws ]]; then
  API_BASE_URL=$(tf output -raw api_base_url)
else
  : "${API_BASE_URL:?pc のときは API_BASE_URL を渡してください}"
fi
DEFINES=(--dart-define=API_BASE_URL="$API_BASE_URL")
[[ -n ${CONTACT_EMAIL:-} ]] && DEFINES+=(--dart-define=CONTACT_EMAIL="$CONTACT_EMAIL")

# 1. 作る（配布版＝release。デプロイ設計書 6.1・6.2）
cd "$ROOT/app"
STAGE=$ROOT/app/build/release-upload/$PLATFORM
rm -rf "$STAGE" && mkdir -p "$STAGE"
if [[ $PLATFORM == android ]]; then
  flutter build apk --release "${DEFINES[@]}"
  cp build/app/outputs/flutter-apk/app-release.apk "$STAGE/$FILE"
else
  # Windows のビルドにはシンボリックリンクが要る（開発者モードを一時的にオンにする）
  # APK を作った直後は、Flutter の一時フォルダーの作り直しで1回目が失敗することがあるので、1回だけやり直す
  flutter build windows --release "${DEFINES[@]}" || flutter build windows --release "${DEFINES[@]}"
  # Inno Setup は PATH になければ、winget の既定の入れ場所（使う人のフォルダー）から探す（デプロイ設計書 6.2）
  ISCC=$(command -v ISCC.exe || echo "$LOCALAPPDATA/Programs/Inno Setup 6/ISCC.exe")
  "$ISCC" "/DAppVersion=$VERSION" windows\\installer\\meowscope.iss
  cp "build/installer/MeowScope-Setup-$VERSION.exe" "$STAGE/$FILE"
fi

# 2. 版の情報（API 設計書 10章）
SHA=$(sha256sum "$STAGE/$FILE" | cut -d' ' -f1)
SIZE=$(stat -c %s "$STAGE/$FILE")
printf '{"version": "%s", "buildNumber": %s, "sha256": "%s", "sizeBytes": %s}\n' \
  "$VERSION" "$BUILD" "$SHA" "$SIZE" > "$STAGE/release.json"
echo "作りました：$(cat "$STAGE/release.json")"

# 3. 置く
cd "$ROOT"
if [[ $TARGET == pc ]]; then
  # bash で呼ぶ（実行の権限に頼らない）
  bash deploy/place-release.sh "$PLATFORM" "$STAGE"
else
  BUCKET=$(tf output -raw releases_bucket)
  INSTANCE=$(tf output -raw instance_id)
  REGION=$(tf output -raw region)
  aws s3 cp "$STAGE/" "s3://$BUCKET/$PLATFORM/" --recursive --region "$REGION" --only-show-errors
  # EC2 で、S3 から取ってボリュームに置き、取ったファイルを消す。スクリプトは最新のリポジトリのものを使う
  TMP=/tmp/meowscope-release/$PLATFORM
  COMMANDS=$(printf '"%s",' \
    "set -euo pipefail" \
    "cd /opt/meowscope && git pull --ff-only" \
    "rm -rf $TMP && mkdir -p $TMP" \
    "aws s3 cp s3://$BUCKET/$PLATFORM/ $TMP/ --recursive --region $REGION --only-show-errors" \
    "bash deploy/place-release.sh $PLATFORM $TMP -f compose.yaml -f deploy/compose.aws.yaml" \
    "rm -rf $TMP")
  PARAMS=$(mktemp)
  echo "{\"commands\": [${COMMANDS%,}]}" > "$PARAMS"
  COMMAND_ID=$(aws ssm send-command --region "$REGION" --instance-ids "$INSTANCE" \
    --document-name AWS-RunShellScript --comment "meowscope release $PLATFORM $FULL" \
    --parameters "file://$(cygpath -m "$PARAMS" 2>/dev/null || echo "$PARAMS")" \
    --query Command.CommandId --output text)
  rm -f "$PARAMS"
  aws ssm wait command-executed --region "$REGION" --command-id "$COMMAND_ID" --instance-id "$INSTANCE" || true
  STATUS=$(aws ssm get-command-invocation --region "$REGION" --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE" --query Status --output text)
  aws ssm get-command-invocation --region "$REGION" --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE" --query '[StandardOutputContent,StandardErrorContent]' --output text | tail -5
  # 中継のファイルは置き終わったら要らない
  aws s3 rm "s3://$BUCKET/$PLATFORM/" --recursive --region "$REGION" --only-show-errors
  [[ $STATUS == Success ]] || { echo "EC2 で置けませんでした（$STATUS）" >&2; exit 1; }
fi

# 手元の作ったファイルも残さない（配布版の APK は数十 MB ある）
rm -rf "$STAGE"
echo "Ver.$VERSION（ビルド $BUILD）を $TARGET に置きました。アプリの設定の「更新を確かめる」で知らせが出ることを確かめてください"
