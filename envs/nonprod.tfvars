# nonprod stage zone — in aj-product-core-nonprod (444444444444 — MOCK),
# delegated from the apex. dev's external-dns (policy sync) and cert-manager
# (DNS-01) hold rights to THIS zone and no other.
zone_name   = "nonprod.aj.io" # MOCK — child of the undecided apex
comment     = "nonprod stage — written by external-dns and cert-manager on dev"
environment = "nonprod"
class       = "product"
customer    = "internal"
team        = "infra-core"
cost_center = "infra-2026-q1"

delegations = {}

query_logging            = true
query_log_retention_days = 30
account_id               = "444444444444" # MOCK — not a real AWS identifier
