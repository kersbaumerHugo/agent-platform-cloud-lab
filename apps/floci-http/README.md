# Floci EC2: versioned deployment and rollback

**Validation target:** local Floci EC2 container, not a real AWS instance. The
network and Security Group behavior are not AWS-equivalent.

The existing OpenTofu stack owns EC2 infrastructure and initializes a BusyBox
TCP/HTTP handler with `user_data`. This slice adds **Git-versioned application
artifacts** and an explicit deployment step, without changing the VPC or EC2.

From the repository root, with Floci and the EC2 already running:

```bash
bash tests/test-floci-release.sh
bash tests/test-floci-readiness.sh

bash scripts/deploy-floci-ec2-app.sh v1.0.0
bash scripts/deploy-floci-ec2-app.sh v1.1.0

# Intentional failure: expect nonzero exit and [RECOVERED] in logs.
set +e
DEPLOY_TIMEOUT_SECONDS=8 DEPLOY_INTERVAL_SECONDS=2 \
  bash scripts/deploy-floci-ec2-app.sh v1.2.0-bad
BAD_EXIT=$?
set -e
printf 'Bad release exit status: %s (expected 1)\n' "$BAD_EXIT"
test "$BAD_EXIT" -eq 1

bash scripts/check-floci-ec2-health.sh
```

The deployment script uses `docker cp`/`docker exec` to reach the simulated EC2
container; it does **not** contact a real AWS account. The `activate.sh` script
atomically swaps `/srv/app/health-handler.sh` to a Git-versioned release. The
pre-existing BusyBox `nc` listener executes that path on each connection, so no
new server process is needed. The first deployment preserves the original
`user_data` handler as the `bootstrap` rollback release.

- `/health` confirms the current service returns `ok`.
- `/version` checks the **intended version**, preventing false success when an
  older healthy release is still serving traffic.
- `v1.2.0-bad` intentionally serves HTTP 503 on `/health` to exercise rollback.
- On a failed candidate, the deploy script restores the former release and
  rechecks readiness; it **still exits nonzero** so CI must treat the deploy as
  failed even if recovery succeeded.
- The existing GitHub Actions CI runs **offline contract tests only**. The live
  integration check must run on `dev01` with Floci + Docker available.

This implementation models app-deploy transactions for learning. It is not an
AWS deployment mechanism, a production-grade release manager, or a durability
solution: simulated EC2 container replacement loses files deployed inside it.

**Definition of Done**

- [ ] Offline release + readiness tests pass
- [ ] v1.0.0 deploys, returns `/health=ok`, `/version=v1.0.0`
- [ ] v1.1.0 deploys, returns `/version=v1.1.0`
- [ ] Broken v1.2.0-bad produces deployment failure
- [ ] Previous release automatically restored; `/version=v1.1.0` afterward
- [ ] OpenTofu `plan -detailed-exitcode` returns 0 (no infrastructure changes)
- [ ] Evidence recorded; GitHub CI passes before merge

## Slice 4: Functional smoke after deploy

New versions exercise a deterministic HTTP operation: `GET /sum?a=2&b=3`
returns `5`, and `GET /sum?a=7&b=4` returns `11`. The deliberately
broken `v1.4.0-badlogic` returns incorrect sums while still returning
`/health=ok` and the expected `/version`. The deployment gate now verifies
readiness, exact version and both functional cases, then restores the previous
release on failure. The rollback check also runs the functional smoke.

**Important:** historical `v1.0.0`, `v1.1.0` and `v1.2.0-bad` do not implement
`/sum`; re-deploying them using this stricter gate will fail functional
validation. First deploy the healthy `v1.3.0`, then the badlogic release.

```bash
bash tests/test-floci-functional.sh
bash scripts/deploy-floci-ec2-app.sh v1.3.0
bash scripts/check-floci-ec2-functional.sh

set +e
bash scripts/deploy-floci-ec2-app.sh v1.4.0-badlogic
BAD_EXIT=$?
set -e
test "$BAD_EXIT" -eq 1

# The previous healthy release must still answer both /version and /sum.
INSTANCE_ID="$(tofu -chdir=infra/opentofu/stacks/aws/local output -raw app_instance_id)"
docker exec "floci-ec2-$INSTANCE_ID" wget -qO- http://127.0.0.1:8080/version
bash scripts/check-floci-ec2-functional.sh
```

The `/sum` demonstration is a **functional HTTP smoke in the local emulator**.
It does not represent end-to-end behavior of Agent Platform, a database, or
external dependencies. It intentionally has no network or storage dependencies.
