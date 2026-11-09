# Plone in a Box(TM) on DigitalOcean.
#
#   export DIGITALOCEAN_TOKEN=<your API token>
#   cd src/digitalocean
#   terraform init
#   terraform apply -var 'ssh_public_key_path=~/.ssh/id_ed25519.pub'
#
# If that SSH key is already in your DigitalOcean account, pass its fingerprint
# instead (DigitalOcean rejects uploading the same key twice):
#   terraform apply -var 'ssh_key_fingerprint=aa:bb:cc:...'
#
# The Droplet provisions itself on first boot by running ../StackScript as
# user data; that takes about 10 minutes. Follow it with:
#   ssh root@<public_ip> tail -f /var/log/cloud-init-output.log
# then read the admin password with:
#   ssh root@<public_ip> cat /root/plone-credentials.txt

terraform {
  required_version = ">= 1.3"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

variable "region" {
  description = "DigitalOcean region slug, for example nyc3, sfo3, ams3, fra1 or tor1."
  type        = string
  default     = "nyc3"
}

variable "size" {
  description = "Droplet size slug. s-1vcpu-1gb is enough for a small site (swap is added automatically); s-1vcpu-2gb or larger for a busier one."
  type        = string
  default     = "s-1vcpu-2gb"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key to upload and allow as root. Ignored when ssh_key_fingerprint is set."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "ssh_key_fingerprint" {
  description = "Fingerprint of an SSH key already in your DigitalOcean account (Settings > Security). Use this instead of ssh_public_key_path if the key is already uploaded."
  type        = string
  default     = ""
}

variable "ssh_allowed_cidrs" {
  description = "Addresses allowed to reach SSH (port 22). Restrict this to your own IP address where possible."
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}

variable "backups" {
  description = "Enable DigitalOcean weekly backups for the Droplet (extra cost)."
  type        = bool
  default     = false
}

variable "admin_password" {
  description = "Plone admin password (at least 12 characters). Leave empty to have one generated; read it with the credentials_command output. Note: it is stored in Terraform state and in the server's user data."
  type        = string
  default     = ""
  sensitive   = true
}

variable "domain" {
  description = "Optional domain name for the site. If set (with letsencrypt_email), HTTPS is configured, so DNS must already point at the Droplet's address."
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

# Reads the API token from the DIGITALOCEAN_TOKEN environment variable.
provider "digitalocean" {}

resource "digitalocean_ssh_key" "deployer" {
  count      = var.ssh_key_fingerprint == "" ? 1 : 0
  name       = "plone-in-a-box"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

locals {
  ssh_key = var.ssh_key_fingerprint != "" ? var.ssh_key_fingerprint : digitalocean_ssh_key.deployer[0].fingerprint
}

resource "digitalocean_droplet" "plone" {
  name       = "plone-in-a-box"
  image      = "ubuntu-26-04-x64"
  region     = var.region
  size       = var.size
  ssh_keys   = [local.ssh_key]
  ipv6       = true
  monitoring = true
  backups    = var.backups
  tags       = ["plone-in-a-box"]

  # Same provisioning script as the Linode StackScript, with its settings
  # passed as environment variables.
  user_data = join("\n", [
    "#!/bin/bash",
    "export ADMIN_PASSWORD=\"$(echo ${base64encode(var.admin_password)} | base64 -d)\"",
    "export DOMAIN=${jsonencode(var.domain)}",
    "export LETSENCRYPT_EMAIL=${jsonencode(var.letsencrypt_email)}",
    "export SITE_TIMEZONE=${jsonencode(var.site_timezone)}",
    "export PLONE_VERSION=${jsonencode(var.plone_version)}",
    "export VOLTO_VERSION=${jsonencode(var.volto_version)}",
    file("${path.module}/../StackScript"),
  ])
}

resource "digitalocean_firewall" "plone" {
  name        = "plone-in-a-box"
  droplet_ids = [digitalocean_droplet.plone.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = var.ssh_allowed_cidrs
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

output "public_ip" {
  value = digitalocean_droplet.plone.ipv4_address
}

output "site_url" {
  value = var.domain != "" ? "https://${var.domain}" : "http://${digitalocean_droplet.plone.ipv4_address}"
}

# Only needed when admin_password was left empty.
output "credentials_command" {
  value = "ssh root@${digitalocean_droplet.plone.ipv4_address} cat /root/plone-credentials.txt"
}
