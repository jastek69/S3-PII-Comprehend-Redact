resource "aws_vpc" "pii_vpc" {              # VPC ID: aws_vpc.CA_VPC.id  
   cidr_block       = "10.244.0.0/16"
   enable_dns_support   = true
   enable_dns_hostnames = true
  
  tags = {
    Name = "pii-vpc"
    Service = "pii"
    access = "Public"   
    zone = "Production"
    availability_zone = "A"
  }
}



resource "aws_subnet" "pii_subnet" {
  vpc_id     = aws_vpc.pii_vpc.id
  cidr_block = "10.244.0.0/24"
  availability_zone = "us-west-2a"
  tags = {
    Name = "pii_subnet"
    Service = "application1"
    Owner   = "Galactus"
    Planet  = "Taa"
  }
}


resource "aws_subnet" "cali-public-us-west-2a" {     
  vpc_id                  = aws_vpc.pii_vpc.id
  cidr_block              = "10.244.1.0/24"
  availability_zone       = "us-west-2a"
  map_public_ip_on_launch = true

  tags = {
    Name    = "cali-public-us-west-2a"
    Service = "application1"
    Owner   = "Galactus"
    Planet  = "Taa"
  }
}


resource "aws_subnet" "cali-public-us-west-2b" {    
  vpc_id                  = aws_vpc.pii_vpc.id
  cidr_block              = "10.244.2.0/24"
  availability_zone       = "us-west-2b"
  map_public_ip_on_launch = true

  tags = {
    Name    = "cali-public-us-west-2b"
    Service = "application1"
    Owner   = "Galactus"
    Planet  = "Taa"
  }
}


#these are for private
resource "aws_subnet" "cali-private-us-west-2a" {  
  vpc_id            = aws_vpc.pii_vpc.id
  cidr_block        = "10.244.11.0/24"
  availability_zone = "us-west-2a"

  tags = {
    Name    = "cali-private-us-west-2a"
    Service = "application1"
    Owner   = "Galactus"
    Planet  = "Taa"
  }
}


resource "aws_subnet" "cali-private-us-west-2b" {  
  vpc_id            = aws_vpc.pii_vpc.id
  cidr_block        = "10.244.12.0/24"
  availability_zone = "us-west-2b"

  tags = {
    Name    = "cali-private-us-west-2b"
    Service = "application1"
    Owner   = "Galactus"
    Planet  = "Taa"
  }
}


resource "aws_internet_gateway" "pii_IGW" {     # Internet Gateway ID: aws_internet_gateway.pii_IGW.id
  vpc_id     = aws_vpc.pii_vpc.id

  tags = {
    Name = "pii_IGW"
  }
}


# Public route table for pii VPC
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.pii_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.pii_IGW.id
  }

  tags = {
    Name = "pii-public-rt"
  }
}

# Associate public subnets to public route table
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.cali-public-us-west-2a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.cali-public-us-west-2b.id
  route_table_id = aws_route_table.public_rt.id
}



# Security Group for PII EC2
resource "aws_security_group" "pii_sg" {
  name        = "pii-ec2-sg"
  description = "Security group for PII EC2 instance - Lambda layer builder"
  vpc_id      = aws_vpc.pii_vpc.id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Restrict to your IP in production
    description = "SSH access"
  }

  # Health check
  ingress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["10.244.0.0/16"]  # VPC only
    description = "Health check"
  }

  # Outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "pii-ec2-sg"
  }
}

# EC2 for PII Redaction
resource "aws_instance" "pii" {
  ami                         = var.ec2_ami_id
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.cali-public-us-west-2a.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.pii_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.pii_ec2_profile.name
  key_name                    = var.pii_key_name
  user_data_base64            = filebase64("${path.module}/scripts/user_data.sh")
  
  tags = merge(local.common_tags, { Name = "${local.name_prefix}-pii-ec2" })
}
