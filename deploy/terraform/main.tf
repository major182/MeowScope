# MeowScope の AWS の環境（デプロイ設計書 2.1）

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# ---- ネットワーク：公開サブネット1つ。NAT ゲートウェイは使わない ----

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = { Name = "meowscope" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "meowscope" }
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = { Name = "meowscope-public" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "meowscope-public" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ---- セキュリティグループ：受けるのは 80・443 だけ（SSH は開けない） ----

resource "aws_security_group" "web" {
  name        = "meowscope-web"
  description = "MeowScope: HTTP and HTTPS only"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "meowscope-web" }
}

resource "aws_vpc_security_group_ingress_rule" "web" {
  for_each = {
    http       = { port = 80, protocol = "tcp" }
    https      = { port = 443, protocol = "tcp" }
    https_quic = { port = 443, protocol = "udp" }
  }

  security_group_id = aws_security_group.web.id
  description       = each.key
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = each.value.port
  to_port           = each.value.port
  ip_protocol       = each.value.protocol
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.web.id
  description       = "all outbound (GHCR, Lets Encrypt, Gmail, SSM)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ---- IAM：セッションマネージャーと /meowscope/* のパラメーターの読み取りだけ ----

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "ec2" {
  name = "meowscope-ec2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "read_params" {
  name = "read-meowscope-parameters"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter", "ssm:GetParameters"]
      Resource = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/meowscope/*"
    }]
  })
}

resource "aws_iam_instance_profile" "ec2" {
  name = "meowscope-ec2"
  role = aws_iam_role.ec2.name
}

# ---- 固定の IP：sslip.io の名前と証明書が変わらないように、先に取ってから EC2 に付ける ----

resource "aws_eip" "web" {
  domain = "vpc"

  tags = { Name = "meowscope" }
}

locals {
  site_address = "${replace(aws_eip.web.public_ip, ".", "-")}.sslip.io"
}

# ---- EC2 ----

resource "aws_instance" "web" {
  ami                    = data.aws_ssm_parameter.al2023.insecure_value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  associate_public_ip_address = true

  metadata_options {
    http_tokens                 = "required" # IMDSv2 だけ
    http_put_response_hop_limit = 1          # コンテナからは使わせない
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    region       = var.region
    git_ref      = var.git_ref
    image_tag    = var.image_tag
    site_address = local.site_address
  })
  # 新しい AMI や image_tag に変わっても EC2 を作り直さない（DB がディスクの中にあるため）。
  # 更新は deploy/update.sh で行う（デプロイ設計書 5.3）
  lifecycle {
    ignore_changes = [ami, user_data]
  }

  tags = { Name = "meowscope" }
}

resource "aws_eip_association" "web" {
  allocation_id = aws_eip.web.id
  instance_id   = aws_instance.web.id
}

# ---- アプリの更新の中継（デプロイ設計書 6.4）：手元から上げ、EC2 が取ってボリュームに置く ----

resource "aws_s3_bucket" "releases" {
  bucket_prefix = "meowscope-releases-"
  # terraform destroy で中身ごと消す（デプロイ設計書 7章）
  force_destroy = true

  tags = { Name = "meowscope-releases" }
}

# 外からは読ませない（サーバーの URL が入ったファイルなので、利用者だけに配る）
resource "aws_s3_bucket_public_access_block" "releases" {
  bucket = aws_s3_bucket.releases.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 置き終わったら消すが、消し忘れても1日で消える
resource "aws_s3_bucket_lifecycle_configuration" "releases" {
  bucket = aws_s3_bucket.releases.id

  rule {
    id     = "expire-relay"
    status = "Enabled"
    filter {}
    expiration {
      days = 1
    }
  }
}

# EC2 には読み取りだけを許す（書き込み・削除は手元から行う）
resource "aws_iam_role_policy" "read_releases" {
  name = "read-meowscope-releases"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.releases.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.releases.arn
      },
    ]
  })
}
