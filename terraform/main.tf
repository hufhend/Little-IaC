// Define the AWS provider and region
provider "aws" {
  region = var.region
}

// Create a VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name    = var.vpc_name
    App     = var.app
    Creator = var.creator
    Unit    = var.unit
    Env     = var.env
  }
}

// Create a subnet
resource "aws_subnet" "main" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_cidr_block
  availability_zone = "${var.region}a"
  map_public_ip_on_launch = true
  tags = {
    Name    = var.subnet_name
    App     = var.app
    Creator = var.creator
    Unit    = var.unit
    Env     = var.env
  }
}

// Create an internet gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name    = var.igw_name
    App     = var.app
    Creator = var.creator
    Unit    = var.unit
    Env     = var.env
  }
}

// Create a route table
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name    = var.route_table_name
    App     = var.app
    Creator = var.creator
    Unit    = var.unit
    Env     = var.env
  }
}

// Associate the route table with the subnet
resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

// Create a security group
resource "aws_security_group" "main" {
  vpc_id = aws_vpc.main.id
  dynamic "ingress" {
    for_each = var.security_group_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = [var.security_group_cidr_ingress]
    }
  }
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.subnet_cidr_block]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.security_group_cidr_egress]
  }
  tags = {
    Name    = var.security_group_name
    App     = var.app
    Creator = var.creator
    Unit    = var.unit
    Env     = var.env
  }
}

// Create AWS EC2 instances
resource "aws_instance" "example" {
  count         = var.instance_count
  ami           = var.ami
  instance_type = var.instance_type
  subnet_id     = aws_subnet.main.id
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.main.id]
  tags = {
    Name    = "server-${format("%02d", count.index + 1)}"
    App     = var.app
    Creator = var.creator
    Unit    = var.unit
    Env     = var.env
  }
  key_name = var.key_name
  user_data = <<-EOF
              #!/bin/bash
              set -e
              adduser --disabled-password --gecos "" ${var.username}
              echo "${var.username} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
              mkdir -p /home/${var.username}/.ssh
              cp /home/ubuntu/.ssh/authorized_keys /home/${var.username}/.ssh/
              chown -R ${var.username}:${var.username} /home/${var.username}/.ssh
              EOF
}

// Load my public key
resource "aws_key_pair" "deployer" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
  tags = {
    Name    = var.key_name
    App     = var.app
    Creator = var.creator
    Unit    = var.unit
    Env     = var.env
  }
}
