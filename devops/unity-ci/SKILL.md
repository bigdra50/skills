---
name: unity-ci
description: >-
  GitHub Actions CI/CD for Unity projects — compile check, test execution,
  multi-platform builds, and artifact distribution. Covers GameCI setup,
  license activation, build matrix, and unilyze quality gates.
  Does NOT cover deployment to app stores (that varies by project).
---

# Unity CI/CD with GameCI

A GitHub Actions pipeline for Unity projects built on [GameCI](https://game.ci). It compiles, tests, gates on code-health regressions, then builds and uploads per-platform artifacts. Everything runs headless in CI with a floating Personal license.

## When to invoke

- Setting up CI for a new Unity project and you want compile + test + build coverage in one workflow.
- Adding a code-health quality gate (`unilyze`) as a required PR check.
- Debugging a Unity build that passes locally but fails in Actions (usually license activation or a missing `Library/` cache).

## Pipeline stages

Run in this order — each stage gates the next, so failures surface cheapest-first:

```
license activation   (all downstream jobs need the activated license)
  └─ compile check    (does the project build the Player scripts at all?)
     └─ EditMode tests (fast, no Player loop)
        └─ PlayMode tests (slower, spins the Player loop)
           └─ unilyze quality gate  (fail on CodeHealth regression vs base)
              └─ build   (matrix: platform x target)
                 └─ artifact upload
```

Put compile + tests + quality gate on every PR. Gate the build matrix behind `push` to `main`/`develop` or a label — full multi-platform builds are minutes-to-tens-of-minutes each and rarely needed per-commit.

## GameCI setup

Two actions do the heavy lifting:

- `game-ci/unity-test-runner@v4` — runs EditMode/PlayMode tests, emits results + coverage.
- `game-ci/unity-builder@v4` — produces a Player build for one `targetPlatform`.

Both need an **activated license**. For a Personal license, store three repo secrets and pass them as env to every GameCI step:

| Secret | Source |
|--------|--------|
| `UNITY_LICENSE` | contents of the `.ulf` file from `game-ci/unity-activate` (run once locally, paste the whole XML) |
| `UNITY_EMAIL` | Unity account email |
| `UNITY_PASSWORD` | Unity account password |

Pin the Unity version explicitly (`unityVersion:`) instead of `auto` so a `ProjectVersion.txt` bump can't silently pull an editor image that isn't cached.

## Build matrix

Pick runners and targets per platform. IL2CPP and mobile SDKs drive the runner choice:

| Platform | Runner | `targetPlatform` | Notes |
|----------|--------|------------------|-------|
| Android | `ubuntu-latest` | `Android` | Android SDK/NDK ship in the `-android` editor image; set `androidExportType: androidPackage` |
| iOS | `macos-latest` | `iOS` | Exports an Xcode project only — no signing in CI (see Boundaries) |
| WebGL | `ubuntu-latest` | `WebGL` | Slow; caching `Library/` is close to mandatory |
| Windows | `windows-latest` | `StandaloneWindows64` | IL2CPP needs VS Build Tools on the runner image |

## Quality gate

Gate PRs on a code-health regression measured by [unilyze](https://github.com/bigdra50/unilyze). unilyze's `diff` compares two snapshot files, so CI snapshots the base ref and the head, then diffs. Fail the job if any type degrades:

```yaml
  quality-gate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0            # need base ref history for the diff
      - name: Snapshot base ref
        run: |
          git worktree add ../base "origin/${{ github.base_ref || 'main' }}"
          unilyze -f json -p ../base -o base.json
      - name: Snapshot head
        run: unilyze -f json -p . -o head.json
      - name: Diff and fail on regression
        run: |
          unilyze diff base.json head.json --changed-only | tee diff.md
          # exit non-zero if any type degraded — keys on the diff report
          ! grep -q "degraded" diff.md
```

Wire this as a required status check in branch protection so a red gate blocks merge.

## Caching

Cache the `Library/` folder — it holds Unity's import cache and is the single biggest build-time win. Key it on the asset + package hash so an asset change busts it:

```yaml
      - uses: actions/cache@v4
        with:
          path: Library
          key: Unity-Library-${{ hashFiles('Assets/**', 'Packages/**', 'ProjectSettings/**') }}
          restore-keys: Unity-Library-
```

`restore-keys` lets a partial hit warm-start even when the exact key misses. Cache per platform if you build several — a WebGL `Library/` differs from an Android one; suffix the key with `targetPlatform` when the matrix fans out.

## Artifact upload

Publish the build output so it's downloadable from the run:

```yaml
      - uses: actions/upload-artifact@v4
        with:
          name: Build-${{ matrix.targetPlatform }}
          path: build/${{ matrix.targetPlatform }}
          retention-days: 14
```

## Example workflow

Minimal `.github/workflows/ci.yml` covering compile + tests + gate on PRs, build matrix on push:

```yaml
name: CI
on:
  pull_request:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { lfs: true }
      - uses: actions/cache@v4
        with:
          path: Library
          key: Unity-Library-${{ hashFiles('Assets/**', 'Packages/**') }}
          restore-keys: Unity-Library-
      - uses: game-ci/unity-test-runner@v4
        env:
          UNITY_LICENSE: ${{ secrets.UNITY_LICENSE }}
          UNITY_EMAIL: ${{ secrets.UNITY_EMAIL }}
          UNITY_PASSWORD: ${{ secrets.UNITY_PASSWORD }}
        with:
          testMode: all          # EditMode + PlayMode; compile is implicit
          unityVersion: 6000.0.30f1

  build:
    needs: test
    if: github.event_name == 'push'
    runs-on: ${{ matrix.runner }}
    strategy:
      fail-fast: false
      matrix:
        include:
          - { targetPlatform: Android, runner: ubuntu-latest }
          - { targetPlatform: WebGL,   runner: ubuntu-latest }
    steps:
      - uses: actions/checkout@v4
        with: { lfs: true }
      - uses: actions/cache@v4
        with:
          path: Library
          key: Unity-Library-${{ matrix.targetPlatform }}-${{ hashFiles('Assets/**', 'Packages/**') }}
          restore-keys: Unity-Library-${{ matrix.targetPlatform }}-
      - uses: game-ci/unity-builder@v4
        env:
          UNITY_LICENSE: ${{ secrets.UNITY_LICENSE }}
          UNITY_EMAIL: ${{ secrets.UNITY_EMAIL }}
          UNITY_PASSWORD: ${{ secrets.UNITY_PASSWORD }}
        with:
          targetPlatform: ${{ matrix.targetPlatform }}
          unityVersion: 6000.0.30f1
      - uses: actions/upload-artifact@v4
        with:
          name: Build-${{ matrix.targetPlatform }}
          path: build/${{ matrix.targetPlatform }}
```

## Boundaries

- Do NOT handle app store distribution (Play Console / App Store Connect upload, TestFlight, release tracks) — that varies per project and belongs in a separate deploy workflow.
- Do NOT manage signing certificates, provisioning profiles, or keystores. The iOS job exports an unsigned Xcode project; signing is a downstream step outside CI's shared secret scope.
- Do NOT commit the `.ulf` license or account credentials — they live in repo secrets only.

## Related skills

- `unity-dev/asmdef-lint` — a cheap pre-build assembly-structure check that can run before compile.
- `unity-dev/project-bootstrap` — sets up the project layout and unilyze baseline this pipeline gates against.
- `unity-review/review-testing` — deeper analysis of the test posture this pipeline exercises.
