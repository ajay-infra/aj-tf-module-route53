# One hosted zone. Called once per zone, in the account that owns the zone.
#
# The apex lives in aj-platform-dns and holds NS delegations only — every
# A, CNAME, TXT the estate needs lives in a delegated per-stage zone in the
# account that serves that stage, written by that account's external-dns and
# cert-manager, which therefore hold rights to exactly one zone each.
# aj-infra-context/arch/account-model.md §6; the SCP that enforces it on the
# apex is protect-dns in aj-tf-module-scps.

resource "aws_route53_zone" "this" {
  name    = var.zone_name
  comment = var.comment != "" ? var.comment : (length(var.delegations) > 0 && !local.private ? "${var.zone_name} — ${var.class}/${var.environment}; delegates ${length(var.delegations)} child zone(s)" : "${var.zone_name} — ${var.class}/${var.environment}")

  dynamic "vpc" {
    for_each = toset(var.vpc_ids)
    content {
      vpc_id = vpc.value
    }
  }

  lifecycle {
    # Deleting a zone re-issues its name servers on re-create; every
    # delegation pointing at it goes dark until the parent is updated.
    # protect-dns denies the API call on the apex; this denies the plan
    # everywhere else. Removing a zone is a deliberate two-step, not a diff.
    prevent_destroy = true

    precondition {
      condition     = !(var.query_logging && local.private)
      error_message = "query_logging is not supported on a private hosted zone (Route 53 limitation). Drop query_logging or vpc_ids."
    }
  }
}

# ── Delegations ──────────────────────────────────────────────────────────────
# One NS record per child zone. TTL 172800 is Route 53's own default for NS
# and is deliberately long: a delegation changes when a child zone is
# re-created, which is rare, and a short TTL here buys nothing but resolver
# load on the apex.

resource "aws_route53_record" "delegation" {
  for_each = var.delegations

  zone_id = aws_route53_zone.this.zone_id
  name    = each.key
  type    = "NS"
  ttl     = 172800
  records = each.value
}

# ── Query logging ────────────────────────────────────────────────────────────
# Public zones only, log group in us-east-1 only — Route 53 writes query logs
# from a service principal, so the log group needs a resource policy that
# lets route53.amazonaws.com put streams and events into it.

resource "aws_cloudwatch_log_group" "query" {
  count = local.query_logging ? 1 : 0

  name              = "/aws/route53/${var.zone_name}"
  retention_in_days = var.query_log_retention_days
}

resource "aws_cloudwatch_log_resource_policy" "query" {
  count = local.query_logging ? 1 : 0

  policy_name = "route53-query-logging-${replace(var.zone_name, ".", "-")}"
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "Route53QueryLogging"
      Effect = "Allow"
      Principal = {
        Service = "route53.amazonaws.com"
      }
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
      ]
      Resource = var.account_id != "" ? "arn:aws:logs:us-east-1:${var.account_id}:log-group:/aws/route53/*" : "arn:aws:logs:us-east-1:*:log-group:/aws/route53/*"
    }]
  })
}

resource "aws_route53_query_log" "this" {
  count = local.query_logging ? 1 : 0

  zone_id                  = aws_route53_zone.this.zone_id
  cloudwatch_log_group_arn = aws_cloudwatch_log_group.query[0].arn

  depends_on = [aws_cloudwatch_log_resource_policy.query]
}
