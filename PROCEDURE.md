# Porting upstream Chatwoot v4.14.1 -> v4.16.2 into starchats

Branch `release/v2.5.1-star`. Upstream remote: `upstream` (github.com/chatwoot/chatwoot).

> This file lives in the repo on purpose. The first copy was written to the session
> scratchpad and was wiped when the session ended, taking the translation script and the
> rspec logs with it.

## Running the suites

```
# backend -- BOTH overrides are required, see below
POSTGRES_DATABASE=chatwoot_test VITE_RUBY_SKIP_COMPATIBILITY_CHECK=true \
  RAILS_ENV=test bundle exec rspec

# frontend
pnpm test
```

**`POSTGRES_DATABASE=chatwoot_test`** — `.env` sets `POSTGRES_DATABASE=chatwoot_dev`, and
`config/database.yml` resolves the test database as `ENV.fetch('POSTGRES_DATABASE',
'chatwoot_test')`, so test and development both point at `chatwoot_dev`.
`rails db:test:prepare` would drop and recreate the developer's database. Rails'
EnvironmentMismatchError is the only guard — **never** run the `db:environment:set` command
its error message suggests. Proposed fix (CI does not set the variable, so it is safe):

```yaml
test:
  database: "<%= ENV.fetch('POSTGRES_TEST_DATABASE', 'chatwoot_test') %>"
```

**`VITE_RUBY_SKIP_COMPATIBILITY_CHECK=true`** — `vite_ruby` is 3.10.2 (what upstream v4.16.2
wants) but `package.json` is frozen at `vite-plugin-ruby ^5.0.0`, and Rails refuses to boot
on the mismatch. Upstream pairs 3.10.2 with `^5.2.1`. Bumping package.json is the real fix
and is a justified exception to the frontend freeze: it is a build-tool version coupled to a
backend gem, not UI code.

## Porting method

Upstream code is translated on the way in:

| upstream | here |
|---|---|
| `enterprise/` path segment | `starchat/` |
| `captain` path segment / identifier | `cosmos` (case-preserving) |
| `lib/captain/`, `spec/lib/captain/` | `starchat/lib/cosmos/`, `spec/starchat/lib/cosmos/` |
| `Enterprise::` namespace | `Starchat::` |

`Enterprise::` is anchored on `::` and on `mod_with('...')` so `StarchatsApp.enterprise?` and
`EnterpriseAccountsController`, which this fork keeps, are left alone.

Build a `xlat` branch holding one commit per upstream tag (each tag's tree with the
translation applied), then **cherry-pick** — never merge. Cherry-pick uses the commit's
parent as the merge base, so only that tag's delta lands. Merging drags the whole
translation in; it produced 436 spurious conflicts when tried.

Per tag:

```
FREEZE="app/javascript public tests theme LICENSE vite.config.ts vite.shared.ts \
        vite.lib.config.ts vitest.config.ts tailwind.config.js package.json pnpm-lock.yaml"
git cherry-pick -n <xlat-sha>
for p in $FREEZE; do git checkout HEAD -- "$p" 2>/dev/null; done
git diff --cached --name-only --diff-filter=A -- $FREEZE | xargs -r git rm -qf --
for f in $(git diff --name-only --diff-filter=U -- app/javascript public tests theme); do
  git rm -qf -- "$f"; done          # new upstream frontend files have no HEAD version
git diff --name-only --diff-filter=U   # resolve what is left
```

`DU` conflicts are files this fork deleted (mostly Captain v1 task services, replaced by the
v2 agent architecture) — keep them deleted.

**Never resolve `Gemfile.lock` by side.** Taking upstream's dropped this fork's `bunny` and
`caxlsx`. Run `bundle lock`, then `bundle check`.

Before committing: `ruby -c` every changed `.rb`, confirm
`git diff --cached --name-only -- app/javascript LICENSE` is empty, grep for leftover
`<<<<<<<`, and run `rails zeitwerk:check`. Zeitwerk is what catches namespace mistakes —
development lazy-loads and hides them, production eager-loads and fails to boot.

## Status

- [x] v4.14.2 — `eb100ed468` (+ lockfile fix `fc910a53e1`)
- [x] v4.15.0 — `af8d53d167`
- [x] v4.15.1 — `447c76539e` (upstream revert of the unread-count filters)
- [x] autoload fix — `2460aaa9a2`
- [ ] v4.16.0 — measured: 463 conflicts, **93 after the freeze** (54 UU, 38 DU, 1 AA)
      * re-lands the unread-count filters v4.15.1 reverted, redesigned around
        `FilteredCountStore` / `FilteredCountInvalidator` and the `unread_count_for_filters`
        flag. Take it this time; it is not the reverted `UserFilterNotifier`.
      * the `channel/whatsapp.rb` conflict adds `after_create :sync_templates`, which this
        fork already declares (with a rubocop disable). Do not end up with it twice.
      * `campaign.rb` auto-merges and keeps our `draft: 2, processing: 3` enum.
- [ ] v4.16.1 (31 overlapping files)
- [ ] v4.16.2 (52) + bump `config/app.yml` to 4.16.2
- [ ] reconcile `featurable.rb`, review the 23 new migrations
- [ ] run rspec green, then the full suite
- [ ] blanket `chatwoot` -> `starchats` rename (excluding `@chatwoot/*` npm packages,
      `github.com/chatwoot/*` URLs). Renames the widget SDK events too, which breaks
      customer integrations listening for `chatwoot:ready` — they must be told first.
- [ ] frontend/dashboard port, including removing the now-unreachable billing UI

## Conflict decisions that must not be undone

- `Campaign#campaign_status`: upstream added `processing: 2`, but 2 already means `draft`
  in stored rows. `draft` stays at 2 and `processing` is mapped to 3.
- Campaigns mark `completed!` after processing, not before, now that upstream's
  `mark_processing!` row lock guards re-entry.
- Campaign audience stays contact-based (ours); upstream is still label-based.
- Facebook send service keeps hardcoded `MESSAGE_TAG`/`ACCOUNT_UPDATE`, so upstream's
  `merge_human_agent_tag` and its specs are left out. Meta restricts ACCOUNT_UPDATE to
  account notifications; `HUMAN_AGENT` is the supported tag for agent replies outside the
  24h window. Worth revisiting.
- Cosmos HTTP tool routes through `SafeFetch` (ssrf_filter), replacing a hand-rolled
  `check_private_ip!` that missed DNS rebinding and redirect bypasses.
- `filter_service.rb` stays at this fork's version; upstream's lt/gt refactor buys nothing
  here yet and this fork has a custom-attribute subsystem upstream lacks.
- `db/schema.rb` was hand-merged: our version (higher) plus the union of foreign keys. It
  loads, but regenerate it from migrations against a clean database before deploying.

## Billing / plans / ChatwootHub removal

All of it is gone from the backend: telemetry, instance registration, the support widget,
pricing plans, Stripe leftovers, `BillingHelper`, and the `hub.2.chatwoot.com` push relay.
`StarchatsApp.enterprise?` already returned `true` unconditionally, so every account is
treated as enterprise.

**Push notifications now require your own Firebase.** The relay was the fallback when
`FIREBASE_PROJECT_ID` / `FIREBASE_CREDENTIALS` are unset — and they are unset here. Mobile
push stays down until you configure them.

Cosmos document auto-sync used to be keyed by plan, which meant accounts with no `plan_name`
never synced at all. It is now a single interval applied to every account
(`COSMOS_DOCUMENT_AUTO_SYNC_INTERVALS`, still accepts the old plan-keyed hash).

The frontend billing screen and `PaymentPendingBanner` were left in place: both are gated on
`isOnStarchatsCloud` / `installationTypes: [CLOUD]`, and `DEPLOYMENT_ENV` is `self-hosted`,
so they are already unreachable. Remove them during the dashboard port.
