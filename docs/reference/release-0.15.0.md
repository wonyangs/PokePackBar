# PokePackBar 0.15.0

App PRs #13–#16 add pack tearing/search, accessible controls and feedback,
friend trade binders/counter-offers, trainer levels/rewards/titles, and the daily
rotation market. Measured per-set pull rates and rebuilt dex rewards replace
the previous data. Server PRs #8–#11 are the matching API and rules release.

## Validation

- Integrated app before the final audit-fixture fix: 961 tests, 9 skipped, zero failures.
- Final release-note/audit-fixture regression subset: 7 tests pass. Reintroducing
  the stale-stock fixture fails the new regression; the mutation is then reverted.
- Final merged server including public-signup PR #8: 251 passed, 95 oracle tests skipped.
- Separately enabled Swift/Python oracle suite: all 95 tests pass.
- Native online audit: authentication, state patches, bulk openings, devices,
  jobs, trade binders/counter-offers, market and durable replay pass.
- HTTP level/rotation audit: one-time rewards, title eligibility, authoritative
  quote/debit, card grant, replay and duplicate/stale rejection pass.
- Korean/English native layout audits cover 22 popover screens. Screenshots
  use isolated fixtures, never a real user's account.
- Copied production database rehearses schema `20261008_0007`: all 25 existing
  tables retain every old column/row, password and session. Both account states
  validate without losing wallet, cards, packs, coupons, pity or claimed rewards.
- Final signed bundle: strict signature, resource/artwork separation, energy
  source audit, 1,000-pack responsiveness benchmark, foil/price/geometry audits
  and repeated native online suites pass. The persistent signing identity is
  unchanged. Zip SHA-256:
  `9fe7edacb4069b229f2080643e7b7251d417cb40dc3622e528bd86c9e4d4ffd5`.

Final package rehearsal found and repairs two validation gaps: readiness was
pinned to schema 0006 despite migration 0007, and the commerce audit reused a
pre-counter-offer spare that may have been consumed. Migration tests now invoke
the actual readiness handler, and the marketplace fixture selects current
authoritative available stock with a regression for zero remaining spares.

## Cutover

The new rules version is
`ppb-server-v2/e835cec930b86e5a50298b384e3c2670a013eef1ca3d020ba38b7da001bdbb2e`.
Online users must update the client; 0.14.0 uses the old rules version and its
mutating commands will be rejected by the updated server. Publish the client
before switching the server. Preserve the old release and a verified backup;
never overwrite resumed transactions with an older database.

The operator explicitly approved public registration for this release. Server
PR #8 allows email/password sign-up without a code; account-linking codes remain
optional and rate limits remain enabled. Email verification is not implemented.
The obsolete `PPB_REGISTRATION_MODE` environment setting is removed at cutover.

Merged feature main CI passes both the full test/coverage gate and secret scan.
The release commit starts a fresh CI run including the additional fixture test.
