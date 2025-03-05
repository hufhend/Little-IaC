// Define the AWS provider and region
provider "aws" {
  region = var.region
}

// Create AWS EC2 instances
resource "aws_instance" "example" {
  count         = 4
  ami           = var.ami
  instance_type = var.instance_type
  tags = {
    Name = "server-${format("%02d", count.index + 1)}"
  }
  key_name = "my-key"
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
  key_name   = "my-key"
  public_key = file("~/.ssh/id_rsa.pub")
}
