# IAM Role for EC2 with SSM access
resource "aws_iam_role" "pii_ec2_role" {
  name = "pii-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach SSM policy
resource "aws_iam_role_policy_attachment" "pii_ec2_ssm" {
  role       = aws_iam_role.pii_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile
resource "aws_iam_instance_profile" "pii_ec2_profile" {
  name = "pii-ec2-profile"
  role = aws_iam_role.pii_ec2_role.name
}
