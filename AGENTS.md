## Contributing

This repo (`fkloosterman/cleanstart`) is the only one in active use. There
is no Lovable-based editing here — Lovable remains connected to
`jreddy777/cleanstart`'s `main` branch, but that's a separate, unrelated
repo that we don't sync with or merge from/into.

`mvp` is the working and production branch — Vercel builds from it, and it's
also the repo's default branch. Both `main` and `mvp` are protected via
GitHub branch rulesets: no direct or force pushes, everything lands via PR.

- Branch off `mvp` for new work, PR back into `mvp`.
- `main` is not actively used; don't rely on it being kept up to date.

See `ONBOARDING.md` for the full new-contributor setup flow (Windows,
agent-guided).

## Database schema changes

Every environment (every developer's local machine, and production) points
at the *same* Supabase database — there's no per-branch or per-PR database
isolation. Never edit `supabase/migrations/` or run a migration against the
shared project without reading `DATABASE.md` first; it's intentionally kept
out of the regular onboarding flow because it needs more care than normal
feature work.
