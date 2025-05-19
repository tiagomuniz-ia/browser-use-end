# syntax=docker/dockerfile:1
# check=skip=SecretsUsedInArgOrEnv

FROM python:3.11-slim

LABEL name="browseruse-api" \
    maintainer="Your Name <your.email@example.com>" \
    description="API for Browser Use - Make websites accessible for AI agents" \
    homepage="https://github.com/your-repo/browser-use" \
    documentation="https://docs.browser-use.com"

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
    DISPLAY=:99

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

# Install Chrome and dependencies
RUN apt-get update && apt-get install -y \
    wget \
    gnupg2 \
    apt-transport-https \
    ca-certificates \
    xvfb \
    xauth \
    && wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list \
    && apt-get update && apt-get install -y \
    google-chrome-stable \
    fonts-liberation \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libatspi2.0-0 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libx11-xcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libxshmfence1 \
    libxss1 \
    x11-apps \
    xdg-utils \
    && rm -rf /var/lib/apt/lists/*

# Create non-privileged user
RUN groupadd --system $BROWSERUSE_USER \
    && useradd --system --create-home --gid $BROWSERUSE_USER --groups audio,video $BROWSERUSE_USER \
    && usermod -u "$DEFAULT_PUID" "$BROWSERUSE_USER" \
    && groupmod -g "$DEFAULT_PGID" "$BROWSERUSE_USER" \
    && mkdir -p /data \
    && mkdir -p /home/$BROWSERUSE_USER/.config \
    && chown -R $BROWSERUSE_USER:$BROWSERUSE_USER /home/$BROWSERUSE_USER

# Set up Python environment
WORKDIR /app
COPY pyproject.toml /app/

# Install Python dependencies
RUN python -m venv $VENV_DIR \
    && . $VENV_DIR/bin/activate \
    && pip install --no-cache-dir "browser-use[api]" fastapi uvicorn python-dotenv playwright

# Install Playwright
RUN . $VENV_DIR/bin/activate \
    && playwright install-deps \
    && playwright install chromium

# Copy application code
COPY . /app

# Set up data directory
RUN mkdir -p "$DATA_DIR/profiles/default" \
    && chown -R $BROWSERUSE_USER:$BROWSERUSE_USER "$DATA_DIR" "$DATA_DIR"/* \
    && chown -R $BROWSERUSE_USER:$BROWSERUSE_USER /app

# Create Xauthority file
RUN touch /home/$BROWSERUSE_USER/.Xauthority \
    && chown $BROWSERUSE_USER:$BROWSERUSE_USER /home/$BROWSERUSE_USER/.Xauthority

USER "$BROWSERUSE_USER"
VOLUME "$DATA_DIR"

# Expose API port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=20s --retries=3 \
    CMD curl --silent 'http://localhost:8000/health' | grep -q 'healthy'

# Start Xvfb and the API
CMD Xvfb :99 -screen 0 1280x1024x24 -ac +extension GLX +render -noreset & \
    python api.py
