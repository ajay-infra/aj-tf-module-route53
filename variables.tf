# ── The zone ─────────────────────────────────────────────────────────────────

variable "zone_name" {
  type        = string
  description = <<-EOT
    The hosted zone's name, without a trailing dot. The apex ("aj.io") in
    aj-platform-dns; a delegated child ("nonprod.aj.io", "acme.saas.aj.io")
    in the account that serves that stage or customer.
  EOT
  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,}$", var.zone_name))
    error_message = "zone_name must be a fully-qualified DNS name, lowercase, no trailing dot."
  }
}

variable "comment" {
  type        = string
  description = "Hosted zone comment. Say what the zone is FOR — 'apex, NS delegations only' or 'nonprod stage, written by external-dns on dev'."
  default     = ""
}

variable "vpc_ids" {
  type        = list(string)
  description = <<-EOT
    Non-empty makes this a PRIVATE hosted zone associated with these VPCs —
    resolvable only from inside them. Empty (the default) is a public zone.
    A stage's private zone (hub-internal names, VPN-only endpoints) is a
    second module call beside its public one, not a flag on the same zone.
  EOT
  default     = []
}

# ── Delegations — the apex's whole job ───────────────────────────────────────

variable "delegations" {
  type        = map(list(string))
  description = <<-EOT
    Child zones this zone delegates, as { "child.zone.name" = [name servers] }.
    The name servers come from the child zone's `name_servers` output, in the
    account that owns it. One NS record per entry, TTL 172800 (2 days, the
    Route 53 default for NS).

    On the apex this map IS the zone's content: per account-model.md §6 the
    apex holds NS delegations and nothing else, and protect-dns denies every
    other write. A stage zone may delegate too ("acme.saas.aj.io" under
    "saas.aj.io"), which is how a dedicated customer's account gets its zone.

    The order of operations is child first: create the child zone, read its
    four name servers, then add the delegation here. Nothing in this module
    can reach across accounts to read them, deliberately.
  EOT
  default     = {}

  validation {
    condition = alltrue([
      for child, ns in var.delegations : length(ns) >= 2 && length(ns) <= 4
    ])
    error_message = "Each delegation needs the child zone's name servers — Route 53 assigns four; two is the minimum a resolver will accept."
  }

  validation {
    condition = alltrue([
      for child, ns in var.delegations : endswith(child, ".${var.zone_name}")
    ])
    error_message = "A delegation must be a child of this zone: '<label>.<zone_name>'. A delegation for an unrelated name is not a delegation, it is a typo."
  }
}

# ── Query logging ────────────────────────────────────────────────────────────

variable "query_logging" {
  type        = bool
  description = <<-EOT
    Ship every query the zone answers to a CloudWatch log group. Public zones
    only — Route 53 does not support query logging on private zones. The log
    group must be in us-east-1; this module creates it there regardless of
    aws_region, plus the resource policy Route 53 needs to write to it.
  EOT
  default     = false
}

variable "query_log_retention_days" {
  type        = number
  description = "Retention for the query log group. 30 for nonprod, 90+ where an audit trail is expected."
  default     = 30
}

variable "account_id" {
  type        = string
  description = <<-EOT
    The account this zone lives in. Used ONLY to scope the CloudWatch
    resource policy when query_logging is on — the module reads nothing live,
    so it cannot discover its own account id. Twelve digits; a MOCK under
    Stage 1, declared in aj-infra/mocks.yaml and named in
    envs/org/accounts.yaml.
  EOT
  default     = ""
  validation {
    condition     = var.account_id == "" || can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be twelve digits."
  }
}

# ── Identity and tags ────────────────────────────────────────────────────────

variable "aws_region" {
  type        = string
  description = "Provider region. Route 53 is global; only the query-log group is regional, and it is always us-east-1."
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Stage the zone is governed as — nonprod | preprod | prod | prodpciconn. The Environment tag. The apex, in a lifecycle-less platform account, is tagged prod: it is governed as production."
  validation {
    condition     = contains(["nonprod", "sandbox", "preprod", "prod", "prodpciconn"], var.environment)
    error_message = "environment must be one of the stage vocabulary: nonprod, sandbox, preprod, prod, prodpciconn."
  }
}

variable "class" {
  type        = string
  description = "Which stack the zone belongs to — platform (the apex), product, saas. The Class tag; matches the account's class segment."
  validation {
    condition     = contains(["platform", "product", "saas"], var.class)
    error_message = "class must be platform, product or saas."
  }
}

variable "customer" {
  type        = string
  description = "The Customer tag — 'internal' for everything that is not a dedicated SaaS customer's zone, the customer slug otherwise. Derived from the account, never a free choice (tag-profiles.md §5.5)."
  default     = "internal"
}

variable "team" {
  type        = string
  description = "Owning team slug — the Team tag."
}

variable "cost_center" {
  type        = string
  description = "Chargeback code — the CostCenter tag."
}

variable "tags" {
  type        = map(string)
  description = "Additional tags, merged over the module's set. A key here overrides the module's value — including the ones the tag guardrails require, so be sure."
  default     = {}
}
