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
# The Droplet provisions itself on first boot: its user data downloads
# src/StackScript from the Plone in a Box release named in var.release and
# runs it; that takes about 10 minutes. Follow it with:
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

variable "release" {
  description = "The Plone in a Box release whose setup script the server downloads from GitHub at first boot. To try unreleased changes, set a branch or commit that's pushed to GitHub."
  type        = string
  default     = "2.24"

  validation {
    condition     = can(regex("^[A-Za-z0-9._/-]+$", var.release))
    error_message = "release: a release, branch or commit, such as 2.24."
  }
}

variable "region" {
  description = "DigitalOcean region slug, for example tor1, sfo3, nyc2, ams3 or fra1. Empty: the first region in preferred_regions that offers the size. A region set here is always used, and if it doesn't offer the size, Terraform stops before creating anything and lists the regions that do."
  type        = string
  default     = ""
}

variable "preferred_regions" {
  description = "With region empty, the regions to choose from, best first. Put the ones near your visitors first; where the server is can also matter for data protection rules."
  type        = list(string)
  default     = ["tor1", "nyc2", "sfo3", "ams3", "fra1", "lon1"]
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

variable "registry_user" {
  description = "Registry login for private images, optional: the username for the registry of frontend_image and backend_image, for example your GitHub username for ghcr.io."
  type        = string
  default     = ""
}

variable "registry_token" {
  description = "Registry token: a read-only access token for that registry, such as a GitHub token with only read:packages."
  type        = string
  default     = ""
  sensitive   = true
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

variable "spamhaus_key" {
  description = "Optional: a free Spamhaus Data Query Service key from spamhaus.com, so the blocklist checks can ask Spamhaus about the server's IP address and the site's domains."
  type        = string
  default     = ""
  sensitive   = true
}

variable "auto_update" {
  description = "Install Plone, Volto and PostgreSQL patch releases every week, after a database backup, and undo them if the site doesn't come back."
  type        = bool
  default     = true
}

variable "alerts" {
  description = "Email when the server is struggling: disk over 85% full, memory over 90% for 10 minutes, CPU over 90% for 30 minutes (DigitalOcean's resource alerts, free)."
  type        = bool
  default     = true
}

variable "alert_emails" {
  description = "Where alerts go: addresses of members of your DigitalOcean team (DigitalOcean only sends alerts to verified addresses). Empty: your account's email."
  type        = list(string)
  default     = []
}

variable "uptime_check" {
  description = "Check the site from outside every few minutes and email when it's down, or its certificate is about to expire (DigitalOcean Uptime: one check per account free, then $1 a month each)."
  type        = bool
  default     = false
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

# Which regions offer the size right now (not every region offers every size).
data "digitalocean_sizes" "chosen" {
  filter {
    key    = "slug"
    values = [var.size]
  }
}

locals {
  size_found   = length(data.digitalocean_sizes.chosen.sizes) > 0
  size_regions = local.size_found && try(data.digitalocean_sizes.chosen.sizes[0].available, false) ? sort(tolist(data.digitalocean_sizes.chosen.sizes[0].regions)) : []
  region       = var.region != "" ? var.region : try([for r in var.preferred_regions : r if contains(local.size_regions, r)][0], "")
}

resource "digitalocean_droplet" "plone" {
  name       = "plone-in-a-box"
  image      = "ubuntu-26-04-x64"
  region     = local.region
  size       = var.size
  ssh_keys   = [local.ssh_key]
  ipv6       = true
  monitoring = true
  backups    = var.backups
  tags       = ["plone-in-a-box"]

  # Same provisioning script as the Linode StackScript, with its settings
  # passed as environment variables. The server downloads the script, as on
  # AWS and Hetzner, so all three run the release named in var.release.
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
    "export REGISTRY_USER=\"$(echo ${base64encode(var.registry_user)} | base64 -d)\"",
    "export REGISTRY_TOKEN=\"$(echo ${base64encode(var.registry_token)} | base64 -d)\"",
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
    "export SPAMHAUS_KEY=\"$(echo ${base64encode(var.spamhaus_key)} | base64 -d)\"",
    "url=https://raw.githubusercontent.com/tkimnguyen/plone-in-a-box/${var.release}/src/StackScript",
    "if ! curl -fsSL --retry 10 --retry-delay 5 --retry-all-errors -o /root/plone-in-a-box.sh \"$url\"; then",
    "  echo \"[plone-in-a-box] Could not download $url\" | tee -a /var/log/plone-in-a-box.log >&2",
    "  exit 1",
    "fi",
    "exec bash /root/plone-in-a-box.sh",
  ])

  lifecycle {
    # The region is chosen when the Droplet is created. Availability changes
    # over time, and a later run choosing another region must not replace the
    # Droplet (and delete the site).
    # Terraform never deletes or replaces the server, which would delete the
    # site: terraform destroy and any change that needs a new server stop with
    # an error. DigitalOcean has no deletion protection
    # of its own, so this is the guard. To remove the box on purpose, change
    # this to false, then run terraform destroy.
    prevent_destroy = true

    # Settings used only when the server is created: the user data (the
    # release and settings, read at first boot), the SSH key and the image.
    # Changing them later, or a newer release or Ubuntu image, must not replace
    # the server; plone-update keeps it current.
    ignore_changes = [region, user_data, ssh_keys, image]

    precondition {
      condition     = local.size_found
      error_message = "size: DigitalOcean has no size called ${var.size}. See https://slugs.do-api.dev for the sizes."
    }
    precondition {
      condition     = !local.size_found || local.region != ""
      error_message = "None of preferred_regions (${join(", ", var.preferred_regions)}) offers ${var.size} right now. Regions that do: ${join(", ", local.size_regions)}. Set region or preferred_regions to one of them."
    }
    precondition {
      condition     = local.region == "" || contains(local.size_regions, local.region)
      error_message = "${var.size} isn't offered in ${local.region} right now. Regions that offer it: ${join(", ", local.size_regions)}. Set region to one of these, or leave it empty to choose from preferred_regions."
    }
  }
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

# Alerts, to the account's email unless alert_emails names others.
data "digitalocean_account" "current" {
  count = (var.alerts || var.uptime_check) && length(var.alert_emails) == 0 ? 1 : 0
}

locals {
  alert_emails = length(var.alert_emails) > 0 ? var.alert_emails : [for a in data.digitalocean_account.current : a.email]
  site_url     = var.domain != "" ? "https://${var.domain}" : "http://${digitalocean_droplet.plone.ipv4_address}"
  resource_alerts = {
    disk   = { type = "v1/insights/droplet/disk_utilization_percent", value = 85, window = "5m", what = "Disk over 85% full" }
    memory = { type = "v1/insights/droplet/memory_utilization_percent", value = 90, window = "10m", what = "Memory over 90% for 10 minutes" }
    cpu    = { type = "v1/insights/droplet/cpu", value = 90, window = "30m", what = "CPU over 90% for 30 minutes" }
  }
}

resource "digitalocean_monitor_alert" "plone" {
  for_each    = var.alerts ? local.resource_alerts : {}
  type        = each.value.type
  compare     = "GreaterThan"
  value       = each.value.value
  window      = each.value.window
  entities    = [digitalocean_droplet.plone.id]
  description = "Plone in a Box (${digitalocean_droplet.plone.ipv4_address}): ${each.value.what}"
  enabled     = true
  alerts {
    email = local.alert_emails
  }
}

resource "digitalocean_uptime_check" "plone" {
  count   = var.uptime_check ? 1 : 0
  name    = "Plone in a Box ${var.domain != "" ? var.domain : digitalocean_droplet.plone.ipv4_address}"
  target  = local.site_url
  type    = var.domain != "" ? "https" : "http"
  regions = ["us_east", "us_west", "eu_west", "se_asia"]
  enabled = true
}

resource "digitalocean_uptime_alert" "down" {
  count    = var.uptime_check ? 1 : 0
  check_id = digitalocean_uptime_check.plone[0].id
  name     = "Site down"
  type     = "down_global"
  # DigitalOcean's own values for a down alert, so a later plan shows no change.
  comparison = "less_than"
  threshold  = 1
  period     = "2m"
  notifications {
    email = local.alert_emails
  }
}

resource "digitalocean_uptime_alert" "certificate" {
  count      = var.uptime_check && var.domain != "" ? 1 : 0
  check_id   = digitalocean_uptime_check.plone[0].id
  name       = "Certificate expires within 14 days"
  type       = "ssl_expiry"
  comparison = "less_than"
  threshold  = 14
  period     = "2m"
  notifications {
    email = local.alert_emails
  }
}

output "region" {
  value = digitalocean_droplet.plone.region
}

output "public_ip" {
  value = digitalocean_droplet.plone.ipv4_address
}

output "site_url" {
  value = local.site_url
}

output "alerts_to" {
  value = var.alerts || var.uptime_check ? join(", ", local.alert_emails) : "(alerts off)"
}

# Only needed when admin_password was left empty.
output "credentials_command" {
  value = "ssh root@${digitalocean_droplet.plone.ipv4_address} cat /root/plone-credentials.txt"
}
