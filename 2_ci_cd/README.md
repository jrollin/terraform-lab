# Configure CI and CD

## What we will build ?

![Schéma](assets/schema.png)

## Requirements

Aws environnement configured

## Steps

### Configure SSH key

Configure AWS credential for a specific user "terraform_iam_user"

```bash
aws configure --profile terraform_iam_user 
```

Create private and public keys to connect to AWS EC2 machines

```bash
ssh-keygen -t rsa -b 2048 -f ~/.ssh/aws_terrafom.pem -q -P ''
chmod 400 ~/.ssh/aws_terrafom.pem
ssh-keygen -y -f ~/.ssh/aws_terrafom.pem > ~/.ssh/aws_terrafom.pub
```

### Configure Infra on AWS

Files to create on terraform 

* `terraform.tf`
* `provider.tf`
* `resources.tf`
* `variables.tf`

> nb: all *.tf are read by terraform 

#### Define terraform version


File `terraform.tf`

```hcl
terraform {
  required_version = ">= 0.12.18"
}
```

#### Define provider AWS


File `provider.tf`
```hcl
provider "aws" {
  region  = var.region
  profile = var.profile
}
```

#### Define resources AWS


File `resources.tf`
```hcl
provider "aws" {
  region  = var.region
  profile = var.profile
}

```

Define ssh ssh pair key to use to connect to our instances :

```bash
resource "aws_key_pair" "admin_key" {
    key_name   = "admin_user"
    public_key = file(var.ssh_public_key)
    
    tags = {
      Name = "keypair"
      Env = "demo"
    }
}
```

Define VPC 

```hcl
resource "aws_default_vpc" "default" {
  tags = {
    Name = "vpc"
    Env = "demo"
  }
}

```

Define Security groups


Allow incomming traffic from port 80 and 443

```hcl
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
```

Allow traffic incoming to port 22

```hcl
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
```

Allow outcoming traffic

```hcl
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
```

Allow ping (useful for health check)

```hcl
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
```

Create instance with related security group  

```hcl
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

    tags = {
      Name = "webserver"
      Env = "demo"
    }
}
```

#### Define Data AWS

User data can be loaded [at instance start](https://docs.aws.amazon.com/fr_fr/AWSEC2/latest/UserGuide/user-data.html) 

File `data.tf`

```hcl
data "template_file" "myuserdata" {
  template = "${file("${path.cwd}/myuserdata.tpl")}"
}
```

Ensure that Python is installed on machine 

> Needed for AWS to execute tasks on remote machine

```bash
#!/bin/bash
export PATH=$PATH:/usr/local/bin
which pip >/dev/null
if [ $? -ne 0 ];
then
  echo 'PIP NOT PRESENT'
  if [ -n "$(which yum)" ]; 
  then
    yum install -y python-pip
  else 
    apt-get -y update && apt-get -y install python-pip
  fi
else 
  echo 'PIP ALREADY PRESENT'
fi

```

Update resource block instance to add `user_data` key

```hcl
resource "aws_instance" "webserver" {
    // commented lines

    user_data = data.template_file.myuserdata.template

    // commented lines
}
```

#### Define variables 

File `variables.tf`

```hcl
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
  # Ubuntu bionic 18.04
  default = "ami-087855b6c8b59a9e4"
}

variable "instance" {
  default = "t2.micro"
}

variable "instance_count" {
  default = "1"
}
```

#### Define output AWS

Display ip assigned to instances after terraform plan execution

File on `outputs.tf`

```hcl
output ips {
    value = [aws_instance.webserver.*.public_ip]
}
```



### Configure CI on Gitlab

* Use case with react application ([create react app ](https://fr.reactjs.org/docs/create-a-new-react-app.html)) 
* Use an account on [gitlab.com](https://about.gitlab.com/)


> Info: We need an http Server to serve our static files, we can install `nginx` on instance startup through `userdata` OR choose an `ami with nginx` 


### CI pipeline stages

Exemple with `.gitlab-ci.yml` for `react node` project

```yaml
  # This file is a template, and might need editing before it works on your project.
# Official framework image. Look for the different tagged releases at:
# https://hub.docker.com/r/library/node/tags/
image: node:latest

# This folder is cached between builds
# http://docs.gitlab.com/ce/ci/yaml/README.html#cache
cache:
  paths:
  - node_modules/

test:
  stage: test
  script:
    - npm install
    - npm test

build:
  stage: build
  script:
    - npm install
    - npm run build
  artifacts:
    paths:
    - build


```

### Add deploy stage

Each time a branch is merged to master, the deploy stage is triggered

Exemple with `.gitlab-ci.yml` for `node` project

```yaml
    
.ansible: &ansible
  stage: deploy
  #when: manual
  image: gableroux/ansible:2.8.3

  before_script:
    # https://docs.gitlab.com/ee/ci/ssh_keys/
    - eval $(ssh-agent -s)
    - mkdir -p ~/.ssh/
    - chmod 700 ~/.ssh
    - echo "$SSH_CONFIG" > ~/.ssh/config
    - echo "$SSH_KNOWN_HOSTS" > ~/.ssh/known_hosts
    - chmod 644 ~/.ssh/known_hosts
    - echo "$SSH_PRIVATE_KEY" | tr -d '\r' | ssh-add - > /dev/null
    # disable ssh host verification
    - export ANSIBLE_HOST_KEY_CHECKING=False

deploy-example-master:
  <<: *ansible
  script:
    - ansible --version
    - ansible all -i "$INSTANCES" -m ping -u $DEPLOY_USER
    - ansible all -m copy -a "src=build/ dest=/var/www/html mode=0755 owner=www-data group=www-data" -i "$INSTANCES" -b  -u $DEPLOY_USER 
  only:
    - master
```

> nb: uncomment `when: manual` to automatic deploy

Settings > CI/CD > Secret variables

#### Create secret variables

* **INSTANCES** : ips instances (IP return by terraform plan)
* **DEPLOY_USER** : user ssh used to connect to machine (configured with Terraform)
* **SSH_PRIVATE_KEY** :  ssh private key (configured with terraform)
* **SSH_CONFIG** : (optional)
* **SSH_KNOWN_HOSTS** (optional if env ANSIBLE_HOST_KEY_CHECKING is set to false )



Example **DEPLOY_USER**

```
`ubuntu` if AMI ubuntu on AWS 

```
Example **INSTANCES** (to replace)

```ini
35.180.211.xxx, 178.45.xx.xx
```

Example **SSH_PRIVATE_KEY** (to replace by your keypair)

```
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNza.......
-----END OPENSSH PRIVATE KEY-----
```


### Launch new Job / merge to master 


Open URL in your browser

That's it !

