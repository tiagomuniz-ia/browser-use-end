# syntax=docker/dockerfile:1
FROM python:3.11-slim

ENV TZ=UTC \
    LANGUAGE=en_US:en \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8 \
    DEBIAN_FRONTEND=noninteractive \
    PYTHONIOENCODING=UTF-8 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    IN_DOCKER=True

# Criar usuário não-privilegiado
ENV BROWSERUSE_USER="browseruse" \
    DEFAULT_PUID=911 \
    DEFAULT_PGID=911

RUN groupadd --system $BROWSERUSE_USER \
    && useradd --system --create-home --gid $BROWSERUSE_USER --groups audio,video $BROWSERUSE_USER \
    && usermod -u "$DEFAULT_PUID" "$BROWSERUSE_USER" \
    && groupmod -g "$DEFAULT_PGID" "$BROWSERUSE_USER"

# Instalar dependências do sistema
RUN apt-get update -qq \
    && apt-get install -qq -y --no-install-recommends \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg2 \
        wget \
        xvfb \
        xauth \
        x11-xkb-utils \
        xfonts-base \
        xfonts-75dpi \
        xfonts-100dpi \
        libnss3 \
        libxss1 \
        libasound2 \
        libx11-xcb1 \
        libxcomposite1 \
        libxdamage1 \
        libxfixes3 \
        libxrandr2 \
        libgbm1 \
        libatk1.0-0 \
        libatk-bridge2.0-0 \
        libpango-1.0-0 \
        libcups2 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copiar arquivos do projeto
COPY pyproject.toml README.md ./
COPY browser_use ./browser_use
COPY api.py ./

# Instalar dependências Python e Playwright
RUN pip install --no-cache-dir -e . && \
    playwright install chromium && \
    playwright install-deps

# Configurar diretórios e permissões
RUN mkdir -p /data/profiles/default && \
    chown -R $BROWSERUSE_USER:$BROWSERUSE_USER /data && \
    chown -R $BROWSERUSE_USER:$BROWSERUSE_USER /app && \
    mkdir -p /tmp/.X11-unix && \
    chmod 1777 /tmp/.X11-unix

USER $BROWSERUSE_USER

ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright \
    DISPLAY=:99

# Executar com Xvfb
CMD ["xvfb-run", "--server-args='-screen 0 1280x800x24'", "python", "-m", "uvicorn", "api:app", "--host", "0.0.0.0", "--port", "8000"]
