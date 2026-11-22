terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# -----------------------------------------------------------------------------
# VPC principal
# -----------------------------------------------------------------------------
resource "aws_vpc" "vpc_03" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "VPC-03"
  }
}

# -----------------------------------------------------------------------------
# Subxarxes públiques en dues Availability Zones
# -----------------------------------------------------------------------------
resource "aws_subnet" "public_subnet_a" {
  vpc_id                  = aws_vpc.vpc_03.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public Subnet A"
  }
}

resource "aws_subnet" "public_subnet_b" {
  vpc_id                  = aws_vpc.vpc_03.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public Subnet B"
  }
}

# -----------------------------------------------------------------------------
# Internet Gateway i Taula d'Encaminament pública
# -----------------------------------------------------------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc_03.id

  tags = {
    Name = "IGW-VPC-03"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc_03.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Public Route Table"
  }
}

resource "aws_route_table_association" "public_subnet_a" {
  subnet_id      = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_subnet_b" {
  subnet_id      = aws_subnet.public_subnet_b.id
  route_table_id = aws_route_table.public_rt.id
}

# -----------------------------------------------------------------------------
# Security Group (SSH extern, ICMP només dins la VPC, sortida oberta)
# -----------------------------------------------------------------------------
resource "aws_security_group" "sg_vpc_03" {
  name        = "vpc-03-sg"
  description = "SG per a VPC-03: SSH extern, ICMP intern i sortida oberta"
  vpc_id      = aws_vpc.vpc_03.id

  ingress {
    description = "SSH port 22 TCP (0.0.0.0/0)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ICMP tots els tipus (CIDR VPC 10.0.0.0/16)"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [aws_vpc.vpc_03.cidr_block]
  }

  egress {
    description = "Tot el trafic sortint (0.0.0.0/0)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SG-VPC-03"
  }
}

# -----------------------------------------------------------------------------
# Última AMI oficial d'Amazon Linux 2023 (x86_64)
# -----------------------------------------------------------------------------
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# -----------------------------------------------------------------------------
# Instàncies EC2 (ec2-a i ec2-b)
# -----------------------------------------------------------------------------
resource "aws_instance" "ec2_a" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_subnet_a.id
  vpc_security_group_ids      = [aws_security_group.sg_vpc_03.id]
  key_name                    = "vockey"
  associate_public_ip_address = true

  tags = {
    Name = "ec2-a"
  }
}

resource "aws_instance" "ec2_b" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_subnet_b.id
  vpc_security_group_ids      = [aws_security_group.sg_vpc_03.id]
  key_name                    = "vockey"
  associate_public_ip_address = true

  tags = {
    Name = "ec2-b"
  }
}
