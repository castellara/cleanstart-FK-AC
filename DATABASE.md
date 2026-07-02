# Database schema changes

This is deliberately **not** part of `ONBOARDING.md` — every environment
(every developer's local machine, and production) currently points at the
*same* Supabase project and database (see `ARCHITECTURE.md`). A schema
change isn't scoped to your machine or a PR preview; it's live for everyone
the moment it's applied. Only touch this if you actually need to change the
schema, and go slower than feels natural.

## The core rule: additive first

Because old and new code can be running against the database at the same
time (someone's browser tab with a stale bundle, an in-flight Vercel
deployment, a teammate mid-`bun run dev` on an older commit), a migration
must not break code that hasn't been updated yet:

- **Adding** a table/column: fine, as long as new columns are nullable or
  have a default — existing code that doesn't know about them keeps working.
- **Renaming or dropping** a column/table, or tightening a constraint (e.g.
  `NOT NULL` on an existing column): only safe once you're sure no deployed
  code path still reads/writes the old shape. In practice this usually means
  a two-step migration landed across two separate deploys (add the new
  shape and dual-write/read for a while, then remove the old shape later),
  not a single migration.
- When in doubt, ask: "if this migration runs right now, before any code
  change ships, does the app still work? And if the old code somehow runs
  after this migration, does *that* still work?" Both need to be yes.

## One person applies it, and only after review

Because there's one shared database, two people can't be applying schema
changes independently without risking conflicting or duplicate changes.

1. Write the migration as a new SQL file under `supabase/migrations/`,
   following the existing naming convention
   (`YYYYMMDDHHMMSS_short_description.sql` — see the existing
   `20260630000000_initial_schema.sql` for style: explicit `GRANT`s and RLS
   policies alongside each new table, not left implicit).
2. Test it locally first (see below) — never write a migration by hand
   against the shared remote database, and never use the Supabase
   Dashboard's SQL editor to make ad hoc schema changes outside of a
   migration file. Both of those cause the committed migration history to
   drift from the database's actual state, which is exactly what this
   process exists to prevent.
3. Get the PR reviewed specifically for the migration's safety (the
   additive-first question above), not just the application code.
4. Only one person (coordinate who, out of band — Slack/chat, not a race)
   actually runs the migration against the shared remote, and only after
   the PR is merged. Announce before and after doing it.

## Windows PowerShell note

Running `bunx supabase ...` directly in PowerShell can fail with a script
execution error, since PowerShell's default execution policy blocks the
`.ps1` shim these tools install. If you hit that, either bypass it for one
command:
```
powershell -ExecutionPolicy Bypass -Command "bunx supabase login"
```
or, for the rest of the session, relax the policy just for your current
PowerShell process (doesn't require admin, doesn't persist):
```
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

## Testing a migration locally

The Supabase CLI can run a full local Postgres + Supabase stack in Docker,
completely separate from the shared remote database, so you can apply and
verify a migration risk-free before it touches anything shared.

Prerequisite: Docker Desktop running.

```
bunx supabase start        # boots the local stack (first run pulls images, slow)
bunx supabase db reset     # applies every migration in supabase/migrations/ from scratch
```

Point your local `.env` at the local stack's URL/keys (printed by
`supabase start`) instead of the shared project's values, run `bun run dev`,
and exercise the feature that depends on the new schema end-to-end before
touching the real database.

When you're done:
```
bunx supabase stop
```

## Applying a migration to the shared remote

This is the one-person, post-merge step from above. First-time setup needs
linking to the actual project (`project_id` is in `supabase/config.toml`):

```
bunx supabase login
bunx supabase link --project-ref kqnkvtguipyprxpwlboh
```

Then, to push pending migrations:
```
bunx supabase db push
```
This applies any migration files that aren't yet recorded as applied on the
remote. Review its output before confirming — it shows exactly what SQL is
about to run.

## Rollback

There's no automatic "down" migration here — these are forward-only SQL
files. Before applying a migration, know what you'd manually run to undo it
if something goes wrong (e.g. the `DROP COLUMN`/`DROP TABLE` that reverses
an `ADD COLUMN`/`CREATE TABLE`), and write it into the PR description. If a
migration turns out to be broken after applying, treat "one person writes
and runs the fix" the same way as applying the original migration — not an
excuse to skip the coordination step because it's urgent.
