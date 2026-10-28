# PokePackBar 0.25.0

App PRs #28/#29/#30 and server PRs #19/#20 add daily price news/history,
rebalance dex rewards and keep native layout audits quiet.

## Changes

- Concentrate permanent theme perks in 56 five-star combinations, raise token
  gain's cap to 40%, increase one-time rewards and add 225/275 completion steps.
  Existing resource ledgers and claimed rewards are preserved without regranting.
- Add daily risers/fallers/owned-card changes and 30/90/all history popovers for
  cards, printings and packs. Initial notification setup establishes a baseline;
  notable owned-card rises notify at most once per recorded day.
- Quiet audits keep windows transparent, click-through and inactive while still
  checking real close/reopen behavior. Normal presentation remains unchanged.
- Review repair: clear owned-price reports on logout/401 and reject late replies.
  Existing refresh-policy tests missed the authentication boundary; a production-
  path regression and a failing generation-guard mutation now cover it.

## Verification

- Focused app suite: 39 passed. Full local suite: 1050 tests, 9 skipped, zero
  failures. Logic-core coverage 88.90% clears the 75% gate.
- Server: 310 passed plus all 94 opt-in Swift/Python comparisons passed; Ruff
  passes. Rules data matches the reviewed Swift candidate.
- Production-copy migration preserves every prior column/row in 27 tables and
  all three accounts' balances, cards/printings, packs, coupons, pity and claims.
- Thirty stored snapshots backfill to 30 days and 505571 changed-value points;
  30/90/all history windows pass without touching the live database.
- Synthetic old-to-new restart covers schema 0009->0010, preserved sessions and
  resources, replay of already committed draws without redraw, stale new-command
  rejection without mutation and successful commands with the new rules.
- Native HTTP audits decode the actual movers/history responses (including an
  encoded printing key), clear reports after 401, and pass profile/alerts,
  commerce/counter-offers, 1001-pack jobs and durable replay.
- Korean/English native snapshots cover news, history, empty/error states and
  existing popover layouts. Quiet account/online audits pass. Screenshot fixtures
  establish layout; live mouse-hover interaction has not been manually audited.
- Package/signature, final main CI and live cutover evidence are recorded in the
  GitHub release after completion.

## Deployment and rollback

- Server source: `f1492eecba1c65d3fa9fc0382874dd9b96615fed`.
- New rules:
  `ppb-server-v2/d11bc98b4915acd13f1bf8262da869727def6ae1a42631211d69c2bb3ab4e1a2`.
  Schema becomes `20261023_0010`. Online clients need 0.25.0 for new commands;
  already committed old requests still replay safely.
- After final app CI, stop the API, take a fresh exclusive consistent backup,
  migrate, verify existing data and activate the immutable server release. Keep
  the tunnel, signup policy, private diagnostics, local token files and signing.
- Schema 0010 is additive, but the previous server's readiness requires 0009.
  A full old-code rollback therefore needs a stopped-API downgrade of only the
  two derived history tables, or a compatible forward repair. Keep the current
  account DB/writes; restoring an old DB requires a separate recovery decision.
- Preserve the previous app and the original offline save before local update.

`PokePackBar.zip` SHA-256:
`7e6e164eeff6d90475c0fcced62bf2287f108413c504cca131e8c22c5fb45965`.
