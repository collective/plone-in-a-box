# Plone in a Box(TM) on Amazon EC2.
#
#   cd src/aws
#   terraform init
#   terraform apply -var 'ssh_public_key_path=~/.ssh/id_ed25519.pub'
#
# The instance provisions itself on first boot: its user data downloads
# src/StackScript from the Plone in a Box release named in var.release and
# runs it; that takes about 10 minutes. Follow it with:
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

variable "deletion_protection" {
  description = "Termination protection: AWS refuses to terminate the instance, from Terraform, the EC2 console or anything else. To remove the box on purpose, set this to false and run terraform apply, change prevent_destroy to false in this file, then run terraform destroy."
  type        = bool
  default     = true
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
  description = "Start the site with Plone's welcome page (or a Plone distribution's own sample content); false starts with an empty site."
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

variable "log_server" {
  description = "Optional: a syslog server or service that gets the server's logs too, as HOST:PORT over TLS (see Sending the logs elsewhere in the setup guide)."
  type        = string
  default     = ""
}

variable "log_token" {
  description = "The token element your log service wants in each message, in brackets, as the service gives it. Empty if it needs none."
  type        = string
  default     = ""
  sensitive   = true
}

variable "log_requests" {
  description = "Send one line per web request too, which is most of the volume."
  type        = bool
  default     = false
}

variable "metrics_endpoint" {
  description = "Optional: an OpenTelemetry service's OTLP endpoint that gets the server's and the site's numbers, such as https://otlp-gateway-prod-us-east-2.grafana.net/otlp (see Graphs of your server and site in the setup guide)."
  type        = string
  default     = ""
}

variable "metrics_user" {
  description = "Your instance ID or user (Grafana Cloud), or header:NAME for a service that takes the token in a header (header:api-key for New Relic)."
  type        = string
  default     = ""
}

variable "control_panel" {
  description = "Turn on the control panel (preview): a page in your browser that shows how your site is doing, with a few buttons, at https://<your site>:8443. Its login is saved next to the admin password."
  type        = bool
  default     = false
}

variable "metrics_token" {
  description = "The OpenTelemetry service's token."
  type        = string
  default     = ""
  sensitive   = true
}

variable "auto_update" {
  description = "Install Plone, Volto and PostgreSQL patch releases every week, after a database backup, and undo them if the site doesn't come back."
  type        = bool
  default     = true
}

variable "release" {
  description = "The Plone in a Box release whose setup script the server downloads from GitHub at first boot. To try unreleased changes, set a branch or commit that's pushed to GitHub."
  type        = string
  default     = "2.26"

  validation {
    condition     = can(regex("^[A-Za-z0-9._/-]+$", var.release))
    error_message = "release: a release, branch or commit, such as 2.26."
  }
}

variable "volume_size_gb" {
  description = "Size of the root disk in GB."
  type        = number
  default     = 20
}

variable "backups" {
  description = "Daily snapshots of the server's disk through AWS Data Lifecycle Manager, the newest 7 kept (extra cost)."
  type        = bool
  default     = false
}

provider "aws" {
  region = var.region
}

# Latest Ubuntu 26.04 LTS image published by Canonical for this region.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-resolute-26.04-amd64-server-*"]
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

  # The control panel on a site without a domain name: nothing answers until
  # you turn it on (sudo plone-panel on).
  ingress {
    description      = "Plone in a Box control panel"
    from_port        = 8443
    to_port          = 8443
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

  # The plone-in-a-box tag is what the snapshot policy below looks for (when
  # backups is on). The key pair's generated name is unique to this
  # deployment, so another server's policy in the same account doesn't
  # snapshot this one too.
  tags = {
    Name             = "Plone in a Box"
    "plone-in-a-box" = aws_key_pair.deployer.key_name
  }

  metadata_options {
    http_tokens = "required" # IMDSv2 only
  }

  # The settings as environment variables, then the release's setup script,
  # downloaded from GitHub like the Launch Stack template does. The script is
  # larger than EC2's 16 KB user data limit, so it isn't embedded.
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
    "export LOG_SERVER=\"$(echo ${base64encode(var.log_server)} | base64 -d)\"",
    "export LOG_TOKEN=\"$(echo ${base64encode(var.log_token)} | base64 -d)\"",
    "export LOG_REQUESTS=${var.log_requests ? "yes" : "no"}",
    "export METRICS_ENDPOINT=\"$(echo ${base64encode(var.metrics_endpoint)} | base64 -d)\"",
    "export METRICS_USER=\"$(echo ${base64encode(var.metrics_user)} | base64 -d)\"",
    "export METRICS_TOKEN=\"$(echo ${base64encode(var.metrics_token)} | base64 -d)\"",
    "export CONTROL_PANEL=${var.control_panel ? "yes" : "no"}",
    "url=https://raw.githubusercontent.com/tkimnguyen/plone-in-a-box/${var.release}/src/StackScript",
    "if ! curl -fsSL --retry 10 --retry-delay 5 --retry-all-errors -o /root/plone-in-a-box.sh \"$url\"; then",
    "  echo \"[plone-in-a-box] Could not download $url\" | tee -a /var/log/plone-in-a-box.log >&2",
    "  exit 1",
    "fi",
    "exec bash /root/plone-in-a-box.sh",
  ])
  user_data_replace_on_change = false
  disable_api_termination     = var.deletion_protection


  lifecycle {
    # Terraform never deletes or replaces the server, which would delete the
    # site: terraform destroy and any change that needs a new server stop with
    # an error. To remove the box on purpose, see deletion_protection.
    prevent_destroy = true

    # Settings used only when the server is created: the user data (the
    # release and settings, read at first boot), the SSH key and the image.
    # Changing them later, or a newer release or Ubuntu image, must not replace
    # the server; plone-update keeps it current.
    ignore_changes = [ami, user_data, user_data_base64, key_name]
  }
}

# Daily snapshots of the disk (backups = true): AWS Data Lifecycle Manager,
# with the role it needs. The newest 7 are kept; see EC2 > Snapshots. Turning
# backups off removes the policy, and leaves the snapshots taken.
resource "aws_iam_role" "snapshots" {
  count       = var.backups ? 1 : 0
  name_prefix = "plone-in-a-box-snapshots-"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "dlm.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "snapshots" {
  count      = var.backups ? 1 : 0
  role       = aws_iam_role.snapshots[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSDataLifecycleManagerServiceRole"
}

resource "aws_dlm_lifecycle_policy" "snapshots" {
  count              = var.backups ? 1 : 0
  description        = "Plone in a Box daily snapshots ${aws_key_pair.deployer.key_name}"
  execution_role_arn = aws_iam_role.snapshots[0].arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["INSTANCE"]
    target_tags = {
      "plone-in-a-box" = aws_key_pair.deployer.key_name
    }

    schedule {
      name      = "Daily newest 7 kept"
      copy_tags = true

      # After the nightly database backup (00:15 server time), so a snapshot
      # holds it too.
      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = ["03:00"]
      }

      retain_rule {
        count = 7
      }
    }
  }

  depends_on = [aws_iam_role_policy_attachment.snapshots]
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
