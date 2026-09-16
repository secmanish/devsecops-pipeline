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

# Debian has published a fix for this; this base image predates it. Named
# individually rather than upgraded wholesale, which Docker's own guidance
# advises against for parent-image packages.
RUN apt-get update \
    && apt-get install --yes --no-install-recommends --only-upgrade \
        libpcre2-8-0 \
    && rm -rf /var/lib/apt/lists/*

# The standalone server starts with `node server.js` and never invokes npm.
# What npm bundles is the whole of this image's Node-package surface, so it goes
# with it. The builder stage above still has npm, which is where `npm ci` runs.
RUN rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx

WORKDIR /app
# standalone omits public/ and .next/static; server.js serves them once copied in.
COPY --from=builder --chown=node:node /app/.next/standalone ./
COPY --from=builder --chown=node:node /app/.next/static ./.next/static
COPY --from=builder --chown=node:node /app/public ./public

USER node
EXPOSE 3000
CMD ["node", "server.js"]
