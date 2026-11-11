# Aves Miuix Repository Instructions

These instructions apply to the whole repository.

## Task workflow

1. Before changing files, inspect the current worktree and state a short implementation plan.
2. Prefer the smallest solution that solves the actual problem. Use modularization when it clearly reduces coupling or regression risk, not by default.
3. After completing a feature or modification, build one Release APK for `arm64-v8a`.
4. Update `fork.md` with a concise completion record. Each record must begin with the completion time in `Asia/Shanghai`.
5. Commit completed changes locally by default.
6. Do not push to GitHub unless the user explicitly requests it.
7. Do not synchronize upstream unless the user explicitly requests it.
8. Never open or submit a pull request to the upstream repository.

If a requested verification or build cannot be completed, report the exact blocker instead of claiming completion.

## Version and APK rules

- Keep `versionName` and `versionCode` unchanged for fork-only work.
- When syncing upstream, inherit the upstream version instead of inventing a fork version.
- Build only the Release `arm64-v8a` APK by default.
- Name artifacts exactly:

  `aves-miuix-<versionName>-arm64-v8a-<change-summary>-<feature-commit-id>.apk`

- Keep APKs outside Git. Do not commit build outputs.

## Fork boundaries

- UI customization primarily belongs to the Miuix skin.
- When the Miuix skin is disabled, preserve upstream Material behavior except for intentional global fork decisions: application identity, packaging, release configuration, and disabled Android TV support.
- Shared layout slots should keep upstream dimensions where practical. Miuix visuals should fit inside those slots rather than changing shared page geometry.
- The persistent tab shell is Miuix-only and must remain inactive for Material and Android TV paths.
- Android TV support is intentionally disabled.
- The custom-font feature was rolled back. Do not reintroduce it without a new explicit request.
- Keep changes to upstream-owned files narrow and conditional so upstream synchronization remains manageable.

## Upstream synchronization

- Synchronize only when explicitly requested.
- Inspect the upstream delta before applying it.
- Account for upstream file moves and refactors; do not blindly preserve obsolete paths.
- Regenerate dependency lock files instead of resolving lock-file conflicts by hand.
- Preserve fork-only behavior deliberately after each merge, especially release workflow, application identity, Miuix integration, TV disablement, and shell navigation.
- Never target a pull request at the upstream project.

## Security

- Never commit signing passwords, keystore contents, access tokens, device serial numbers, personal absolute paths, or machine-specific environment dumps.
- Keep local credentials and keystore files outside Git.
- Before committing, inspect the staged diff for secrets and unrelated files.
