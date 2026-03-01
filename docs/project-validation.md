# Journal Starter — Full Project Validation Report

> **Scope**: API · Terraform Infra · Kubernetes · CI/CD · Tests · Dockerfile  
> **Date**: 2026-02-28  
> **Status**: Pre-deployment review

---

## Legend

| Icon | Meaning |
|------|---------|
| 🔴 | **Blocker** — Will break deployment or create a security hole |
| 🟡 | **Warning** — Won't break it today but will cause pain soon |
| 🟢 | **Good** — Solid practice, worth calling out |
| 💡 | **Improvement** — Optional but will make you a better engineer |

---

## 1. API (`api/`)

### 🔴 Blockers

| # | File | Issue |
|---|------|-------|
| 1 | `routers/journal_router.py` L68 | `GET /entries/{entry_id}` returns **501 Not Implemented**. Tests for this endpoint will fail and the route is broken in production. |
| 2 | `routers/journal_router.py` L98 | `DELETE /entries/{entry_id}` returns **501 Not Implemented**. Same issue. |
| 3 | `routers/journal_router.py` L129 | `POST /entries/{entry_id}/analyze` returns **501**. The LLM integration is fully missing — `llm_service.py` raises `NotImplementedError`. |
| 4 | `main.py` L12-18 | Logging is a TODO comment. Without logging you cannot debug issues in production — you are flying blind. |

### 🟡 Warnings

| # | File | Issue |
|---|------|-------|
| 5 | `routers/journal_router.py` L35-36 | Bottom-level `except Exception as e → 400` swallows **all** errors (DB connection failures, constraint violations). At minimum distinguish 400 (bad input) from 500 (server error). |
| 6 | `routers/journal_router.py` L71 | `update_entry` receives `entry_update: dict` with **no Pydantic validation**. Any key can be passed and stored in the DB. Use a Pydantic `EntryUpdate` model with `Optional` fields. |
| 7 | `repositories/postgres_repository.py` L27 | `asyncpg.create_pool()` is called on **every single request** because `PostgresDB` is instantiated per-request in the dependency. This will hammer the DB with connection pool setup overhead. Pool should be created once at startup (e.g., lifespan context or FastAPI `startup` event). |
| 8 | `repositories/postgres_repository.py` L14-16 | `DATABASE_URL` is validated at module import time. If the env var is missing, the whole import fails with `ValueError`, which gives a very poor error in CI. Raise a more helpful startup error from lifespan. |
| 9 | `repositories/postgres_repository.py` L41 | Entry `data` JSONB column stores the full dict including `created_at` / `updated_at` **again** (they're already in dedicated columns). This is redundant data storage and can cause inconsistencies on updates. |
| 10 | `main.py` L20 | FastAPI app has no `version`, `docs_url` config, and no CORS middleware. For a deployed API you need at minimum to think about which origins can call it. |

### 🟢 Good Practices

- Pydantic models (`Entry`, `EntryCreate`) are used for request bodies ✓
- Repository pattern + service layer = clean separation of concerns ✓
- Async throughout (`asyncpg`, `AsyncClient`) ✓
- `/health` endpoint exists and is used by k8s probes ✓
- Prometheus instrumentation is wired up correctly ✓

### 💡 Improvements

- **Pagination on `GET /entries`** — returning every row without a limit is a production problem the moment you have thousands of entries. Add `?limit=50&offset=0`.
- **Return `201 Created`** instead of `200 OK` on `POST /entries` — semantically correct HTTP.
- **`DELETE /entries` (nuke all)** should not be a public endpoint in a real app. Add authentication or remove it.
- `sqlalchemy` is listed in `pyproject.toml` dependencies but never imported anywhere — dead dependency.

---

## 2. Dockerfile

### 🔴 Blockers

| # | Issue |
|---|-------|
| 11 | **`COPY . /app` copies everything including `.env`** — even though the comment says "do NOT bake secrets", the `COPY .` will include `.env` unless `.dockerignore` explicitly excludes it. Verify `.dockerignore` exists and lists `.env`. |

### 🟡 Warnings

| # | Issue |
|---|-------|
| 12 | No **multi-stage build**. `build-essential` and `libpq-dev` are installed in the final image, bloating it by ~200 MB. Use a build stage to compile, copy only the Python packages to a slim runtime stage. |
| 13 | The image runs as **root** by default (`python:3.11-slim` does not create a non-root user). Add `RUN useradd -m appuser && USER appuser` before `CMD`. |
| 14 | `pip install -r requirements.txt` — but your project uses `pyproject.toml` + `uv`. `requirements.txt` and `pyproject.toml` can drift. Either generate `requirements.txt` from `uv export` in CI, or use `uv` in the Dockerfile directly. |
| 15 | `COPY . /app` **before** `pip install` means any source code change invalidates the pip cache layer. Copy `requirements.txt` first, `pip install`, then `COPY . /app`. |

### 🟢 Good Practices

- `PYTHONUNBUFFERED=1` is set ✓
- Comment about not baking secrets shows awareness ✓
- `uvicorn` is the correct ASGI server ✓

---

## 3. Database (`database_setup.sql`)

### 🟢 Good Practices

- `CREATE TABLE IF NOT EXISTS` is idempotent ✓
- `TIMESTAMP WITH TIME ZONE` (not naive `TIMESTAMP`) ✓
- `GIN` index on the JSONB `data` column for fast JSON queries ✓
- Index on `created_at` for time-range queries ✓

### 🟡 Warnings

| # | Issue |
|---|-------|
| 16 | `\d entries;` is a `psql` meta-command — it will **fail** if this SQL is executed from application code (e.g., `asyncpg`). Fine for CI-only execution but be aware. |
| 17 | No `sslmode` enforcement at the DB level. The app connects with `sslmode=require` but the DB itself has no server-side SSL check. |

---

## 4. Terraform Infra (`infra/`)

### 🔴 Blockers

| # | File | Issue |
|---|------|-------|
| 18 | `rds.tf` L18 | **Typo in egress CIDR**: `"0.0.0.0/16"` is invalid (should be `"0.0.0.0/0"` to allow all outbound). This will silently fail or block egress from the RDS security group. |
| 19 | `rds.tf` L38 | `username = "postgres"` is hardcoded (not a variable). Use a variable like `db_username` with a sensitive default for the same reason `db_password` is a variable. |
| 20 | `kubernetes-secrets.tf` L10 | The **DB password is passed as plaintext** via Terraform state: `${var.db_password}`. Your Terraform state file (even in S3) will contain the plain-text password. Use AWS Secrets Manager + the `aws_secretsmanager_random_password` resource, or at minimum ensure the state backend is encrypted. |
| 21 | `providers.tf` (no backend block) | **No remote state backend configured**. `terraform.tfstate` is local. If you lose your machine you lose the entire state — you won't be able to destroy or update resources. Add an S3 backend with DynamoDB state locking. |

### 🟡 Warnings

| # | File | Issue |
|---|-------|-------|
| 22 | `variables.tf` L46 | `eks_version = "1.27"` — EKS 1.27 reached **End of Life on November 1, 2024**. Using an EOL version won't prevent initial creation but AWS will auto-upgrade you and you'll lose control. Bump to 1.30 or 1.31. |
| 23 | `eks.tf` L9 | `subnet_ids = module.vpc.private_subnets` — EKS nodes in private subnets is correct, but confirm the VPC has the `kubernetes.io/cluster/<name>` subnet tags in addition to the ELB tags. The EKS module usually handles this but worth checking. |
| 24 | `eks.tf` L10 | `cluster_endpoint_public_access = true` with no CIDR restriction. The EKS API server is open to `0.0.0.0/0`. Add `cluster_endpoint_public_access_cidrs` with your IP(s) or the GitHub Actions IP ranges. |
| 25 | `rds.tf` L45 | `skip_final_snapshot = true` — fine for dev/learning, **not OK for any data you care about**. RDS will be deleted with zero backup when you `terraform destroy`. |
| 26 | `rds.tf` | No `backup_retention_period` set — defaults to 0 (backups disabled). Set to at least `7` for any real data. |
| 27 | `ecr.tf` L3 | `image_tag_mutability = "MUTABLE"` — the `:latest` tag can be overwritten silently. Switch to `"IMMUTABLE"` to ensure every tag points to the exact digest that was pushed. The CI pipeline already pushes by commit SHA so this is a safe change. |
| 28 | `eks.tf` L22 | `capacity_type = "SPOT"` — SPOT nodes can be interrupted with 2 minutes notice. With `desired_size = 1` and `max_size = 2`, a SPOT interruption will cause downtime. Use at least 2 SPOT nodes or mix SPOT + ON_DEMAND. |
| 29 | `infra/terraform.tfvars` | Likely contains `db_password` in plaintext. If this file is ever committed it's a credential leak. Confirm it's in `.gitignore`. |

### 🟢 Good Practices

- Common tags applied everywhere via `local.common_tags` ✓
- `enable_irsa = true` on EKS for fine-grained workload IAM ✓
- ECR `scan_on_push = true` for vulnerability scanning ✓
- `publicly_accessible = false` on RDS ✓
- RDS in private subnets, security group only allows EKS node SG ✓
- `kubernetes_secret` created via Terraform (consistent infra-as-code pattern) ✓
- Helpful `kubeconfig_command` output ✓

---

## 5. Kubernetes Manifests (`k8s/`)

### 🔴 Blockers

| # | File | Issue |
|---|------|-------|
| 30 | `deployment.yaml` L19 | `image: IMAGE_PLACEHOLDER` — this is correct if the CI/CD pipeline does the `sed` substitution **before** `kubectl apply`. But if someone runs `kubectl apply -f k8s/` manually the pod will fail to pull with `ErrImagePull`. Document clearly that this file must be processed by CI. |
| 31 | `k8s/monitoring/grafana-dashboard.yaml` L10-12 | The ConfigMap `data` block contains **a YAML comment, not actual JSON**. Kubernetes will create the ConfigMap but Grafana will have an empty dashboard. The comment says this is intentional for manual import, but if the CI job applies it, it will overwrite any manually imported panels. Either paste the real JSON or don't apply this file via CI. |

### 🟡 Warnings

| # | File | Issue |
|---|-------|-------|
| 32 | `deployment.yaml` L8 | `replicas: 1` — comment even says "run at least 2 for high availability". With EKS SPOT nodes and 1 replica, any node interruption causes downtime. Set `replicas: 2`. |
| 33 | `deployment.yaml` | No `namespace` specified — defaults to `default`. For production, use a dedicated namespace (`journal`, `app`) to isolate workloads. |
| 34 | `deployment.yaml` | No **Pod Disruption Budget (PDB)** — with 1 replica, a rolling update or node drain will cause 100% downtime. Add a `PodDisruptionBudget` with `minAvailable: 1`. |
| 35 | `deployment.yaml` L36-43 | `livenessProbe` and `readinessProbe` have the same config. `livenessProbe` should have a higher `failureThreshold` (e.g., 3) and longer `initialDelaySeconds` (e.g., 15) to avoid premature pod killing during startup. |
| 36 | `service.yaml` L9 | `type: LoadBalancer` provisions a **Classic ELB** by default on AWS. This is the older (more expensive, less capable) load balancer. Add the annotation `service.beta.kubernetes.io/aws-load-balancer-type: "nlb"` for a Network Load Balancer, or better yet, use an **Ingress + ALB Ingress Controller**. |
| 37 | `service.yaml` | Service exposes port 80 (HTTP) to the internet with no TLS. For a real deployment you need HTTPS. Add an ALB Ingress with ACM certificate, or at least document this gap. |
| 38 | `monitoring/servicemonitor.yaml` L7 | `release: prometheus-stack` label must exactly match what the Prometheus Operator's `serviceMonitorSelector` is configured to pick up. If Prometheus was installed with a different release name, this label won't be matched and metrics won't be scraped. |

### 🟢 Good Practices

- `livenessProbe` and `readinessProbe` both configured ✓
- Resource `requests` and `limits` are set ✓
- `envFrom: secretRef` — secrets injected from Kubernetes Secret, not hardcoded ✓
- `secrets.yaml.example` as a reference template (not committed with real data) ✓

---

## 6. CI/CD (`.github/workflows/dev-impl.yml`)

### 🔴 Blockers

| # | Issue |
|---|-------|
| 39 | `deploy` job runs `kubectl apply -f k8s/` — this applies **all files recursively in `k8s/`**, including `k8s/monitoring/`. This means the empty `grafana-dashboard.yaml` ConfigMap (with comment-only data) gets applied every deploy, potentially wiping Grafana dashboards. |
| 40 | `monitoring` job installs Helm + Prometheus on **every push to main**. `helm upgrade --install` is safe but it will re-apply and potentially restart Prometheus pods unnecessarily. Consider making this a separate manual workflow or using a condition to run only when monitoring config changes. |

### 🟡 Warnings

| # | Issue |
|---|-------|
| 41 | `aws-actions/configure-aws-credentials@v2` — v2 is outdated. Use `@v4` (supports OIDC / OpenID Connect). With **OIDC you don't need `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` secrets at all** — GitHub gets a short-lived token from AWS directly. This is much more secure than long-lived IAM keys. |
| 42 | `docker/build-push-action@v4` and `setup-buildx-action@v2` — outdated. Use `@v6` and `@v3` respectively. |
| 43 | The deployment job has `--name journal-cluster` hardcoded, while cluster name comes from `var.project_name` in Terraform. If the variable ever changes, CI breaks. Use a GitHub secret or env var for the cluster name. |
| 44 | No `environment:` protection rule on the `deploy` job. Anyone who merges to main deploys to production with no manual approval gate. |
| 45 | `deploy` job only runs on push to `main`. On a `pull_request` the test runs but build/deploy don't. This is fine but PRs won't validate that the Docker image actually builds. Consider adding a `build-only` (no push) step on PRs. |
| 46 | The `build-and-push.yml` file is entirely commented out — dead code. Either remove it or note it's superseded by `dev-impl.yml`. |

### 🟢 Good Practices

- `needs: test` gate — build only if tests pass ✓
- Git SHA used as Docker image tag (immutable, reproduceable) ✓
- Docker layer caching with GitHub Actions cache ✓
- `--health-cmd pg_isready` on service container ✓
- Postgres service container for real integration tests ✓
- `database_setup.sql` applied before pytest ✓
- Ruff linting step before tests ✓

---

## 7. Tests (`tests/`)

### 🟡 Warnings

| # | Issue |
|---|-------|
| 47 | Tests for `GET /entries/{id}`, `DELETE /entries/{id}`, and `POST /entries/{id}/analyze` will currently **pass only by testing the 501 / error path**, not the happy path. Once you implement the endpoints the tests need updating. |
| 48 | `test_create_entry_exceeds_max_length` validates a "256 character limit" — but checking `api/models/entry.py` (not shown here but inferred from the test) may or may not actually enforce `max_length=255`. Confirm the Pydantic model has `Field(max_length=256)`. |
| 49 | `conftest.py` uses `autouse=True` with a cleanup fixture that opens a DB connection before **every** test. This adds latency. A faster approach is to wrap each test in a transaction and rollback instead of running `DELETE FROM entries`. |
| 50 | No `pytest-asyncio` mode set in `pytest.ini` or `pyproject.toml`. Tests are `async def` but without `asyncio_mode = "auto"`, pytest-asyncio won't pick them up. Check your `pytest.ini`. |

### 🟢 Good Practices

- Good test class organization by endpoint ✓
- Happy path + error path tested ✓
- `autouse` cleanup ensures test isolation ✓
- Using `ASGITransport` for fast in-process testing (no real server needed) ✓

---

## 8. Security Checklist

| Check | Status | Notes |
|-------|--------|-------|
| `.env` in `.gitignore` | ✅ Assumed (verify) | `.env-sample` exists, actual `.env` must be ignored |
| `terraform.tfvars` in `.gitignore` | ⚠️ Verify | Contains plaintext DB password |
| `terraform.tfstate` in `.gitignore` | 🔴 Likely NOT | State is local and in the `infra/` dir. Should be remote (S3) |
| DB password in Terraform state | 🔴 Yes | `kubernetes-secrets.tf` writes the password into state |
| Secrets in k8s created by Terraform | ✅ Better than manifests | But state is still unencrypted locally |
| Docker image runs as root | 🔴 Yes | Add non-root user in Dockerfile |
| EKS API server open to internet | 🟡 Yes | Restrict with `cluster_endpoint_public_access_cidrs` |
| Long-lived IAM keys in CI | 🟡 Yes | Migrate to OIDC (`aws-actions/configure-aws-credentials@v4`) |
| ECR MUTABLE tags | 🟡 Yes | Switch to `IMMUTABLE` |
| No HTTPS on k8s Service | 🔴 Yes | Only HTTP/80, no TLS |

---

## 9. Architecture Gaps (for a real deployment)

These aren't bugs but things you'll hit the moment you deploy:

1. **No Ingress Controller** — `LoadBalancer` type provisions a Classic ELB per service, which is expensive and limited. Install AWS Load Balancer Controller + use `Ingress` instead.
2. **No TLS/HTTPS** — The API is HTTP-only. You need an ACM certificate + ALB Ingress annotation or cert-manager.
3. **No remote Terraform backend** — Running Terraform from two places (local + CI) with no state locking = corruption.
4. **No namespace isolation** — Everything in `default`. Separate `app`, `monitoring` namespaces are a must.
5. **No Horizontal Pod Autoscaler (HPA)** — The app can't scale under load. Add an HPA targeting CPU at 70%.
6. **No image lifecycle policy on ECR** — Every push pushes a new image. ECR will grow forever. Add a lifecycle rule to keep only the last N images.
7. **EKS 1.27 is EOL** — AWS will auto-upgrade you, this can be disruptive.
8. **No database migration strategy** — `database_setup.sql` is only run manually in CI. When you add columns later you need a migration tool (Alembic, Flyway, or even a simple K8s Job).
9. **LLM feature is completely missing** — `llm_service.py` is a stub. Before deploying the analyze endpoint you need to pick a provider (OpenAI, Anthropic, AWS Bedrock) and add its API key to Kubernetes secrets.

---

## 10. Priority Fix List (Deploy Order)

For a successful first deployment, fix these in order:

```
1. 🔴 Fix rds.tf egress CIDR typo: "0.0.0.0/16" → "0.0.0.0/0"
2. 🔴 Add Terraform remote backend (S3 + DynamoDB locking)   
3. 🔴 Implement GET /entries/{id} and DELETE /entries/{id}    
4. 🔴 Add logging.basicConfig() to main.py                   
5. 🔴 Bump EKS version from 1.27 to 1.30                     
6. 🔴 Add USER appuser to Dockerfile + fix layer order        
7. 🔴 Fix grafana-dashboard.yaml (real JSON or exclude from CI apply)
8. 🟡 Add db_username variable to Terraform                   
9. 🟡 Move to OIDC in GitHub Actions (remove long-lived keys) 
10. 🟡 Switch ECR to IMMUTABLE image tags                     
11. 🟡 Set replicas: 2 in deployment.yaml                     
12. 🟡 Add connection pool at startup (not per-request)       
13. 🟡 Add Pydantic validation to update_entry endpoint       
```
