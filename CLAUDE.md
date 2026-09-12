# CLAUDE.md — aj-tf-module-route53

> Local context file for Claude Code.

## What This Module Does

One Route 53 hosted zone per call, in the account that owns it. The apex in
`aj-platform-dns` holds NS delegations only; per-stage zones are delegated
into the workload account that serves that stage, so external-dns and
cert-manager hold rights to one zone each. `aj-infra-context/arch/account-model.md` §6.

## Module Structure

```
main.tf      → aws_route53_zone (prevent_destroy), aws_route53_record NS
               delegations, optional query logging (log group + resource
               policy + aws_route53_query_log)
locals.tf    → private?, query_logging gate, full_tags
variables.tf → zone_name, vpc_ids, delegations (validated as children),
               query_logging, account_id, environment/class/customer/team/cost_center
outputs.tf   → zone_id, zone_arn, name_servers (the value a PARENT needs),
               delegated_children, query_log_group_name
providers.tf → aws 5.100.0, skip_* flags — plans offline
envs/        → apex.tfvars (aj-platform-dns), nonprod.tfvars (aj-product-core-nonprod)
```

## Key Design Decisions

- **One zone per call, one state per zone, in the owning account.** Never
  cross-account. The apex cannot read a child's name servers; a human copies
  them. That is the point.
- **The apex holds NS records only.** Enforced by `protect-dns` in
  `aj-tf-module-scps`, not by this module — this module only refuses to
  delegate a name that is not a child.
- **`prevent_destroy`.** Re-creating a zone re-issues name servers and breaks
  every delegation to it.
- **No data sources.** Plans with dummy credentials. `account_id` is a
  variable for the one place (the query-log resource policy) that would
  otherwise need `aws_caller_identity`.
- **Query logging is us-east-1 only and public-zone only.** Route 53's rules;
  the precondition fails the plan rather than the apply.

## Stage 1

Nothing applies. `envs/apex.tfvars` carries MOCK name servers in the
delegations map because Route 53 assigns real ones at create. `account_id`
and the apex name are mocks declared in `aj-infra/mocks.yaml`.

## Consumers

None yet. The consumer is `aj-infra` — a `provision-dns.yml` plan pipeline
over `envs/dns/`, and `dns_module_tag` in `versions.yaml`. The Z0MOCK zone
ids in `mocks.yaml` are what this module's `zone_id` output replaces.
