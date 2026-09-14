from fastapi import FastAPI

app = FastAPI(title="Tasklane API")


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}
