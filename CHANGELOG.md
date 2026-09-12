# Changelog

All notable changes to this module are documented here. Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added — the pipeline role, DNSSEC, DS delegations (ported from the retired aj-tf-module-dns)
Two modules for one resource were created six minutes apart on 2026-09-12. This one survives — the name matches every other module's — and the three things the other had that this lacked come across here.

- **`create_pipeline_role`** (apex only, default off) creates the IAM role `protect-dns` exempts — `dns-pipeline`, scoped to **this zone's ARN** and to record changes; no zone create/delete, no `kms:*`. Its name is a contract with `aj-infra/envs/org/platform/scps.tfvars`; CI asserts the apex plan creates it. `pipeline_trust_principal_arns` is required when on — a role nobody can assume fails the plan with a sentence. This moves the role out of "belongs with the account bootstrap" (README §Open, now closed): its policy is scoped to a zone ARN only this module knows, and a role created elsewhere would be scoped to `hostedzone/*`, the over-grant DNS was split out to end.
- **`dnssec`** (default off): KMS key (ECC_NIST_P256, SIGN_VERIFY, us-east-1), key-signing key, signing enabled, `ds_record` output. Needs `account_id` — the key policy's admin principal is built from it so the module still reads nothing live. The two steps it cannot perform are named on the variable: the apex DS at the registrar, and a child's DS into its parent.
- **`delegation_ds_records`** — DS per delegated child, validated against `delegations`. A parent with dnssec off can still carry DS for a signed child.
- **Precondition**: `query_logging` or `dnssec` with `aws_region != us-east-1` fails the plan. The log group and the KSK are regional and Route 53 accepts them only there; the previous text said the module "creates it there regardless", which one provider cannot do.
- **CI shape assertions**: the apex plan must create the pipeline role and write nothing but NS/DS; a stage-zone plan must not create the role.


### Added — v0.1.0, the first version
One hosted zone per call, in the account that owns it. Apex-with-delegations and delegated-child are the same resource with different inputs; the shape is the tree in `account-model.md` §6.

- `aws_route53_zone` with `prevent_destroy`; private when `vpc_ids` is set.
- NS delegations from a `{ child => name_servers }` map, validated as children of the zone, TTL 172800.
- Optional query logging: log group + the resource policy Route 53 needs + `aws_route53_query_log`, us-east-1, public zones only (precondition).
- Tags: the base set plus `Application = dns`, `Class`, `Customer`, `Zone` — the emit side the SaaS tag guardrail waits on.
- Plans offline: no data sources; `account_id` is a variable for the one policy that would otherwise need one.
- CI plans `example.tfvars`, `envs/apex.tfvars` and `envs/nonprod.tfvars` and asserts the zone is in each plan.

Closes the gap `aj-infra/mocks.yaml` has carried since the Z0MOCK ids were declared: "Nothing in the estate creates these zones."
