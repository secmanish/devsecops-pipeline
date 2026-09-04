from fastapi import FastAPI

app = FastAPI(title="Acme Portal API")


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}
