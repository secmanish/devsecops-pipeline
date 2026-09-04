# DevSecOps Pipeline

A security-integrated CI/CD pipeline — SAST, DAST, SCA, custom rules, policy
gates, and vulnerability management — built around **Acme Portal**, a
multi-tenant invoice and expense portal that serves as its target application.

> [!WARNING]
> Acme Portal is a security testing target. Run it locally or in an ephemeral,
> access-restricted environment, and never expose it to a public network. Seed
> it with synthetic data only.

## Layout

| Path        | Contents                    |
| ----------- | --------------------------- |
| `frontend/` | Next.js (TypeScript) client |
| `backend/`  | FastAPI (Python) service    |

## Running

The two services run independently.

```bash
cd frontend && npm ci && npm run dev
```

```bash
cd backend && uv sync && uv run fastapi dev
```

The client serves on `http://localhost:3000` and the API on
`http://localhost:8000`, with its OpenAPI schema at `/openapi.json`.
