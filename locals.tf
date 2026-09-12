locals {
  # Route 53 answers with the zone name dotted; inputs are undotted. Keep the
  # convention at the boundary so callers never see a trailing dot.
  zone_fqdn = "${var.zone_name}."

  private = length(var.vpc_ids) > 0

  # Query logging is public-zone only and the log group is us-east-1 only.
  # Both are Route 53's rules, not ours; the plan fails early rather than
  # the apply failing late.
  query_logging = var.query_logging && !local.private

  full_tags = merge({
    # The estate's base set — see aj-skill-farm/rules/tagging.yaml.
    Project     = "aj-tf-module-route53"
    ManagedBy   = "Terraform"
    Repository  = "aj-tf-module-route53"
    Environment = var.environment
    Team        = var.team
    CostCenter  = var.cost_center
    Application = "dns"
    # The two keys the SaaS guardrail waits on modules to emit
    # (tag-profiles.md §5.6 step 1). Class is the account's class; Customer is
    # internal unless this is a dedicated customer's own zone.
    Class    = var.class
    Customer = var.customer
    Zone     = var.zone_name
  }, var.tags)
}
