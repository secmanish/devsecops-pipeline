# Build stage: resolve and install locked dependencies into a venv.
FROM python:3.14.7-slim@sha256:cad9a2c871761c413caa6fdd6441c783451e740a48aaeba60ae62a8b53525ef6 AS builder

COPY --from=ghcr.io/astral-sh/uv:0.12.15@sha256:62f8c047d0a0e9ece6b53fc63df902585a67a47a7f318ddec4a37db586edc8e3 /uv /usr/local/bin/uv

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never

WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev

# Runtime stage: the venv and the application, nothing else.
FROM python:3.14.7-slim@sha256:cad9a2c871761c413caa6fdd6441c783451e740a48aaeba60ae62a8b53525ef6

# Named individually rather than upgraded wholesale, which Docker's guidance
# advises against for parent-image packages.
RUN apt-get update \
    && apt-get install --yes --no-install-recommends --only-upgrade \
        gzip \
        libpcre2-8-0 \
        libsqlite3-0 \
        perl-base \
    && rm -rf /var/lib/apt/lists/*

# The venv carries no seed packages, so neither is reached at runtime. A package
# manager in a runtime layer is attack surface rather than a feature.
RUN python -m pip uninstall --yes setuptools \
    && python -m pip uninstall --yes pip

RUN useradd --create-home --uid 10001 tasklane

WORKDIR /app
COPY --from=builder --chown=tasklane:tasklane /app/.venv ./.venv
COPY --chown=tasklane:tasklane app ./app

ENV PATH="/app/.venv/bin:$PATH"

USER tasklane
EXPOSE 8000
CMD ["fastapi", "run", "app/main.py", "--port", "8000"]
