<!-- LOVABLE:BEGIN -->
> [!IMPORTANT]
> This project is connected to [Lovable](https://lovable.dev), synced to the
> `lovable-dev` branch (not `main`). Avoid rewriting published git history on
> `lovable-dev` — force pushing, or rebasing/amending/squashing commits that
> are already pushed — as it rewrites history on Lovable's side and the user
> will likely lose their project history.
>
> Commits you push to `lovable-dev` sync back to Lovable and show up in the
> editor, so keep that branch in a working state.
<!-- LOVABLE:END -->

## Contributing

`main` is the deployed branch (Vercel builds from it) and is protected — no
direct pushes or force-pushes. All changes land via PR, regardless of tool:

- Feature branches (Claude Code, other contributors): branch off `main`, PR
  back into `main`.
- Lovable edits: sync to `lovable-dev`, then PR `lovable-dev` into `main`.

This keeps Lovable's auto-sync from colliding with everyone else's commits
while still landing all changes in one shared history.
