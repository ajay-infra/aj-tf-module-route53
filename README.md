# aj-tf-module-route53

One Route 53 hosted zone, called once per zone, in the account that owns it.

The estate's DNS is a tree with a rule at each level
(`aj-infra-context/arch/account-model.md` §6):

```
aj.io                        aj-platform-dns          NS delegations ONLY — protect-dns denies every other write
├── nonprod.aj.io            aj-product-core-nonprod  written by dev's external-dns + cert-manager
├── preprod.aj.io            aj-product-core-preprod
├── prod.aj.io               aj-product-core-prod
├── prodpci.aj.io            aj-product-regulated-prodpciconn
└── saas.aj.io               (a SaaS stage zone)
    └── acme.saas.aj.io      aj-saas-acme-prod        the dedicated customer's own zone
```

Each writer — external-dns, cert-manager's DNS-01 solver — therefore holds
rights to exactly one zone, in its own account. A dev misconfiguration cannot
reach a prod record by any path short of a cross-account role. The apex, the
one zone every hostname descends from, lives where nobody's workloads run and
where an SCP denies record writes to every principal but the DNS pipeline's.

## What it creates

| Resource | When | What |
|---|---|---|
| `aws_route53_zone.this` | always | the zone; private when `vpc_ids` is non-empty; `prevent_destroy` |
| `aws_route53_record.delegation[*]` | per `delegations` entry | one NS record per child zone, TTL 172800 |
| `aws_cloudwatch_log_group.query` · `_resource_policy` · `aws_route53_query_log` | `query_logging` on a public zone | query logs in us-east-1, the only region Route 53 writes them to |

**Plans offline.** No data sources, no live reads — `terraform plan` with
dummy credentials is a real diff. `aws_route53_zone` needs no API call at
plan; only the name servers are unknowable until apply.

## Order of operations — child first

Route 53 assigns a zone's four name servers at create time. A parent can only
delegate to name servers it knows. So:

1. Plan and apply the **child** zone in its account. Read `name_servers`.
2. Copy them into the **parent's** `delegations` map, in the parent's account.
3. Plan and apply the parent.

Nothing in this module reaches across accounts to read them, deliberately —
that would be a credential path from the apex account into every stage. Under
Stage 1 the delegations in `envs/apex.tfvars` are mock name servers in the
shape Route 53 uses, marked as such.

## Guardrails this module carries and relies on

- **`prevent_destroy`** on the zone. Deleting a zone re-issues its name
  servers on re-create, and every delegation pointing at it goes dark until
  the parent is updated. Removing a zone is a deliberate two-step, not a diff.
- **`delegations` must be children of `zone_name`** — a delegation for an
  unrelated name is a typo, and the validation says so.
- **Query logging on a private zone fails the plan**, not the apply. Route 53
  does not support it; the precondition says why.
- **On the apex, `protect-dns`** (`aj-tf-module-scps` ≥ v0.4.0) denies zone
  deletion, record writes, VPC disassociation and the registrar-side escapes
  to every principal except `dns_pipeline_role_arns`. This module's pipeline
  role must be one of those, or its own applies are denied.

## Tags

Emits the estate's base set plus `Application = dns`, `Class`, `Customer`
and `Zone`. `Class` and `Customer` are the two keys the SaaS tag guardrail
waits on modules to emit (`tag-profiles.md` §5.6 step 1). `Customer` is
`internal` for every zone that is not a dedicated customer's own.

## Usage

```hcl
module "nonprod_zone" {
  source = "git::https://github.com/ajay-infra/aj-tf-module-route53.git?ref=v0.1.0"

  zone_name   = "nonprod.aj.io"
  environment = "nonprod"
  class       = "product"
  team        = "infra-core"
  cost_center = "infra-2026-q1"

  query_logging = true
  account_id    = "444444444444" # the account the zone lives in; MOCK under Stage 1
}
```

`envs/apex.tfvars` and `envs/nonprod.tfvars` are the two shapes this module
has; CI plans both plus `example.tfvars`.

## Open

- **The apex name.** `aj-infra/mocks.yaml` models four registered apexes;
  the account model recommends one with delegated subzones. This module is
  written for the recommended shape and uses the mock vocabulary. Decide at
  registration, then change the mocks and these tfvars together.
- **DNSSEC.** Not in v0.1.0. It needs a KMS key in us-east-1 and a
  key-signing key per zone, and it changes what "re-create the zone" costs.
  Worth a version of its own once the apex is real.
- **The DNS pipeline role.** `protect-dns` exempts `dns_pipeline_role_arns`;
  nothing creates that role yet. It belongs with the account bootstrap, not
  in this module.
