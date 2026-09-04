# Acme Portal API

The FastAPI backend for Acme Portal.

## Running

```bash
uv sync
uv run fastapi dev
```

The API serves on `http://localhost:8000`. Interactive documentation is at
`/docs` and the OpenAPI schema at `/openapi.json`.

## Commands

| Command               | Purpose                        |
| --------------------- | ------------------------------ |
| `uv sync`             | Install locked dependencies    |
| `uv run fastapi dev`  | Development server with reload |
| `uv run fastapi run`  | Production server              |
