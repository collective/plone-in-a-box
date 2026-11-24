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
# The server provisions itself on first boot: its user data downloads
# src/StackScript from the Plone in a Box release named in var.release and
# runs it; that takes about 10 minutes. Open the site_url output to watch the
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

variable "release" {
  description = "The Plone in a Box release whose setup script the server downloads from GitHub at first boot. To try unreleased changes, set a branch or commit that's pushed to GitHub."
  type        = string
  default     = "2.21"

  validation {
    condition     = can(regex("^[A-Za-z0-9._/-]+$", var.release))
    error_message = "release: a release, branch or commit, such as 2.21."
  }
}

variable "location" {
  description = "Hetzner location: nbg1 (Nuremberg), fsn1 (Falkenstein), hel1 (Helsinki), ash (Ashburn, VA), hil (Hillsboro, OR) or sin (Singapore). Empty: the first location in preferred_locations that offers the server type. A location set here is always used, and if it doesn't offer the server type, Terraform stops before creating anything and lists the locations that do."
  type        = string
  default     = ""
}

variable "preferred_locations" {
  description = "With location empty, the locations to choose from, best first. Put the ones near your visitors first; where the server is can also matter for data protection rules."
  type        = list(string)
  default     = ["hel1", "fsn1", "nbg1"]
}

variable "server_type" {
  description = "Hetzner server type. cpx02 (1 vCPU, 1 GB) is enough for a small site, but isn't offered in ash or hil; use cpx11 (2 GB) there. Arm types such as cax11 work too."
  type        = string
  default     = "cpx02"
}

variable "deletion_protection" {
  description = "Delete and rebuild protection: Hetzner refuses to delete or rebuild the server, from Terraform, the Hetzner Console or anything else. To remove the box on purpose, set this to false and run terraform apply, change prevent_destroy to false in this file, then run terraform destroy."
  type        = bool
  default     = true
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

variable "site_language" {
  description = "The site's language, as a language code such as en, de, fr, es or pt-br."
  type        = string
  default     = "en"

  validation {
    condition     = can(regex("^[A-Za-z]{2,3}([-_][A-Za-z]{2,4})?$", var.site_language))
    error_message = "site_language: a language code such as en, de or pt-br."
  }
}

variable "starter_content" {
  description = "Create the sample pages a new site (or a Plone distribution) comes with; false starts with an empty site."
  type        = bool
  default     = true
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

variable "addons" {
  description = "Backend add-ons, optional: Python package names separated by spaces, for example collective.easyform. Activate them afterwards in Site Setup > Add-ons."
  type        = string
  default     = ""
}

variable "frontend_image" {
  description = "Frontend image, optional: a ready-made Plone in a Box image such as ghcr.io/collective/plone-in-a-box-frontend:19-vlt (Volto Light Theme), or your own. Empty: the standard Volto image."
  type        = string
  default     = ""
}

variable "backend_image" {
  description = "Backend image, optional: replaces the official Plone backend, for example a Plone distribution such as ghcr.io/kitconcept/kitconcept-intranet-backend:3.11 (with its frontend image in frontend_image), or your own project's. Empty: the official Plone backend."
  type        = string
  default     = ""
}

variable "demo_user" {
  description = "Demo login, optional: a username such as demo, for people you let try the site. Setup creates it with a generated password, saved next to the admin password in /root/plone-credentials.txt."
  type        = string
  default     = ""
}

variable "demo_password" {
  description = "The demo login's password, optional, at least 12 characters. Empty: generated, and saved in /root/plone-credentials.txt."
  type        = string
  default     = ""
  sensitive   = true
}

variable "demo_roles" {
  description = "Roles of the demo login, separated by commas, for example Editor or Site Administrator. Empty: the roles the frontend image suggests, or Site Administrator."
  type        = string
  default     = ""
}

variable "notify_url" {
  description = "Notification URL, optional: update reports are posted here, for example https://ntfy.sh/a-long-random-topic, or a Slack, Discord, Google Chat, Mattermost or Microsoft Teams webhook."
  type        = string
  default     = ""
  sensitive   = true
}

variable "smtp_host" {
  description = "Email, optional: the SMTP server of an email relay service, for example mail.smtp2go.com. Empty: the site doesn't send email."
  type        = string
  default     = ""
}

variable "smtp_port" {
  description = "Email: SMTP port."
  type        = number
  default     = 587
}

variable "smtp_user" {
  description = "Email: SMTP username."
  type        = string
  default     = ""
}

variable "smtp_password" {
  description = "Email: SMTP password."
  type        = string
  default     = ""
  sensitive   = true
}

variable "email_from" {
  description = "Email: the site's From address, at a domain the email service has verified."
  type        = string
  default     = ""
}

variable "report_email" {
  description = "Email: your address for a test email and the update reports. Empty: the From address."
  type        = string
  default     = ""
}

variable "auto_update" {
  description = "Install Plone, Volto and PostgreSQL patch releases every week, after a database backup, and undo them if the site doesn't come back."
  type        = bool
  default     = true
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

# Which locations offer the server type right now (not every location offers
# every type, and a type can be out of stock in a location for a while).
data "hcloud_server_type" "chosen" {
  name = var.server_type
}

locals {
  type_locations = sort([for l in data.hcloud_server_type.chosen.locations : l.name if l.available && !l.is_deprecated])
  location       = var.location != "" ? var.location : try([for l in var.preferred_locations : l if contains(local.type_locations, l)][0], "")
}

resource "hcloud_server" "plone" {
  name         = "plone-in-a-box"
  image        = "ubuntu-26.04"
  server_type  = var.server_type
  location     = local.location
  ssh_keys     = [hcloud_ssh_key.deployer.id]
  firewall_ids = [hcloud_firewall.plone.id]
  backups      = var.backups

  delete_protection  = var.deletion_protection
  rebuild_protection = var.deletion_protection

  labels = {
    "plone-in-a-box" = "true"
  }

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  # Same provisioning script as the Linode StackScript, with its settings
  # passed as environment variables. The server downloads the script, because
  # Hetzner accepts only 32 KiB of user data.
  user_data = join("\n", [
    "#!/bin/bash",
    "export ADMIN_PASSWORD=\"$(echo ${base64encode(var.admin_password)} | base64 -d)\"",
    "export DOMAIN=${jsonencode(var.domain)}",
    "export LETSENCRYPT_EMAIL=${jsonencode(var.letsencrypt_email)}",
    "export SITE_TIMEZONE=${jsonencode(var.site_timezone)}",
    "export SITE_LANGUAGE=${jsonencode(var.site_language)}",
    "export STARTER_CONTENT=${var.starter_content ? "yes" : "no"}",
    "export PLONE_VERSION=${jsonencode(var.plone_version)}",
    "export VOLTO_VERSION=${jsonencode(var.volto_version)}",
    "export ADDONS=\"$(echo ${base64encode(var.addons)} | base64 -d)\"",
    "export FRONTEND_IMAGE=\"$(echo ${base64encode(var.frontend_image)} | base64 -d)\"",
    "export BACKEND_IMAGE=\"$(echo ${base64encode(var.backend_image)} | base64 -d)\"",
    "export DEMO_USER=\"$(echo ${base64encode(var.demo_user)} | base64 -d)\"",
    "export DEMO_PASSWORD=\"$(echo ${base64encode(var.demo_password)} | base64 -d)\"",
    "export DEMO_ROLES=\"$(echo ${base64encode(var.demo_roles)} | base64 -d)\"",
    "export AUTO_UPDATE=${var.auto_update ? "yes" : "no"}",
    "export NOTIFY_URL=\"$(echo ${base64encode(var.notify_url)} | base64 -d)\"",
    "export SMTP_HOST=\"$(echo ${base64encode(var.smtp_host)} | base64 -d)\"",
    "export SMTP_PORT=${var.smtp_port}",
    "export SMTP_USER=\"$(echo ${base64encode(var.smtp_user)} | base64 -d)\"",
    "export SMTP_PASSWORD=\"$(echo ${base64encode(var.smtp_password)} | base64 -d)\"",
    "export EMAIL_FROM=\"$(echo ${base64encode(var.email_from)} | base64 -d)\"",
    "export REPORT_EMAIL=\"$(echo ${base64encode(var.report_email)} | base64 -d)\"",
    "url=https://raw.githubusercontent.com/tkimnguyen/plone-in-a-box/${var.release}/src/StackScript",
    "if ! curl -fsSL --retry 10 --retry-delay 5 --retry-all-errors -o /root/plone-in-a-box.sh \"$url\"; then",
    "  echo \"[plone-in-a-box] Could not download $url\" | tee -a /var/log/plone-in-a-box.log >&2",
    "  exit 1",
    "fi",
    "exec bash /root/plone-in-a-box.sh",
  ])

  lifecycle {
    # The location is chosen when the server is created. Availability changes
    # over time, and a later run choosing another location must not replace
    # the server (and delete the site).
    # Terraform never deletes or replaces the server, which would delete the
    # site: terraform destroy and any change that needs a new server stop with
    # an error. To remove the box on purpose, see deletion_protection.
    prevent_destroy = true

    # Settings used only when the server is created: the user data (the
    # release and settings, read at first boot), the SSH key and the image.
    # Changing them later, or a newer release or Ubuntu image, must not replace
    # the server; plone-update keeps it current.
    ignore_changes = [location, user_data, ssh_keys, image]

    precondition {
      condition     = local.location != ""
      error_message = "None of preferred_locations (${join(", ", var.preferred_locations)}) offers ${var.server_type} right now. Locations that do: ${join(", ", local.type_locations)}. Set location or preferred_locations to one of them."
    }
    precondition {
      condition     = local.location == "" || contains(local.type_locations, local.location)
      error_message = "${var.server_type} isn't offered in ${local.location} right now. Locations that offer it: ${join(", ", local.type_locations)}. Set location to one of these, or leave it empty to choose from preferred_locations."
    }
  }
}

output "location" {
  value = hcloud_server.plone.location
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
