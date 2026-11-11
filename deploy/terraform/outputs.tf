output "api_base_url" {
  description = "アプリに渡すサーバーの URL（--dart-define=API_BASE_URL）"
  value       = "https://${local.site_address}/api/v1"
}

output "instance_id" {
  description = "セッションマネージャーでつなぐときの EC2 の ID（aws ssm start-session --target）"
  value       = aws_instance.web.id
}
