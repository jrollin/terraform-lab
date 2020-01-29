variable "profile" {
  default = "terraform_iam_user"
}

variable "region" {
  default = "eu-west-3"
}

variable "ssh_user" {
  # ami ubuntu
  default = "ubuntu"
}

variable "ssh_private_key" {
  default = "~/.ssh/MyKeyPair.pem"
}

variable "ssh_public_key" {
  default = "~/.ssh/MyKeyPair.pub"
}

variable "ami" {
  # AWS linux 
  # default = "ami-0652eb0db9b20aeaf"
  # Ubuntu bionic 18.04
  default = "ami-087855b6c8b59a9e4"
}

variable "instance" {
  default = "t2.micro"
}

variable "instance_count" {
  default = "1"
}
