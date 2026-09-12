# THE APEX — in aj-platform-dns (777777777777 — MOCK). NS delegations only.
# protect-dns (aj-tf-module-scps >= v0.4.0) denies every other write here to
# every principal but dns_pipeline_role_arns.
#
# The apex name is still the estate's oldest naming decision
# (account-model.md §9): mocks.yaml models four registered apexes
# (nonprod-aj.io, preprod-aj.io, prod-aj.io, prodpci-aj.io); the account
# model recommends ONE apex with delegated per-stage subzones. This file is
# written for the recommended shape and uses the mock vocabulary for the
# apex itself. Change the names when the apex is registered, not before.
zone_name   = "aj.io" # MOCK — the registered apex is undecided
comment     = "apex — NS delegations only; every record lives in a delegated per-stage zone"
environment = "prod" # governed as production: it is the one zone every hostname descends from
class       = "platform"
customer    = "internal"
team        = "infra-core"
cost_center = "infra-2026-q1"

# Child first. Each list below is the child zone's `name_servers` output,
# read from the plan/apply in the child's account and copied here. Under
# Stage 1 none are knowable — Route 53 assigns them at create — so these are
# MOCK name servers in the shape Route 53 uses, declared as such.
delegations = {
  "nonprod.aj.io" = ["ns-mock-1.awsdns-00.org", "ns-mock-2.awsdns-00.co.uk", "ns-mock-3.awsdns-00.com", "ns-mock-4.awsdns-00.net"]
  "prod.aj.io"    = ["ns-mock-5.awsdns-00.org", "ns-mock-6.awsdns-00.co.uk", "ns-mock-7.awsdns-00.com", "ns-mock-8.awsdns-00.net"]
}

query_logging            = true
query_log_retention_days = 90
account_id               = "777777777777" # MOCK — not a real AWS identifier
