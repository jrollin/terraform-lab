resource "aws_key_pair" "admin_key" {
    key_name   = "admin_user"
    public_key = file(var.ssh_public_key)
    
    tags = {
      Name = "keypair"
      Env = "demo"
    }
}

resource "aws_default_vpc" "default" {
  tags = {
    Name = "vpc"
    Env = "demo"
  }
}

resource "aws_instance" "webserver" {
    ami           = var.ami
    instance_type = var.instance
    key_name = aws_key_pair.admin_key.key_name

    vpc_security_group_ids = [
        aws_security_group.web.id,
        aws_security_group.ssh.id,
        aws_security_group.ping.id,
        aws_security_group.egress.id
    ]

    count = var.instance_count

    user_data = data.template_file.myuserdata.template

    tags = {
      Name = "webserver"
      Env = "demo"
    }
}



resource "aws_security_group" "web" {
  name        = "web"
  description = "Security group for web that allows web traffic from internet"
  
  vpc_id = aws_default_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    tags = {
      Name = "sg-web"
      Env = "demo"
    }
}


resource "aws_security_group" "ssh" {
  name        = "ssh"
  description = "Security group for nat instances that allows SSH and VPN traffic from internet"

  vpc_id = aws_default_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-ssh"
    Env = "demo"
  }
}

resource "aws_security_group" "egress" {
  name        = "egress"
  description = "Default security group that allows outbound traffic from all instances in the VPC"

  vpc_id = aws_default_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-egress"
    Env = "demo"
  }
}



resource "aws_security_group" "ping" {
  name        = "ping"
  description = "Default security group that allows to ping the instance"

  vpc_id = aws_default_vpc.default.id
  
  ingress {
    from_port        = -1
    to_port          = -1
    protocol         = "icmp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "sg-ping"
    Env = "demo"
  }
}