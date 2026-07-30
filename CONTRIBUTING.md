# Contributing

## Branch naming

Every branch is tied to a Trello card ID from the "Bisan Internship" board:

```
<type>/<CARD-ID>-<short-description>
```

- `type` — `feature`, `fix`, `chore`, or `docs`
- `CARD-ID` — the card's Trello ID (e.g. `AUTH-4`, `SETUP-1`)
- `short-description` — a few kebab-case words

Examples:

```
feature/AUTH-4-rbac-guard
feature/SETUP-4-db-migrations
fix/AUTH-3-token-revocation-bug
```

## Pull requests

- Branch off `main`, open a PR back into `main`.
- PR title references the card ID (e.g. `AUTH-4: server-side RBAC guard`).
- CI (build + tests for backend and frontend) must pass before merge.
- **At least 1 approval is required before merging.**
- No direct pushes to `main` — all changes land via PR (enforced by branch protection).
- Prefer small, reviewable PRs scoped to a single Trello card.

## Commits

- Keep commits focused; write messages that explain *why*, not just *what*.
