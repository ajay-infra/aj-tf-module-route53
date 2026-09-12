# ── The pipeline role — apex only ─────────────────────────────────────────────
# protect-dns (aj-tf-module-scps >= v0.4.0) denies record writes and zone
# deletion in the DNS account to every principal except the ARNs in
# aj-infra/envs/org/platform/scps.tfvars -> dns_pipeline_role_arns. This is
# that role. Its name is a contract with that file: if the two disagree, the
# pipeline denies itself and no delegation can ever be written.
#
# Why it lives here and not with the account bootstrap: its policy is scoped
# to THIS zone's ARN, which only this module knows, and the SCP exemption is a
# property of the zone's owner. A role created elsewhere would be scoped to
# hostedzone/* — the exact over-grant the account model split DNS out to end.
#
# Scope: record changes on this zone, read-only listing. It cannot create or
# delete a zone (deletion is SCP-denied regardless) and has no kms:* — the
# DNSSEC key in dnssec.tf is administered by the account, never by the
# record writer.

data "aws_iam_policy_document" "pipeline_trust" {
  # Also gated on the trust list being non-empty: an empty `identifiers` is a
  # provider error with a worse message than the role's precondition below.
  count = var.create_pipeline_role && length(var.pipeline_trust_principal_arns) > 0 ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = var.pipeline_trust_principal_arns
    }
  }
}

data "aws_iam_policy_document" "pipeline" {
  count = var.create_pipeline_role ? 1 : 0

  statement {
    sid    = "ChangeRecordsInThisZone"
    effect = "Allow"
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:GetHostedZone",
      "route53:ListResourceRecordSets",
    ]
    resources = [aws_route53_zone.this.arn]
  }
  statement {
    sid       = "ReadOnlyAcrossRoute53"
    effect    = "Allow"
    actions   = ["route53:ListHostedZones", "route53:ListHostedZonesByName", "route53:GetChange", "route53:GetDNSSEC"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "pipeline" {
  count = var.create_pipeline_role ? 1 : 0

  name               = var.pipeline_role_name
  assume_role_policy = try(data.aws_iam_policy_document.pipeline_trust[0].json, "{}") # the precondition below is the real guard
  description        = "The only principal protect-dns lets write ${var.zone_name}. Record changes on that zone only."

  lifecycle {
    precondition {
      condition     = length(var.pipeline_trust_principal_arns) > 0
      error_message = "create_pipeline_role is true but pipeline_trust_principal_arns is empty. A role nobody can assume is not a pipeline; decide the trust (Stage 2: the GitHub OIDC principal) or set create_pipeline_role = false."
    }
    precondition {
      condition     = !local.private
      error_message = "create_pipeline_role is for the apex. A private zone is never the apex and protect-dns never applies to it."
    }
  }
}

resource "aws_iam_role_policy" "pipeline" {
  count = var.create_pipeline_role ? 1 : 0

  name   = "${var.pipeline_role_name}-${replace(var.zone_name, ".", "-")}"
  role   = aws_iam_role.pipeline[0].id
  policy = data.aws_iam_policy_document.pipeline[0].json
}
