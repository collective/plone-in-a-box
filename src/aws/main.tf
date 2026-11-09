# Plone in a Box(TM) on Amazon EC2.
#
#   cd src/aws
#   terraform init
#   terraform apply -var 'ssh_public_key_path=~/.ssh/id_ed25519.pub'
#
# The instance provisions itself on first boot by running ../StackScript as
# EC2 user data; that takes about 10 minutes. Follow it with:
#   ssh ubuntu@<public_ip> sudo tail -f /var/log/cloud-init-output.log
# then read the admin password with:
#   ssh ubuntu@<public_ip> sudo cat /root/plone-credentials.txt

terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type. Plone + Volto + PostgreSQL need at least 2 GB of RAM; t3.small is the smallest recommended size."
  type        = string
  default     = "t3.small"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key that will be allowed to log in as the 'ubuntu' user."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed to reach SSH (port 22). Restrict this to your own IP address where possible."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "admin_password" {
  description = "Plone admin password (at least 12 characters). Leave empty to have one generated; read it with the credentials_command output. Note: it is stored in Terraform state and in the server's user data."
  type        = string
  default     = ""
  sensitive   = true
}

variable "domain" {
  description = "Optional domain name for the site. If set (with letsencrypt_email), HTTPS is configured, so DNS must already point at the instance's address."
  type        = string
  default     = ""
}

variable "letsencrypt_email" {
  description = "Email address for Let's Encrypt certificate notices. Required for HTTPS."
  type        = string
  default     = ""
}

variable "site_timezone" {
  description = "Time zone for the Plone site, for example America/Chicago."
  type        = string
  default     = "UTC"
}

variable "plone_version" {
  description = "plone/plone-backend image tag."
  type        = string
  default     = "6.2"
}

variable "volto_version" {
  description = "plone/plone-frontend image tag."
  type        = string
  default     = "19"
}

variable "volume_size_gb" {
  description = "Size of the root disk in GB."
  type        = number
  default     = 20
}

provider "aws" {
  region = var.region
}

# Latest Ubuntu 24.04 LTS image published by Canonical for this region.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "deployer" {
  key_name_prefix = "plone-in-a-box-"
  public_key      = file(pathexpand(var.ssh_public_key_path))
}

resource "aws_security_group" "plone" {
  name_prefix = "plone-in-a-box-"
  description = "Plone in a Box: SSH, HTTP and HTTPS"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidrs
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_instance" "app_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.plone.id]

  root_block_device {
    volume_size = var.volume_size_gb
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens = "required" # IMDSv2 only
  }

  # Same provisioning script as the Linode StackScript, with its settings
  # passed as environment variables. Compressed, because EC2 limits user data
  # to 16 KB and the script is larger; cloud-init decompresses it.
  user_data_base64 = base64gzip(join("\n", [
    "#!/bin/bash",
    "export ADMIN_PASSWORD=\"$(echo ${base64encode(var.admin_password)} | base64 -d)\"",
    "export DOMAIN=${jsonencode(var.domain)}",
    "export LETSENCRYPT_EMAIL=${jsonencode(var.letsencrypt_email)}",
    "export SITE_TIMEZONE=${jsonencode(var.site_timezone)}",
    "export PLONE_VERSION=${jsonencode(var.plone_version)}",
    "export VOLTO_VERSION=${jsonencode(var.volto_version)}",
    file("${path.module}/../StackScript"),
  ]))
  user_data_replace_on_change = true

  tags = {
    Name = "Plone in a Box"
  }
}

output "public_ip" {
  value = aws_instance.app_server.public_ip
}

output "site_url" {
  value = var.domain != "" ? "https://${var.domain}" : "http://${aws_instance.app_server.public_ip}"
}

# Only needed when admin_password was left empty.
output "credentials_command" {
  value = "ssh ubuntu@${aws_instance.app_server.public_ip} sudo cat /root/plone-credentials.txt"
}
