# Plone in a Box(TM) on Hetzner Cloud.
#
#   export HCLOUD_TOKEN=<your API token>
#   cd src/hetzner
#   terraform init
#   terraform apply -var 'ssh_public_key_path=~/.ssh/id_ed25519.pub'
#
# The token belongs to one Hetzner project (Security > API tokens, Read &
# Write), and the server is created in that project.
#
# The server provisions itself on first boot by running ../StackScript as user
# data; that takes about 10 minutes. Open the site_url output to watch the
# setup progress page, and if you left admin_password empty, read the
# generated one with:
#   ssh root@<public_ip> cat /root/plone-credentials.txt

terraform {
  required_version = ">= 1.3"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.0"
    }
  }
}

variable "location" {
  description = "Hetzner location: nbg1 (Nuremberg), fsn1 (Falkenstein), hel1 (Helsinki), ash (Ashburn, VA), hil (Hillsboro, OR) or sin (Singapore). Not every server type is offered everywhere."
  type        = string
  default     = "hel1"
}

variable "server_type" {
  description = "Hetzner server type. cpx02 (1 vCPU, 1 GB) is enough for a small site, but isn't offered in ash or hil; use cpx11 (2 GB) there. Arm types such as cax11 work too."
  type        = string
  default     = "cpx02"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key to upload and allow as root."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "ssh_allowed_cidrs" {
  description = "Addresses allowed to reach SSH (port 22). Keep 0.0.0.0/0 and ::/0 to use SSH from anywhere, or restrict to your own IP."
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}

variable "backups" {
  description = "Enable Hetzner's automatic daily backups of the server (extra cost)."
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
  description = "Optional domain name for the site. If set (with letsencrypt_email), HTTPS is configured, so DNS must already point at the server's address."
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

# Reads the API token from the HCLOUD_TOKEN environment variable.
provider "hcloud" {}

resource "hcloud_ssh_key" "deployer" {
  name       = "plone-in-a-box"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

resource "hcloud_firewall" "plone" {
  name = "plone-in-a-box"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = var.ssh_allowed_cidrs
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_server" "plone" {
  name         = "plone-in-a-box"
  image        = "ubuntu-26.04"
  server_type  = var.server_type
  location     = var.location
  ssh_keys     = [hcloud_ssh_key.deployer.id]
  firewall_ids = [hcloud_firewall.plone.id]
  backups      = var.backups
  labels = {
    "plone-in-a-box" = "true"
  }

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  # Same provisioning script as the Linode StackScript, with its settings
  # passed as environment variables. Hetzner accepts up to 32 KiB of user data.
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

output "public_ip" {
  value = hcloud_server.plone.ipv4_address
}

output "site_url" {
  value = var.domain != "" ? "https://${var.domain}" : "http://${hcloud_server.plone.ipv4_address}"
}

# Only needed when admin_password was left empty.
output "credentials_command" {
  value = "ssh root@${hcloud_server.plone.ipv4_address} cat /root/plone-credentials.txt"
}
