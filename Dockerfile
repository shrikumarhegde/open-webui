# syntax=docker/dockerfile:1

# Frontend Build Stage
FROM --platform=$BUILDPLATFORM node:22-alpine3.20 AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --production  # Install only production dependencies
COPY . .
ENV APP_BUILD_HASH=dev-build
RUN npm run build

# Backend Stage
FROM python:3.11-slim-bookworm AS base

# Build Arguments (disable CUDA and Ollama, keep defaults minimal)
ARG USE_CUDA=false
ARG USE_OLLAMA=false
ARG USE_EMBEDDING_MODEL=sentence-transformers/all-MiniLM-L6-v2
ARG BUILD_HASH=dev-build

# Environment Variables
ENV ENV=prod \
    PORT=8080 \
    USE_OLLAMA_DOCKER=${USE_OLLAMA} \
    USE_CUDA_DOCKER=${USE_CUDA} \
    RAG_EMBEDDING_MODEL=${USE_EMBEDDING_MODEL} \
    OLLAMA_BASE_URL="" \
    OPENAI_API_BASE_URL="" \
    OPENAI_API_KEY="" \
    WEBUI_SECRET_KEY="" \
    SCARF_NO_ANALYTICS=true \
    DO_NOT_TRACK=true \
    ANONYMIZED_TELEMETRY=false

WORKDIR /app/backend

# Install minimal system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl jq && \
    rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY ./backend/requirements.txt .
RUN pip3 install uv && \
    # Install torch for CPU only, minimal requirements
    pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu --no-cache-dir && \
    uv pip install --system -r requirements.txt --no-cache-dir

# Copy frontend build
COPY --from=build /app/build /app/build
COPY --from=build /app/CHANGELOG.md /app/CHANGELOG.md
COPY --from=build /app/package.json /app/package.json

# Copy backend files
COPY ./backend .

EXPOSE 8080

# Healthcheck
HEALTHCHECK CMD curl --silent --fail http://localhost:${PORT:-8080}/health | jq -ne 'input.status == true' || exit 1

ENV WEBUI_BUILD_VERSION=${BUILD_HASH}
ENV DOCKER=true

CMD ["bash", "start.sh"]
