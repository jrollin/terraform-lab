provider "aws" {
  profile    = "default"
  region     = "eu-west-3"
}

resource "aws_instance" "example" {
  ami           = "ami-0652eb0db9b20aeaf"
  instance_type = "t2.micro"
}