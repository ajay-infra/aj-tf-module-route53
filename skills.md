# skills.md — aj-tf-module-route53

Read by `aj-skill-farm`. What a skill needs to know to change this module.

- **Tag on `main`** after merge, `vX.Y.Z`; consumers pin `dns_module_tag`.
- **Adding a delegation** is a tfvars change in the PARENT's env file, after
  the child exists and its `name_servers` output has been read. Never in the
  child.
- **Never remove `prevent_destroy`.** If a zone genuinely has to go, the
  two-step is: remove every delegation pointing at it in its parent, apply
  that, then remove the zone with `-target` and an explicit override.
- **A new zone** is a new `envs/<name>.tfvars` here (for the module's own
  CI) and a new entry in `aj-infra/envs/dns/` (for the pipeline). Both.
