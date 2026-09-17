# Build stage: install locked dependencies and produce a standalone build.
FROM node:24.21.0-slim@sha256:2fe369e969550cde8e867afc3fe370b260140cab4a23d467074295b42163d553 AS builder

ENV NEXT_TELEMETRY_DISABLED=1

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

# Runtime stage: the standalone server, its static assets, nothing else.
FROM node:24.21.0-slim@sha256:2fe369e969550cde8e867afc3fe370b260140cab4a23d467074295b42163d553

ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    HOSTNAME=0.0.0.0 \
    PORT=3000

# Named individually rather than upgraded wholesale, which Docker's guidance
# advises against for parent-image packages.
RUN apt-get update \
    && apt-get install --yes --no-install-recommends --only-upgrade \
        libpcre2-8-0 \
    && rm -rf /var/lib/apt/lists/*

# The standalone server never invokes npm, and npm's bundled packages are this
# image's whole Node-package surface. The builder stage keeps it for `npm ci`.
RUN rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx

WORKDIR /app
# standalone omits public/ and .next/static; server.js serves them once copied in.
COPY --from=builder --chown=node:node /app/.next/standalone ./
COPY --from=builder --chown=node:node /app/.next/static ./.next/static
COPY --from=builder --chown=node:node /app/public ./public

USER node
EXPOSE 3000

# Uses the runtime already in the image; there is no dedicated health route.
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --start-interval=2s --retries=3 \
  CMD ["node", "-e", "fetch('http://127.0.0.1:3000/').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))"]

CMD ["node", "server.js"]
