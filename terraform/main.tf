variable "region" {}
variable "instance_type" {}
variable "users" {
  type = "list"
}
variable "arn" {}
variable "key_name" {}
variable "public_key" {}

provider "aws" {
  region = "${var.region}"
}

resource "aws_iam_policy_attachment" "user_policy" {
    name       = "userpolicy"
    users      = "${var.users}"
    policy_arn = "${var.arn}"
}

resource "aws_key_pair" "user_key_pair" {
  key_name = "${var.key_name}"
  public_key = "${var.public_key}"
}

resource "aws_security_group" "allow_ssh_jupyter" {
  name        = "allowsshjupyter"
  description = "Allow ssh, jupyter notebook in, all out"

  ingress {
    from_port   = 8888
    to_port     = 8888
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags {
    Name = "allow_ssh_jupyter"
  }
}

# Pick the latest ubuntu bionic ami
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}


resource "aws_instance" "web" {
  ami           = "${data.aws_ami.ubuntu.id}"
  instance_type = "${var.instance_type}"
  root_block_device {
    volume_size = 18
  }

  security_groups = ["${aws_security_group.allow_ssh_jupyter.name}"]

  key_name = "${var.key_name}"

  tags {
    Name = "gato-rapido-311"
  }

  user_data = <<EOF
#!/bin/bash
# Install docker
apt-get update
apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
apt-get update
apt-get install -y docker-ce
usermod -aG docker ubuntu

# Install docker-compose
curl -L https://github.com/docker/compose/releases/download/1.22.0/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Clone repo
git clone https://github.com/gato-rapido/complaint-cleanup /home/ubuntu/complaint-cleanup

# Run docker-compose
docker-compose -f /home/ubuntu/complaint-cleanup/docker-compose.yml up -d
EOF

}

