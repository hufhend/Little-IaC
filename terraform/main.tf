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
}

resource "aws_key_pair" "deployer" {
  key_name   = "my-key"
  public_key = file("~/.ssh/id_rsa.pub")
}
