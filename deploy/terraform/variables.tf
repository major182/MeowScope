variable "region" {
  description = "AWS のリージョン（東京）"
  type        = string
  default     = "ap-northeast-1"
}

variable "image_tag" {
  description = "サーバーのイメージのタグ（server-image のワークフローで作ったコミットの SHA）"
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{40}$", var.image_tag))
    error_message = "image_tag にはコミットの SHA（40 文字）を指定してください。"
  }
}

variable "git_ref" {
  description = "EC2 が取ってくるリポジトリのブランチかタグ（compose の定義とスクリプトに使う）"
  type        = string
  default     = "main"
}

variable "instance_type" {
  description = "EC2 の種類"
  type        = string
  default     = "t3.small"
}
