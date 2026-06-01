# --------------------------------------------------------------------------
# Instance role for the backend EC2: lets it pull the model from S3 on boot
# and be managed via SSM Session Manager (no SSH key required).
# --------------------------------------------------------------------------

data "aws_iam_policy_document" "backend_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backend" {
  name               = "${local.name_prefix}-backend"
  description        = "Instance role for the AI Text Flagger backend"
  assume_role_policy = data.aws_iam_policy_document.backend_assume.json

  tags = local.common_tags
}

# Keyless shell access via Session Manager.
resource "aws_iam_role_policy_attachment" "backend_ssm" {
  role       = aws_iam_role.backend.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Read-only access to the model bucket (only when it exists).
data "aws_iam_policy_document" "backend_model" {
  count = var.enable_model_bucket ? 1 : 0

  statement {
    sid       = "ListModelBucket"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.model[0].arn]
  }

  statement {
    sid       = "ReadModelObjects"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.model[0].arn}/*"]
  }
}

resource "aws_iam_role_policy" "backend_model" {
  count = var.enable_model_bucket ? 1 : 0

  name   = "${local.name_prefix}-backend-model-read"
  role   = aws_iam_role.backend.id
  policy = data.aws_iam_policy_document.backend_model[0].json
}

resource "aws_iam_instance_profile" "backend" {
  name = "${local.name_prefix}-backend"
  role = aws_iam_role.backend.name

  tags = local.common_tags
}
