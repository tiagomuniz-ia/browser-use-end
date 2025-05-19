# syntax=docker/dockerfile:1
# check=skip=SecretsUsedInArgOrEnv

FROM python:3.11-slim

LABEL name="browseruse-api" \
    maintainer="Your Name <your.email@example.com>" \
    description="API for Browser Use - Make websites accessible for AI agents" \
    homepage="https://github.com/your-repo/browser-use" \
    documentation="https://docs.browser-use.com"

ARG TARGETPLATFORM
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT

######### Environment Variables #################################

ENV TZ=UTC \
    LANGUAGE=en_US:en \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8 \
    DEBIAN_FRONTEND=noninteractive \
    APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 \
    PYTHONIOENCODING=UTF-8 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    IN_DOCKER=True \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

# User config
ENV BROWSERUSE_USER="browseruse" \
    DEFAULT_PUID=911 \
    DEFAULT_PGID=911

# Paths
ENV CODE_DIR=/app \
    DATA_DIR=/data \
    VENV_DIR=/app/.venv \
    PATH="/app/.venv/bin:$PATH"

# Build shell config
SHELL ["/bin/bash", "-o", "pipefail", "-o", "errexit", "-o", "errtrace", "-o", "nounset", "-c"]

# Install base dependencies including Chrome dependencies
RUN apt-get update -qq \
    && apt-get install -qq -y --no-install-recommends \
        apt-transport-https \
        ca-certificates \
        apt-utils \
        gnupg2 \
        unzip \
        curl \
        wget \
        grep \
        nano \
        iputils-ping \
        dnsutils \
        jq \
        libnss3 \
        libxss1 \
        libasound2 \
        libx11-xcb1 \
        libxcomposite1 \
        libxdamage1 \
        libxrandr2 \
        libatk1.0-0 \
        libatk-bridge2.0-0 \
        libpangocairo-1.0-0 \
        libgtk-3-0 \
        libgbm1 \
        xvfb \
        xauth \
        fonts-liberation \
        fonts-noto-color-emoji \
        fonts-noto-cjk \
    && rm -rf /var/lib/apt/lists/*

# Create non-privileged user
RUN groupadd --system $BROWSERUSE_USER \
    && useradd --system --create-home --gid $BROWSERUSE_USER --groups audio,video $BROWSERUSE_USER \
    && usermod -u "$DEFAULT_PUID" "$BROWSERUSE_USER" \
    && groupmod -g "$DEFAULT_PGID" "$BROWSERUSE_USER" \
    && mkdir -p /data \
    && mkdir -p /home/$BROWSERUSE_USER/.config \
    && mkdir -p /ms-playwright \
    && chown -R $BROWSERUSE_USER:$BROWSERUSE_USER /home/$BROWSERUSE_USER \
    && chown -R $BROWSERUSE_USER:$BROWSERUSE_USER /ms-playwright \
    && ln -s $DATA_DIR /home/$BROWSERUSE_USER/.config/browseruse

# Set up Python environment
WORKDIR /app
COPY pyproject.toml /app/

# Install Python dependencies and Playwright
RUN python -m venv $VENV_DIR \
    && . $VENV_DIR/bin/activate \
    && pip install --no-cache-dir "browser-use[api]" fastapi uvicorn python-dotenv playwright \
    && playwright install-deps \
    && PLAYWRIGHT_BROWSERS_PATH=/ms-playwright playwright install chromium \
    && chown -R $BROWSERUSE_USER:$BROWSERUSE_USER /ms-playwright

# Copy application code
COPY . /app

# Set up data directory
RUN mkdir -p "$DATA_DIR/profiles/default" \
    && chown -R $BROWSERUSE_USER:$BROWSERUSE_USER "$DATA_DIR" "$DATA_DIR"/* \
    && chown -R $BROWSERUSE_USER:$BROWSERUSE_USER /app

USER "$BROWSERUSE_USER"
VOLUME "$DATA_DIR"

# Expose API port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=20s --retries=3 \
    CMD curl --silent 'http://localhost:8000/health' | grep -q 'healthy'

# Start the API with xvfb-run
CMD ["xvfb-run", "-a", "python", "api.py"]
