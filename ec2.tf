# --------------------------------------------------------------------------
# Backend: EC2 instance running the FastAPI/uvicorn API under systemd.
# Mirrors the manual setup documented in the backend README.
# --------------------------------------------------------------------------

# Latest Ubuntu 24.04 LTS (Noble) AMI, owned by Canonical.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Default VPC / subnet — keeps the module drop-in for the simple single-EC2
# topology in the README. Swap for explicit subnet/VPC vars if you need a
# custom network.
data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "backend" {
  name        = "${local.name_prefix}-backend"
  description = "AI Text Flagger backend: SSH and API access"
  vpc_id      = data.aws_vpc.default.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-backend"
  })
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each = toset(var.ssh_ingress_cidrs)

  security_group_id = aws_security_group.backend.id
  description       = "SSH"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_ingress_rule" "api" {
  for_each = toset(var.api_ingress_cidrs)

  security_group_id = aws_security_group.backend.id
  description       = "FastAPI backend"
  from_port         = var.api_port
  to_port           = var.api_port
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.backend.id
  description       = "Allow all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# Optional SSH key pair (omit and rely on SSM Session Manager if preferred).
resource "aws_key_pair" "backend" {
  count = var.ssh_public_key == "" ? 0 : 1

  key_name   = "${local.name_prefix}-backend"
  public_key = var.ssh_public_key

  tags = local.common_tags
}

resource "aws_instance" "backend" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.backend.id]
  key_name               = var.ssh_public_key == "" ? null : aws_key_pair.backend[0].key_name
  iam_instance_profile   = aws_iam_instance_profile.backend.name

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    repo_url     = var.backend_repo_url
    api_port     = var.api_port
    model_bucket = var.enable_model_bucket ? var.model_bucket_name : ""
    model_prefix = var.model_s3_prefix
    region       = var.region
  })

  # Re-bootstrap when the user-data changes.
  user_data_replace_on_change = true

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_tokens   = "required" # IMDSv2 only
    http_endpoint = "enabled"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-backend"
  })
}

resource "aws_eip" "backend" {
  count = var.assign_elastic_ip ? 1 : 0

  instance = aws_instance.backend.id
  domain   = "vpc"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-backend"
  })
}

locals {
  backend_public_ip = var.assign_elastic_ip ? aws_eip.backend[0].public_ip : aws_instance.backend.public_ip
}
