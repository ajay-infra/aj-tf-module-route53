# Changelog

All notable changes to this module are documented here. Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added — v0.1.0, the first version
One hosted zone per call, in the account that owns it. Apex-with-delegations and delegated-child are the same resource with different inputs; the shape is the tree in `account-model.md` §6.

- `aws_route53_zone` with `prevent_destroy`; private when `vpc_ids` is set.
- NS delegations from a `{ child => name_servers }` map, validated as children of the zone, TTL 172800.
- Optional query logging: log group + the resource policy Route 53 needs + `aws_route53_query_log`, us-east-1, public zones only (precondition).
- Tags: the base set plus `Application = dns`, `Class`, `Customer`, `Zone` — the emit side the SaaS tag guardrail waits on.
- Plans offline: no data sources; `account_id` is a variable for the one policy that would otherwise need one.
- CI plans `example.tfvars`, `envs/apex.tfvars` and `envs/nonprod.tfvars` and asserts the zone is in each plan.

Closes the gap `aj-infra/mocks.yaml` has carried since the Z0MOCK ids were declared: "Nothing in the estate creates these zones."
