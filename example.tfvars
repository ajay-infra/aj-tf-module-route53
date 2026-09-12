# The nonprod stage zone, in aj-product-core-nonprod (444444444444 — MOCK).
# Delegated from the apex, written by dev's external-dns and cert-manager.
zone_name   = "nonprod-aj.io" # MOCK apex vocabulary — see aj-infra/mocks.yaml dns_zones
comment     = "nonprod stage — written by external-dns and cert-manager on dev; delegated from the apex"
environment = "nonprod"
class       = "product"
customer    = "internal"
team        = "infra-core"
cost_center = "infra-2026-q1"

# A stage zone may itself delegate. Empty here; the apex's tfvars carry the
# stage delegations, and this is where a dedicated customer's zone would go.
delegations = {}

query_logging            = true
query_log_retention_days = 30
account_id               = "444444444444" # MOCK — not a real AWS identifier
