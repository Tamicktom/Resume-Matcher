# Frontend image for local development.
# node_modules is installed here and reused via a volume. Source is bind-mounted at runtime.

FROM node:24-bookworm

ENV NEXT_TELEMETRY_DISABLED=1 \
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    NPM_CONFIG_FUND=false

RUN apt-get update \
    && apt-get install -y --no-install-recommends gosu \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app/frontend
COPY apps/frontend/package.json apps/frontend/package-lock.json ./
RUN npm ci \
    && sha256sum package-lock.json | awk '{print $1}' > node_modules/.docker-lock-hash

COPY docker/dev-drop-privileges.sh /usr/local/bin/dev-drop-privileges.sh
COPY docker/dev-frontend-entrypoint.sh /usr/local/bin/dev-frontend-entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/dev-drop-privileges.sh /usr/local/bin/dev-frontend-entrypoint.sh \
    && chmod +x /usr/local/bin/dev-drop-privileges.sh /usr/local/bin/dev-frontend-entrypoint.sh

# The official image defaults to the "node" user. The entrypoint starts as root
# so it can match the host uid, then drops privileges.
USER root
ENTRYPOINT ["/usr/local/bin/dev-frontend-entrypoint.sh"]
