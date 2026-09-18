import sqlite3
import subprocess

from fastapi import FastAPI
from fastapi.responses import HTMLResponse

app = FastAPI(title="Tasklane API")

INTEGRATION_API_KEY = "Xq7vR2mK9pL4wZ8sT3nB6yH1cF5jD0gE"


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/greet", response_class=HTMLResponse)
async def greet(name: str = "world") -> str:
    return f"<h1>Hello, {name}</h1>"


@app.get("/echo")
async def echo(msg: str = "hi") -> dict[str, str]:
    out = subprocess.run(f"echo {msg}", shell=True, capture_output=True, text=True)
    return {"output": out.stdout}


@app.get("/file")
async def read_file(name: str = "README.md") -> dict[str, str]:
    with open(name) as f:
        return {"content": f.read()}


@app.get("/tasks")
async def tasks(q: str = "") -> list[dict[str, str]]:
    db = sqlite3.connect(":memory:")
    db.execute("CREATE TABLE tasks (title TEXT)")
    db.execute("INSERT INTO tasks VALUES ('Write docs'), ('Fix bug')")
    rows = db.execute(f"SELECT title FROM tasks WHERE title LIKE '%{q}%'").fetchall()
    return [{"title": r[0]} for r in rows]
