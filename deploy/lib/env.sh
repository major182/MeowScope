# shellcheck shell=bash
# .env（gitignore の対象）から1つの値を読む（デプロイ設計書 6.4）。source して使う
#   使い方：env_value <.env の場所> <名前>
#   - 名前=値 の行の値を出す。同じ名前が何度もあれば最後の行（docker compose と同じ）
#   - 値の前後の引用符（" か '）と、Windows の改行（CR）を外す。最後の行に改行がなくても読む
#   - ファイルや行がなければ何も出さない（呼ぶ側が「渡されていない」と扱う）
env_value() {
  local file=$1 name=$2 line value
  [[ -f $file ]] || return 0
  # 最後の行に改行がないと read が取りこぼすので、|| [[ -n $line ]] で拾う
  while IFS= read -r line || [[ -n $line ]]; do
    line=${line%$'\r'}
    [[ $line == "$name="* ]] && value=${line#"$name="}
  done < "$file"
  [[ -n ${value:-} ]] || return 0
  if [[ $value == \"*\" || $value == \'*\' ]]; then
    value=${value:1:${#value}-2}
  fi
  printf '%s' "$value"
}
