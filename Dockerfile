# syntax=docker/dockerfile:1

# Frontend Build Stage
FROM --platform=$BUILDPLATFORM node:22-alpine3.20 AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --production
COPY . .
ENV APP_BUILD_HASH=dev-build
RUN npm run build

# Backend Stage
FROM python:3.11-slim-bookworm AS base

ENV ENV=prod \
    PORT=8080 \
    OLLAMA_BASE_URL="" \
    OPENAI_API_BASE_URL="" \
    WEBUI_SECRET_KEY="" \
    SCARF_NO_ANALYTICS=true \
    DO_NOT_TRACK=true \
    ANONYMIZED_TELEMETRY=false

WORKDIR /app/backend

# Install minimal system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY ./backend/requirements.txt .
RUN pip3 install uv && \
    uv pip install --system -r requirements.txt --no-cache-dir

# Copy frontend build
COPY --from=build /app/build /app/build
COPY --from=build /app/CHANGELOG.md /app/CHANGELOG.md
COPY --from=build /app/package.json /app/package.json

# Copy backend files
COPY ./backend .

EXPOSE 8080

HEALTHCHECK CMD curl --silent --fail http://localhost:${PORT:-8080}/health || exit 1

ENV WEBUI_BUILD_VERSION=dev-build
ENV DOCKER=true

CMD ["bash", "start.sh"]
