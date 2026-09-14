# DevSecOps Pipeline

A security-integrated CI/CD pipeline — SAST, DAST, SCA, custom rules, policy
gates, and vulnerability management — built around **Tasklane**, a
multi-tenant project-management tool that serves as its target application.

> [!WARNING]
> Tasklane is a security testing target. Run it locally or in an ephemeral,
> access-restricted environment, and never expose it to a public network. Seed
> it with synthetic data only.

## Layout

| Path        | Contents                    |
| ----------- | --------------------------- |
| `frontend/` | Next.js (TypeScript) client |
| `backend/`  | FastAPI (Python) service    |

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
