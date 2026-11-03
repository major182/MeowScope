# API 設計書：MeowScope

| 項目 | 内容 |
|---|---|
| 文書番号 | 06 |
| 版数 | 0.5 |
| 作成日 | 2026-11-02 |
| 作成者 | major182 |
| 前提となる文書 | [01 要件定義書](01_requirements.md)、[05 DB 設計書](05_db-design.md) |

---

## 1. 方針

- 形式は JSON の REST とし、パスは `/api/v1` から始める（NF-MT-03）
- 記録や猫などの共有データは、個別の API を作らず同期の API でまとめて送受信する。オフラインの処理と通信の経路を1つにするため
- 認証が必要な API は、`Authorization: Bearer <アクセストークン>` を付ける
- おうちの権限はサーバーで毎回確かめ、属していないおうちは 404 を返す（NF-SC-04）

## 2. 認証

アクセストークンは15分、更新トークンは30日で期限が切れる。更新のたびに新しい更新トークンへ交換し、使い回しを検知したら、そのユーザーの全トークンを無効にする。端末では OS の安全な保管場所に置く（NF-SC-07）。

| メソッド | パス | 説明 | 認証 |
|---|---|---|---|
| POST | `/auth/register` | 新規登録 | 不要 |
| POST | `/auth/login` | ログイン（回数制限あり：NF-SC-03） | 不要 |
| POST | `/auth/refresh` | トークンの更新 | 更新トークン |
| POST | `/auth/logout` | ログアウト | 必要 |
| POST | `/auth/password-reset/request` | 再設定の受付（Q-26 の結果で見直す） | 不要 |
| POST | `/auth/password-reset/confirm` | 再設定の実行（同上） | 不要 |

ログアウトの動作：

- 同期済みのデータは端末から消す
- 未送信の記録と写真は、ユーザーの ID を付けて端末に残し、同じユーザーが再ログインしたら送信する
- 別のユーザーのログイン中は、残したデータを表示も送信もしない
- 更新トークンの期限が切れても、端末での記録は続けられる。再ログインの後に送信する

## 3. アカウント

| メソッド | パス | 説明 |
|---|---|---|
| GET | `/me` | 自分の情報（メールアドレスを含む） |
| PATCH | `/me` | 表示名の変更 |
| PUT | `/me/password` | パスワードの変更 |
| PUT | `/me/icon` | アイコンの登録 |
| DELETE | `/me` | 退会。本文に `keepRecords` |

## 4. おうち

| メソッド | パス | 説明 |
|---|---|---|
| POST | `/households` | おうちの作成。端末が作ったおうちの ID と名前、標準の8項目（ID を含む）を受け取って登録し、作った人をメンバーにする。サーバーでは標準の項目を作らない |
| POST | `/households/{id}/invitations` | 招待の作成（Q-26 の結果で見直す） |
| POST | `/invitations/accept` | 招待の受諾 |
| POST | `/households/{id}/leave` | おうちを抜ける。本文に `keepRecords` |

## 5. 同期

```text
POST /sync
```

端末の変更を送り、続けて相手の変更を受け取る処理を、1回の通信で行う。

要求：

```json
{
  "lastSeq": 1200,
  "changes": [
    {
      "table": "records",
      "id": "UUID",
      "updatedAt": "2026-11-02T00:10:00Z",
      "deletedAt": null,
      "data": { "catId": "UUID", "recordTypeId": "UUID" }
    }
  ]
}
```

応答：

```json
{
  "results": [{ "id": "UUID", "status": "applied" }],
  "changes": [],
  "nextSeq": 1215,
  "hasMore": false,
  "fullResyncRequired": false
}
```

| 項目 | 動作 |
|---|---|
| 競合 | サーバーが後から受け取った変更を採用する（BR-10）。受け取った順に `server_seq` を振る。`updatedAt` は比べない |
| 結果の値 | `applied`（反映）、`ignored`（同じ変更の再送で、すでに反映済み）、`rejected`（権限や内容の誤り） |
| 再送 | 同じ変更を再送しても結果は同じになる。通信が切れても安全に送り直せる |
| 分割 | 1回で送受信するのは500件まで。`hasMore` が真なら続けて呼ぶ |
| 全件の取り直し | `lastSeq` が90日の保持より古いときは `fullResyncRequired` を返す |
| 同時実行 | 端末では同時に1つだけ実行する |

`rejected` の変更は再送せず、S-46 に件数を表示する。

同期する表と `data` に入れる主な列は次のとおり（列の意味は [05 DB 設計書](05_db-design.md)）。おうちそのものの作成は `POST /households` で行う。

| 表 | `data` の主な列 |
|---|---|
| `households` | `name` |
| `cats` | `householdId`、`name`、`birthDate`、`sex`、`conditions`、`status` |
| `record_types` | `householdId`、`name`、`icon`、`kind`、`sortOrder`、`hidden`（非表示） |
| `records` | `catId`、`recordTypeId`、`recordedAt`、`authorName`、`valueNumber`、`level`、`detail`、`memo` |
| `user_settings` | `weekStart` など。端末では同期の実装まで `app_states` の `settings.weekStart` に置いており、同期の実装で移す |

退会やおうちを抜ける操作を別の端末で行ったときは、次の同期で検知し、端末のそのおうちのデータを消して S-04 へ戻る。

## 6. 写真

| メソッド | パス | 説明 |
|---|---|---|
| PUT | `/photos/{id}` | 写真の送信。画像のみ、上限 5MB（NF-SC-08） |
| GET | `/photos/{id}` | 写真の取得 |

記録の同期を先に行い、その後で写真を送る。写真の取得もおうちの権限を確かめる。

## 7. 端末のログ

| メソッド | パス | 説明 |
|---|---|---|
| POST | `/client-logs` | 端末のログの受信。認証が必要で、1回100件、1時間60回まで（ログ設計書 8章） |

## 8. AI 分析（次の段階）

| メソッド | パス | 説明 |
|---|---|---|
| POST | `/households/{id}/analysis` | 期間を指定して分析する。写真は送らない（BR-04） |

## 9. エラーの形式

RFC 9457（Problem Details）の形式で返す。

```json
{
  "type": "about:blank",
  "title": "入力内容に誤りがあります",
  "status": 400,
  "code": "VALIDATION_ERROR",
  "requestId": "問い合わせ番号"
}
```

| 状態コード | 使う場面 |
|---|---|
| 400 | 入力の誤り |
| 401 | 未認証、トークンの期限切れ |
| 403 | 許可されていない操作 |
| 404 | 存在しない、または属していないおうち |
| 409 | メールアドレスの重複 |
| 413 | 写真の容量超過 |
| 429 | 回数制限 |
| 500 | サーバーの異常。`requestId` を画面に表示する（F-LG-02） |

## 10. 改訂履歴

| 版数 | 日付 | 内容 |
|---|---|---|
| 0.1 | 2026-11-02 | 初版 |
| 0.2 | 2026-11-02 | ログアウトと別端末での退会の動作を追加 |
| 0.3 | 2026-11-02 | 端末のログの受信を追加 |
| 0.4 | 2026-11-03 | 標準の項目を8つに変更 |
| 0.5 | 2026-11-03 | 標準の8項目は端末で作って送る形に変更。競合をサーバーが受け取った順に変更。同期する表と列を記入 |
