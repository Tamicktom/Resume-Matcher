# Backend image for local development.
# Dependencies and Chromium are baked in. Application code is bind-mounted at runtime.

FROM python:3.13-slim-bookworm

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON=/usr/local/bin/python \
    UV_PROJECT_ENVIRONMENT=/opt/venv \
    VIRTUAL_ENV=/opt/venv \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright \
    PATH="/opt/venv/bin:${PATH}"

ARG DEBIAN_MIRROR
ARG DEBIAN_SECURITY_MIRROR
RUN esc() { printf '%s' "$1" | sed 's/[&|\\]/\\&/g'; } \
    && if [ -n "${DEBIAN_MIRROR}" ]; then \
        sed -i "s|^URIs: http://deb.debian.org/debian\$|URIs: $(esc "${DEBIAN_MIRROR%/}")|" \
            /etc/apt/sources.list.d/debian.sources; \
    fi \
    && if [ -n "${DEBIAN_SECURITY_MIRROR}" ]; then \
        sed -i "s|^URIs: http://deb.debian.org/debian-security|URIs: $(esc "${DEBIAN_SECURITY_MIRROR%/}")|" \
            /etc/apt/sources.list.d/debian.sources; \
    fi

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean \
    && apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gosu \
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    libpango-1.0-0 \
    libcairo2 \
    libatspi2.0-0 \
    libgtk-3-0 \
    fonts-noto-cjk

RUN pip install --no-cache-dir uv

WORKDIR /app/backend
COPY apps/backend/pyproject.toml /app/backend/pyproject.toml

ARG PIP_INDEX_URL
RUN --mount=type=cache,target=/root/.cache/uv \
    if [ -n "${PIP_INDEX_URL}" ]; then export UV_DEFAULT_INDEX="${PIP_INDEX_URL}"; fi \
    && uv sync --no-install-project

ARG PLAYWRIGHT_DOWNLOAD_HOST
RUN python -m playwright install --only-shell chromium \
    && chmod -R a+rX /ms-playwright

COPY docker/dev-drop-privileges.sh /usr/local/bin/dev-drop-privileges.sh
COPY docker/dev-backend-entrypoint.sh /usr/local/bin/dev-backend-entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/dev-drop-privileges.sh /usr/local/bin/dev-backend-entrypoint.sh \
    && chmod +x /usr/local/bin/dev-drop-privileges.sh /usr/local/bin/dev-backend-entrypoint.sh

WORKDIR /app/backend
USER root
ENTRYPOINT ["/usr/local/bin/dev-backend-entrypoint.sh"]
