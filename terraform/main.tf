provider "aws" {
  region = "eu-central-1"
}

resource "aws_instance" "example" {
  ami           = "ami-07eef52105e8a2059" # Nahraď ID AMI podle své oblasti
  instance_type = "t3.small"
  tags = {
    Name = "server-01"
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

resource "aws_key_pair" "deployer" {
  key_name   = "my-key"
  public_key = file("~/.ssh/id_rsa.pub")
}
