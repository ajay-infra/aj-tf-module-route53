output "zone_id" {
  description = "Hosted zone id — what external-dns, cert-manager's DNS-01 solver and the CloudFront module are given. Replaces the Z0MOCK* ids in aj-infra/mocks.yaml on the day this applies."
  value       = aws_route53_zone.this.zone_id
}

output "zone_arn" {
  description = "Hosted zone ARN — for IAM policies that scope a writer to exactly this zone."
  value       = aws_route53_zone.this.arn
}

output "zone_name" {
  description = "The zone name, undotted, as given."
  value       = var.zone_name
}

output "name_servers" {
  description = <<-EOT
    The four name servers Route 53 assigned. For a delegated child zone this
    is the value the PARENT needs in its `delegations` map — copy it into the
    parent's tfvars in the parent's account. For the apex it is what the
    registrar needs. Route 53 assigns these at create time and they are not
    knowable at plan.
  EOT
  value       = aws_route53_zone.this.name_servers
}

output "private" {
  description = "Whether this is a private hosted zone (vpc_ids was non-empty)."
  value       = local.private
}

output "delegated_children" {
  description = "The child zones this zone delegates — the map's keys, so a parent's plan says what it points at."
  value       = sort(keys(var.delegations))
}

output "query_log_group_name" {
  description = "The query log group, when query_logging is on; null otherwise."
  value       = local.query_logging ? aws_cloudwatch_log_group.query[0].name : null
}
