# Editor build patch for dev

> Two commits that make `website/build.py`, `website/validate.py` and `website/admin.py` build on dev's layout today and after the Team project moves to `Apps/Team`. Build code only, no page text. Apply them to dev with `git am`.

Made from `origin/dev` at `1087a92` (v0.4.5). Apply with:

```
git am briefs/2026-11-08__three-apps/editor-build/*.patch
```

The two commits are `0e56b60` (build finds the app project, artwork and `Websites.json` in `Apps/` and `Packages/`; app version follows `VERSION` from v0.4) and `23c4fa5` (admin pages read the Team app from `Apps/Team` after the move).

## Checked

- Today's dev layout: build, validator and 59 tests pass.
- Platform's layout, tried in a throwaway worktree (`PrompTugal.xcodeproj` to `Apps/Team/Team.xcodeproj`, `PrompTugal/` to `Apps/Team/Sources`, tests to `Apps/Team/Tests` and `UITests`, `apps.json` team entry on `Apps/Team/`): build, validator and 59 tests pass.

If dev has moved on, `git am -3` handles small drift; tell me if it does not apply.
