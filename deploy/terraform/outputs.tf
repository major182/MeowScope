output "api_base_url" {
  description = "アプリに渡すサーバーの URL（--dart-define=API_BASE_URL）"
  value       = "https://${local.site_address}/api/v1"
}

output "instance_id" {
  description = "セッションマネージャーでつなぐときの EC2 の ID（aws ssm start-session --target）"
  value       = aws_instance.web.id
}

output "releases_bucket" {
  description = "アプリの更新の中継の S3 バケット（deploy/publish-release.sh が使う）"
  value       = aws_s3_bucket.releases.bucket
}

output "region" {
  description = "リージョン（deploy/publish-release.sh が使う）"
  value       = var.region
}
