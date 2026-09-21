# Deferred CraftSim notes (throwaway)

Snapshot from 2026-09-20. Not addon code — never loaded by `CraftSim.toc`.

- [open-issues-triage.md](open-issues-triage.md) — triage of open issues on derfloh205/CraftSim at 27.0.5
- [headless-lua-test-ci.md](headless-lua-test-ci.md) — deferred Lua 5.1 + GitHub Actions test plan

## Retrieve on another computer

From a CraftSim clone that has the `avilene` fork:

```bash
git fetch fork notes/deferred-plans
git checkout notes/deferred-plans
```

Or, without checking out the branch:

```bash
git fetch fork notes/deferred-plans
git show fork/notes/deferred-plans:Dev/plans/open-issues-triage.md
git show fork/notes/deferred-plans:Dev/plans/headless-lua-test-ci.md
```

In Cursor, open this branch and tell the agent to read `Dev/plans/`.
