# PC の本番の Caddy（デプロイ設計書 2.4）
# Cloudflare の DNS に確かめの記録を書いて証明書を取るため、部品 caddy-dns/cloudflare を組み込む。
# 公式の組み立て用のイメージ（builder）で xcaddy を使って作り、公式の実行用のイメージに入れ替える
FROM caddy:2.11.9-builder AS builder
RUN xcaddy build v2.11.9 --with github.com/caddy-dns/cloudflare@v0.2.4

FROM caddy:2.11.9
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
