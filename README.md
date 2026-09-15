# DevSecOps Pipeline

A security-integrated CI/CD pipeline — SAST, DAST, SCA, custom rules, policy
gates, and vulnerability management — built around **Tasklane**, a
multi-tenant project-management tool that serves as its target application.

> [!WARNING]
> Tasklane is a security testing target. Run it locally or in an ephemeral,
> access-restricted environment, and never expose it to a public network. Seed
> it with synthetic data only.

## Layout

| Path        | Contents                       |
| ----------- | ------------------------------ |
| `frontend/` | Next.js (TypeScript) client    |
| `backend/`  | FastAPI (Python) service       |
| `security/` | Custom scanner rules (Semgrep) |

## Running

The two services run independently.

**Development**

```bash
cd frontend && npm ci && npm run dev
```

```bash
cd backend && uv sync && uv run fastapi dev
```

**Production build**

```bash
cd frontend && npm ci && npm run build && npm run start
```

```bash
cd backend && uv sync && uv run fastapi run
```

The client serves on `http://localhost:3000` and the API on
`http://localhost:8000`, with its OpenAPI schema at `/openapi.json`.

## Pre-commit hooks

Gitleaks, ruff, and ESLint run locally before anything reaches CI.

```bash
uv tool install pre-commit
pre-commit install
```

The ESLint hook runs the frontend's own `npm run lint`, so `cd frontend && npm
ci` first if you haven't already. To run every hook against the full repo
instead of just staged files:

```bash
pre-commit run --all-files
```
