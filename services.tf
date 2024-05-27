## Set Provider
provider "aws" {
    region  = var.region
}

## Set AWS Region
variable "region" {
  default = "ap-southeast-1"
}


data "aws_caller_identity" "current" {}

variable "main_vpc_cidr" {
  description = "Sample VPC CIDR"
  default     = "10.101.0.0/16"
}

## Create a VPC
resource "aws_vpc" "main_vpc" {
  cidr_block = var.main_vpc_cidr
  tags = {
    Name = "main-vpc"
  }
}

## Create a subnet in the VPC 
resource "aws_subnet" "main_sub" {
  vpc_id        = aws_vpc.main_vpc.id
  cidr_block    = cidrsubnet(var.main_vpc_cidr, 8, 1)
  map_public_ip_on_launch = "true"
  availability_zone = "${var.region}a"
  tags          = {
    Name = "main-sub-1"
  }
}

## Create Internet Gateway for outbound and inbound connectivity
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "main-igw"
  }
}

## Create Route Table & associate subnet to route table
resource "aws_route_table" "main_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = {
    Name = "main-rt"
  }
}

resource "aws_route_table_association" "main_sub_assoc" {
  subnet_id = aws_subnet.main_sub.id
  route_table_id = aws_route_table.main_rt.id
}

## Create keypair for SSH
resource "tls_private_key" "private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "keypair" {
  key_name   = "keypair"
  public_key = tls_private_key.private_key.public_key_openssh
}

resource "local_file" "ssh_key" {
  filename = "${aws_key_pair.keypair.key_name}.pem"
  content = tls_private_key.private_key.private_key_pem
  file_permission = "0400"
}

## Identifying Ubuntu AMI ID 
data "aws_ami" "aws_ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["679593333241"]
}


## Security Group for AWS Instance
resource "aws_security_group" "instance_sg" {
  name        = "instance-sg"
  description = "Instance Security Group"
  vpc_id      = aws_vpc.main_vpc.id

  # Allow all outbound traffic.
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "instance-sg"
  }
}

## Create role to access existing secrets in AWS Secret Manager
resource "aws_iam_role" "main_role" {
  name = "main-role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "main_policy" {
  name = "main-policy"
  role = aws_iam_role.main_role.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "ecr:*",
        ]
        Effect   = "Allow"
        Resource = "arn:aws:secretsmanager:*:${data.aws_caller_identity.current.account_id}:secret:pc/defender*"
      },
    ]
  })
}

resource "aws_iam_instance_profile" "main_profile" {
  name = "main-profile"
  role = "${aws_iam_role.main_role.name}"
}

## Public IP output
output "instance_public_ip" {
  value       = aws_instance.main_instance.public_ip
}