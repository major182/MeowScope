# デプロイ設計書：MeowScope

| 項目 | 内容 |
|---|---|
| 文書番号 | 09 |
| 版数 | 0.3 |
| 作成日 | 2026-11-11 |
| 作成者 | major182 |
| 前提となる文書 | [01 要件定義書](01_requirements.md)、[02 技術選定書](02_tech-stack.md)、[07 ログ設計書](07_logging-design.md)、[08 性能テスト設計書](08_performance-test.md) |

サーバーを AWS に置いて動作を確かめ（C-04）、その後に開発者の PC の Docker へ移す（C-05・C-08）。そのための構成・費用・手順・バックアップ・アプリの配り方を書く。

アカウント ID・ARN・インスタンス ID・IP アドレス・サーバーの URL・tailnet の名前・メールアドレスは、この文書に書かない。値の確かめ方を各章に書く。

---

## 1. 決めたこと

| 項目 | 決定 | 理由 |
|---|---|---|
| 進め方 | A. AWS に置く → B. PC へ移す → AWS を消す | 要件定義書 C-04・C-05 |
| AWS に置く期間 | 開始と終了は利用者が合図する（日数は決めない） | 課題の確認の日程に合わせる |
| AWS で使う人 | 開発者1人（Android と Windows） | 家族は PC へ移した後に使い始める |
| サーバー | EC2（t3.small）1台で、`compose.yaml` をそのまま動かす | 技術選定書。PC と同じ構成で移しやすい |
| HTTPS | Caddy 2.11.9 で証明書を自動で取る。名前は **sslip.io**（IP アドレスから名前を作る無料のサービス） | ドメインを買わずに正式な証明書を使える |
| サーバーへの入り方 | セッションマネージャーだけ。SSH は開けない | 鍵を持たず、受けるポートを減らす |
| サーバーのイメージ | GitHub Actions で作り、GitHub Container Registry（GHCR）に置く。EC2 は取ってくるだけ | t3.small（2GB）でのビルドはメモリーが足りないおそれがある。ECR や OIDC の設定も要らない |
| 秘密の値 | パラメーターストア（SecureString）。EC2 は起動のときに読んで、root だけが読める `.env` に書く | 鍵をリポジトリ・イメージに入れない |
| 自動デプロイ | 行わない。更新は手で1つのコマンド（5.3） | 使う期間が短く、使う人も1人 |
| バックアップ | 毎日 DB のダンプと写真を固め、7世代を残す（NF-BK-01）。AWS と PC で同じスクリプト | 4章 |
| PC での接続 | Tailscale の `tailscale serve` で、tailnet の中だけに HTTPS で出す | サーバーをインターネットに公開しない（C-08） |
| Android の配布 | 署名した APK を、開発者の手で端末に入れる | 一般公開しない。署名の鍵は PC の外に出さない |
| Windows の配布 | Inno Setup 6 でインストーラーにする（版は入れるときに最新の安定版を確かめて固定する）。署名はしない（Q-27） | 署名がなくても作れる。SmartScreen の警告は「詳細情報」→「実行」で進める |
| 公開の範囲 | APK・インストーラーは GitHub Releases に置かない | サーバーの URL（IP アドレスや tailnet の名前）がアプリに入るため |

## 2. 構成

### 2.1 A. AWS

```mermaid
flowchart LR
  dev["開発者の端末<br>Android・Windows"] -- "HTTPS 443" --> caddy
  subgraph ec2 ["EC2 t3.small（東京）"]
    caddy["Caddy<br>証明書を自動で取る"] -- "8080" --> server["Spring Boot"]
    server --> db[("PostgreSQL 18.6")]
    server --> photos[("写真のボリューム")]
    cron["cron：毎日のバックアップ"] --> backup[("/var/backups/meowscope<br>7世代")]
  end
  le["Let's Encrypt"] -- "HTTP 80（証明書の確認）" --> caddy
  server -- "SMTP 587" --> gmail["Gmail"]
  ghcr["GHCR"] -. "イメージを取る" .-> server
  ssm["パラメーターストア"] -. "起動のときに読む" .-> ec2
```

| 資源 | 内容 |
|---|---|
| VPC | 公開サブネット1つ。NAT ゲートウェイは使わない |
| セキュリティグループ | 受けるのは 80・443 だけ（どこからでも。スマートフォンは回線で IP が変わるため）。DB とサーバーの 8080 は外に出さない |
| EC2 | Amazon Linux 2023、t3.small、ディスク gp3 20GB（暗号化）。スワップ 2GB。IMDSv2 だけ |
| 固定の IP（Elastic IP） | sslip.io の名前と証明書が変わらないように固定する |
| IAM ロール | セッションマネージャー（`AmazonSSMManagedInstanceCore`）と、`/meowscope/*` のパラメーターを読む権限だけ |
| パラメーターストア | `/meowscope/db-password`・`/meowscope/jwt-secret`・`/meowscope/mail-username`・`/meowscope/mail-password`（どれも SecureString） |

`compose.yaml` に、AWS 用の差分 `deploy/compose.aws.yaml` を重ねる。

- `caddy` を足す（80・443 を受け、`server:8080` へ渡す。証明書はボリュームに残す）
- `server` の 8080 と `db` の 5432 は外に出さない
- `server` はイメージを GHCR から取る（`build` しない）。`MEOWSCOPE_ENV=prod`
- `MAIL_HOST=smtp.gmail.com`・`MAIL_PORT=587`

サーバーの URL は `https://<固定の IP をハイフンでつないだもの>.sslip.io/api/v1`。確かめ方は `terraform output api_base_url`。

### 2.2 B. PC

```mermaid
flowchart LR
  phone["家族の端末<br>Tailscale"] -- "HTTPS（tailnet の中だけ）" --> ts
  subgraph pc ["開発者の PC（Docker Desktop）"]
    ts["tailscale serve"] -- "127.0.0.1:8080" --> server["Spring Boot"]
    server --> db[("PostgreSQL 18.6")]
    server --> photos[("写真のボリューム")]
    task["タスクスケジューラー：毎日のバックアップ"] --> backup[("バックアップのフォルダー<br>7世代")]
  end
```

- `deploy/compose.pc.yaml` を重ね、サーバーの 8080 を `127.0.0.1` だけで受ける（LAN に出さない）
- `tailscale serve` が tailnet の中だけに HTTPS で出す。証明書は Tailscale が用意する
- サーバーの URL は `https://<PC の名前>.<tailnet>.ts.net/api/v1`。確かめ方は `tailscale status`
- 家族の端末に Tailscale を入れ、同じ tailnet に招く
- PC が止まっている間は、アプリは端末に記録し、PC が動いたら同期する（F-OF-02）

## 3. 費用（A. AWS）

金額は USD で、概算。作る前に AWS の料金 API で確かめる。

| 項目 | 単価 | 1日 |
|---|---|---|
| EC2 t3.small（東京） | 約 $0.027／時 | 約 $0.65 |
| 公開 IPv4（Elastic IP） | $0.005／時 | $0.12 |
| EBS gp3 20GB | 約 $0.096／GB・月 | 約 $0.07 |
| パラメーターストア（標準）・通信 | ― | ほぼ 0 |
| **合計** | | **約 $0.85** |

- アカウントは無料プランで、費用はクレジットから引かれる。2026-11-11 の残高は $158.54、期限は 2027-03-27（`aws freetier get-account-plan-state` で確認）。t3.small は無料プランで使える種類（`aws ec2 describe-instance-types --filters Name=free-tier-eligible,Values=true`）
- 予算のアラートとコスト異常検出は、アカウント共通のものを使う。Terraform では作らず、消さない

## 4. バックアップ（F-BK-01、NF-BK-01）

`deploy/backup.sh` を AWS（cron）と PC（タスクスケジューラーから Git Bash）で動かす。

| 項目 | 内容 |
|---|---|
| 時刻 | 毎日 3:00（日本時間） |
| DB | `docker compose exec db pg_dump -Fc` で1つのファイルに |
| 写真 | 写真のボリュームを tar.gz に固める |
| 残す数 | 7世代。古いものから消す |
| 置き場所 | AWS：EC2 のディスクの `/var/backups/meowscope`。PC：PC の外付けか、別のディスクのフォルダー（利用者が決める） |
| 失敗したとき | 終了コードと件数をログに残す（AWS は `/var/log/meowscope-backup.log`）。途中で失敗したファイルは世代に数えない |
| 復元の確認 | 作った日に一度、別のコンテナの PostgreSQL に戻し、利用者・猫・記録の件数と写真の数が元と合うかを確かめる（`deploy/restore-check.sh`）。PC へ移すときの手順も、これと同じ |

- 置き場所は引数（`deploy/backup.sh <置き場所>`）か環境変数 `BACKUP_DIR` で渡す。AWS では EC2 の初期設定が cron（`/etc/cron.d/meowscope-backup`）を登録する
- 2つのスクリプトは CI（`deploy` のジョブ）で、開発用の compose に対して動かして確かめる

AWS のバックアップは EC2 のディスクの中だけにある。AWS を使う期間は短く、PC へ移すときに最新のダンプを持ち出すので、別の場所への写しはしない。

## 5. 手順

### 5.1 準備（1回だけ）

1. サーバーのイメージを作る：GitHub Actions の `server-image` を手で動かし、`ghcr.io/major182/meowscope-server:<コミット>` を作る（公開のパッケージ。秘密の値は入っていない）
2. パラメーターストアに秘密の値を入れる。DB のパスワードと JWT の鍵はその場で作る。メールの値は手元の `.env` から入れ、画面に出さない
3. Android の署名の鍵を作る（6.1）

### 5.2 A. AWS を作る

1. `deploy/terraform` で `terraform apply -var image_tag=<イメージのコミット>`（VPC・EC2・Elastic IP・セキュリティグループ・IAM ロール）。状態のファイル（tfstate）は手元に置き、コミットしない
2. EC2 の初期設定（`deploy/terraform/user_data.sh.tftpl`）が、スワップを作り、Docker を入れ、リポジトリを取り、パラメーターから `.env` を作り、`docker compose up -d` まで行う
3. `terraform output api_base_url` の URL で、`/actuator/health` が `UP` を返すことを確かめる
4. その URL でアプリを作って入れる（6章）
5. 5.4 の確認を行う

- 初期設定は最初の起動のときだけ動く。`image_tag` を変えて `terraform apply` しても EC2 は作り直さない（DB がディスクの中にあるため）。イメージの更新は 5.3 で行う
- 定義の書式と、外に出すポートが 80・443 だけであることは CI（`deploy` のジョブ）で確かめる

### 5.3 更新

新しいイメージを作った後に、セッションマネージャーから `deploy/update.sh <コミット>` を動かす（イメージを取り直し、`docker compose up -d`）。DB の構造は、起動のときに Flyway が反映する。

### 5.4 確認すること

| 観点 | 内容 |
|---|---|
| 通信 | HTTP は HTTPS へ転送される。証明書が正しい。8080・5432 には外からつながらない |
| 認証 | 登録・ログイン・ログアウト・パスワードの再設定のメールが届く |
| 機能 | おうち・招待のリンク・記録・写真・カレンダー・統計・通知・Android のウィジェット |
| 同期 | Android と Windows の両方で記録し、互いに届く。機内モードで記録し、戻したら届く |
| ログ | `docker compose logs server` に JSON のログが出る。端末のログが届く |
| バックアップ | 翌朝にバックアップができている。復元の確認が通る |

### 5.5 B. PC へ移す

1. PC に Tailscale を入れ、`tailscale serve` を設定する
2. AWS でバックアップを取り、PC に持ってくる（S3 は使わず、セッションマネージャーのポート転送で取る）
3. PC で `deploy/compose.pc.yaml` を重ねて立て、ダンプと写真を戻す。件数が AWS と合うことを確かめる
4. PC の URL でアプリを作り直し、入れ直す（同じ署名の鍵なので、端末のデータは残る）
5. 家族の端末に Tailscale とアプリを入れる
6. タスクスケジューラーにバックアップを登録する
7. 数日使って問題がなければ、7章で AWS を消す

## 6. アプリの配り方

### 6.1 Android

- 署名の鍵は `keytool` で作り、リポジトリの外（`%USERPROFILE%\.meowscope\`）に置く。鍵のパスワードは利用者のパスワードの管理の道具に残す。鍵をなくすと、同じアプリとして上書きできなくなる
- `app/android/key.properties`（`.gitignore` に入れる）で鍵の場所を渡し、`build.gradle.kts` は、それがあれば release の署名に使う（なければ今のとおり debug の鍵）
- `flutter build apk --release --dart-define=API_BASE_URL=<サーバーの URL>`
- `adb install -r` か、ファイルを端末に送って入れる

### 6.2 Windows

- `flutter build windows --release --dart-define=API_BASE_URL=<サーバーの URL>`
- Inno Setup のスクリプト（`app/windows/installer/meowscope.iss`）で、`build/windows/x64/runner/Release` をインストーラー（`MeowScope-Setup-<版>.exe`）にする。スタートメニューに登録し、アンインストールもできる
- 署名はしない（Q-27）。初めて動かすときの SmartScreen の警告は「詳細情報」→「実行」で進める

## 7. 片付け（AWS）

1. 最新のバックアップを PC に持ってきてあることを確かめる
2. `terraform destroy` で全部消す
3. EC2・EBS・Elastic IP・セキュリティグループ・IAM ロール・パラメーターの消し残しが 0 件であることを CLI で確かめる
4. 予算のアラートとコスト異常検出は**残す**
5. 要件定義書の F-BK-01 の「PC へ移すまで」を済みにする

## 8. 改訂履歴

| 版数 | 日付 | 内容 |
|---|---|---|
| 0.1 | 2026-11-11 | 初版（#152）。AWS（EC2・Caddy・sslip.io）→ PC（Tailscale）の構成、バックアップ、アプリの配り方 |
| 0.2 | 2026-11-11 | AWS の定義を追加（#158）。Caddy を 2.11.9 に。5.2 に apply の引数と、初期設定は最初の起動だけであることを追記 |
| 0.3 | 2026-11-11 | バックアップ・復元の確認・更新のスクリプトを追加（#160）。4章に置き場所の渡し方と cron を追記 |
