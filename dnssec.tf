# ── DNSSEC ────────────────────────────────────────────────────────────────────
# One asymmetric KMS key (ECC_NIST_P256, SIGN_VERIFY, us-east-1 — Route 53's
# rule), one key-signing key, signing enabled. Off by default. Two steps this
# cannot perform, named where the variable is: the apex's DS at the REGISTRAR
# (manual, and protect-dns denies route53domains to everyone), and a child's
# DS into its parent — that is the parent's `delegation_ds_records` input,
# fed from this zone's `ds_record` output, by value like the name servers.
#
# No data source: the key policy's admin principal is built from
# var.account_id, the same way the query-log policy is. That keeps this
# module planning offline, which is the property the estate depends on.

resource "aws_kms_key" "dnssec" {
  count = var.dnssec ? 1 : 0

  description              = "${var.zone_name} Route 53 DNSSEC key-signing key"
  customer_master_key_spec = "ECC_NIST_P256"
  key_usage                = "SIGN_VERIFY"
  deletion_window_in_days  = 30
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowRoute53DNSSEC"
        Effect    = "Allow"
        Principal = { Service = "dnssec-route53.amazonaws.com" }
        Action    = ["kms:DescribeKey", "kms:GetPublicKey", "kms:Sign"]
        Resource  = "*"
      },
      {
        Sid       = "AllowRoute53DNSSECGrant"
        Effect    = "Allow"
        Principal = { Service = "dnssec-route53.amazonaws.com" }
        Action    = ["kms:CreateGrant"]
        Resource  = "*"
        Condition = { Bool = { "kms:GrantIsForAWSResource" = "true" } }
      },
      {
        # Key administration stays with the account. The pipeline role in
        # iam.tf has no kms:* on purpose.
        Sid       = "AccountAdmin"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${var.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
    ]
  })

  lifecycle {
    precondition {
      condition     = var.account_id != ""
      error_message = "dnssec needs account_id: the key policy's admin principal is built from it, because this module reads nothing live."
    }
    precondition {
      condition     = !local.private
      error_message = "A private hosted zone cannot be DNSSEC-signed (Route 53 limitation). Drop dnssec or vpc_ids."
    }
  }
}

resource "aws_kms_alias" "dnssec" {
  count = var.dnssec ? 1 : 0

  name          = "alias/route53-dnssec-${replace(var.zone_name, ".", "-")}"
  target_key_id = aws_kms_key.dnssec[0].key_id
}

resource "aws_route53_key_signing_key" "this" {
  count = var.dnssec ? 1 : 0

  hosted_zone_id             = aws_route53_zone.this.zone_id
  key_management_service_arn = aws_kms_key.dnssec[0].arn
  name                       = replace("${var.zone_name}-ksk", ".", "-")
}

resource "aws_route53_hosted_zone_dnssec" "this" {
  count = var.dnssec ? 1 : 0

  hosted_zone_id = aws_route53_key_signing_key.this[0].hosted_zone_id

  depends_on = [aws_route53_key_signing_key.this]
}

# The DS records that make a signed CHILD's chain of trust reach this zone.
# Only present for children whose owner enabled dnssec and handed the
# ds_record up; a parent with dnssec off can still carry DS for a signed child.
resource "aws_route53_record" "delegation_ds" {
  for_each = var.delegation_ds_records

  zone_id = aws_route53_zone.this.zone_id
  name    = each.key
  type    = "DS"
  ttl     = 172800
  records = each.value

  lifecycle {
    precondition {
      condition     = contains(keys(var.delegations), each.key)
      error_message = "delegation_ds_records names ${each.key}, which is not in delegations. A DS without an NS is a chain of trust to nowhere."
    }
  }
}
