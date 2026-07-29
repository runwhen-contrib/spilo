# Spilo — RunWhen Maintained PostgreSQL + Patroni Images

RunWhen-maintained [Spilo](https://github.com/zalando/spilo) PostgreSQL + Patroni container images — built and published to GitHub Container Registry (GHCR) with automated vulnerability scanning.

## Why This Repo?

The upstream [zalando/spilo](https://github.com/zalando/spilo) project does not publish regular Docker image releases. This fork:

- **Builds independently from upstream master** to resolve CVEs on our schedule
- **Publishes multi-arch images** (`linux/amd64`, `linux/arm64`) to GHCR
- **Scans every build** with Trivy (CRITICAL + HIGH severity)
- **Auto-updates dependencies** via Renovatebot
- **Supports PostgreSQL 16, 17, 18** (matching upstream)

## Images

| PostgreSQL | Image | Status |
|---|---|---|
| 18 | `ghcr.io/runwhen-contrib/spilo-18` | Active |
| 17 | `ghcr.io/runwhen-contrib/spilo-17` | Active |
| 16 | `ghcr.io/runwhen-contrib/spilo-16` | Active |

**Tags**: `{patroni-version}-p{counter}` (e.g., `4.1-p2`) plus `latest`.

## Quick Start

```bash
# Pull the latest PostgreSQL 18 image
docker pull ghcr.io/runwhen-contrib/spilo-18:latest

# Run a single-node Patroni cluster
docker run -d --name spilo \
  -e SCOPE=test \
  -e PGVERSION=18 \
  ghcr.io/runwhen-contrib/spilo-18:latest
```

## Building Locally

```bash
# Clone
git clone git@github.com:runwhen-contrib/spilo.git
cd spilo

# Build with default PostgreSQL 18
docker build \
  --build-arg PGVERSION=18 \
  --build-arg DEMO=false \
  --build-arg COMPRESS=false \
  -t spilo:local \
  postgres-appliance/

# Or use a different version
docker build --build-arg PGVERSION=17 -t spilo-17:local postgres-appliance/
```

### Running Tests

```bash
SPILO_TEST_IMAGE=spilo:local bash postgres-appliance/tests/test_spilo.sh
```

## CI/CD Pipeline

| Workflow | Trigger | What It Does |
|---|---|---|
| `build-push.yaml` | Push to `main`, tag push, manual | Build → test → push multi-arch to GHCR → scan |
| `pr-build.yaml` | PR opened against `main` | Trivy fs scan → build → integration test |
| `trivy-scheduled.yaml` | Weekly (Mondays), manual | Scan all published PG version images |
| `renovate.yml` | Daily, manual | Auto-update dependencies |
| `sync-upstream.yaml` | Daily, manual | Bump submodule → open PR with upstream commit log |

## Dependency Management

[Renovatebot](https://docs.renovatebot.com/) tracks:

- **PostgreSQL** version in Dockerfile
- **Patroni** version (PyPI)
- **wal-g** version (GitHub releases)
- **PostGIS**, **bg_mon**, **pg_auth_mon**, **pg_mon**, **plprofiler**, **pg_profile**, **pam_oauth2**
- **Base image** (Ubuntu)
- **GitHub Actions** versions in workflows

Minor/patch updates auto-merge after 3 days. Major updates require manual approval.

## Security Scanning

Trivy scans run on:
- Every PR (filesystem scan of `postgres-appliance/`)
- Every push to main/tag (image scan after build)
- Weekly scheduled scan of all published images
- Results uploaded to GitHub Security tab as SARIF

Known false positives are tracked in `.trivyignore`.

## Updating from Upstream

Upstream source lives in `postgres-appliance/`. We track `zalando/spilo:master` via a daily sync workflow that opens PRs showing exactly what changed.

### Why in-tree?

We **modify build scripts directly** to resolve CVEs — bumping pinned component versions, updating base images, and patching dependencies without waiting for upstream releases.

| Capability | How |
|---|---|
| **Fix wal-g CVE** | Edit `ENV WALG_VERSION=v3.1.0` in Dockerfile |
| **Update base image** | Edit `ARG BASE_IMAGE=ubuntu:24.04` |
| **Patch an extension** | Edit commit ref ENV or modify build script |
| **Adopt upstream fixes** | Merge the daily sync PR (or cherry-pick commits) |

### Automatic (daily)

`sync-upstream.yaml` opens a PR when upstream has new commits:
1. Detects new commits on `zalando/spilo:master`
2. Creates a merge branch with upstream changes
3. Opens a PR showing the diff in `postgres-appliance/`
4. CI runs build → test on the PR

### Manual

```bash
git fetch upstream
git merge upstream/master
# Only possible conflict: README.md → keep our version
git push origin main
```

### Post-update checklist
- [ ] Review `postgres-appliance/` diffs for CVE fixes and breaking changes
- [ ] If Dockerfile build args/ENVs changed, update `renovate.json`
- [ ] CI passes (build workflow runs on the sync PR)
- [ ] Merge the PR, or cherry-pick specific commits
- [ ] Build and push images if CVE fixes were included

## License

Apache 2.0 — see upstream [zalando/spilo LICENSE](https://github.com/zalando/spilo/blob/master/LICENSE).