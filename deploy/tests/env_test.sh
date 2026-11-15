#!/usr/bin/env bash
# deploy/lib/env.sh の env_value の単体テスト（UT-EV-01〜08）。CI の deploy で動かす
#   使い方：bash deploy/tests/env_test.sh
set -euo pipefail
# shellcheck source=deploy/lib/env.sh
source "$(dirname "$0")/../lib/env.sh"

DIR=$(mktemp -d)
trap 'rm -rf "$DIR"' EXIT
failed=0

# 期待どおりかを比べ、結果を1行出す
check() {
  local id=$1 expected=$2 actual=$3
  if [[ $expected == "$actual" ]]; then
    echo "ok   $id"
  else
    echo "FAIL $id：期待 [$expected]、実際 [$actual]"
    failed=1
  fi
}

printf 'A=1\nCONTACT_EMAIL=a@example.com\nB=2\n' > "$DIR/plain"
check "UT-EV-01 値を読む" "a@example.com" "$(env_value "$DIR/plain" CONTACT_EMAIL)"

printf 'CONTACT_EMAIL=a@example.com' > "$DIR/no-newline"
check "UT-EV-02 最後の行に改行がなくても読む" "a@example.com" "$(env_value "$DIR/no-newline" CONTACT_EMAIL)"

printf 'CONTACT_EMAIL=a@example.com\r\n' > "$DIR/crlf"
check "UT-EV-03 Windows の改行（CRLF）を外す" "a@example.com" "$(env_value "$DIR/crlf" CONTACT_EMAIL)"

printf 'X="a b"\nY='"'"'c'"'"'\n' > "$DIR/quoted"
check "UT-EV-04 二重引用符を外す" "a b" "$(env_value "$DIR/quoted" X)"
check "UT-EV-05 一重引用符を外す" "c" "$(env_value "$DIR/quoted" Y)"

printf 'A=1\nMY_CONTACT_EMAIL=x\n#CONTACT_EMAIL=y\nCONTACT_EMAIL=\n' > "$DIR/missing"
check "UT-EV-06 名前が一部だけ合う行・コメント・空の値は読まない" "" "$(env_value "$DIR/missing" CONTACT_EMAIL)"

printf 'URL=https://old\nURL=https://new/api/v1?a=b\n' > "$DIR/twice"
check "UT-EV-07 同じ名前は最後の行。値の中の = はそのまま" "https://new/api/v1?a=b" "$(env_value "$DIR/twice" URL)"

check "UT-EV-08 ファイルがなければ空" "" "$(env_value "$DIR/none" CONTACT_EMAIL)"

exit $failed
