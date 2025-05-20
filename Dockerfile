# syntax=docker/dockerfile:1
FROM python:3.11-bookworm

ENV TZ=UTC \
    LANGUAGE=en_US:en \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8 \
    DEBIAN_FRONTEND=noninteractive \
    PYTHONIOENCODING=UTF-8 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    IN_DOCKER=True

# Instalar dependências do sistema essenciais para Xvfb, X11 e Playwright
RUN apt-get update -qq && \
    apt-get install -qq -y --no-install-recommends \
    # Essenciais para Xvfb e X11
    xvfb \
    xauth \
    x11-xkb-utils \
    xfonts-base \
    xfonts-cyrillic \
    xfonts-100dpi \
    xfonts-75dpi \
    xfonts-scalable \
    # Dependências comuns do Playwright e navegadores
    libnss3 libxss1 libasound2 libx11-xcb1 libatk1.0-0 libatk-bridge2.0-0 \
    libcups2 libdrm2 libdbus-1-3 libxkbcommon0 libxcomposite1 libxdamage1 \
    libxfixes3 libxrandr2 libgbm1 libpango-1.0-0 libcairo2 libfontconfig1 \
    libfreetype6 libjpeg62-turbo libpng16-16 libxext6 libxrender1 libxtst6 \
    libglib2.0-0 libgtk-3-0 libnspr4 libexpat1 \
    # Utilitários
    wget curl gnupg2 ca-certificates apt-transport-https && \
    rm -rf /var/lib/apt/lists/*

# Criar usuário não-privilegiado
ENV BROWSERUSE_USER="browseruse" \
    APP_USER_UID=911 \
    APP_USER_GID=911

RUN groupadd --system --gid $APP_USER_GID $BROWSERUSE_USER && \
    useradd --system --uid $APP_USER_UID --gid $APP_USER_GID --create-home --shell /bin/bash $BROWSERUSE_USER

WORKDIR /app

# Copiar arquivos do projeto
COPY --chown=$BROWSERUSE_USER:$BROWSERUSE_USER pyproject.toml README.md ./
COPY --chown=$BROWSERUSE_USER:$BROWSERUSE_USER browser_use ./browser_use
COPY --chown=$BROWSERUSE_USER:$BROWSERUSE_USER api.py ./

# Instalar dependências Python como o usuário da aplicação
USER $BROWSERUSE_USER
RUN pip install --no-cache-dir -e .

# Instalar Playwright e suas dependências de navegador como o usuário da aplicação
# PLAYWRIGHT_BROWSERS_PATH será automaticamente configurado para o cache do usuário
ENV PLAYWRIGHT_BROWSERS_PATH=/home/$BROWSERUSE_USER/.cache/ms-playwright
RUN pip install --no-cache-dir playwright && \
    playwright install --with-deps chromium

USER root
RUN mkdir -p /data/profiles/default && \
    chown -R $BROWSERUSE_USER:$BROWSERUSE_USER /data
USER $BROWSERUSE_USER


ENV DISPLAY=:99

# Comando para iniciar a aplicação com Xvfb
# --auto-servernum tenta encontrar um número de display livre
# --server-num=0 especifica um número de display (se :99 for problemático)
CMD ["xvfb-run", "--auto-servernum", "--server-args='-screen 0 1280x800x24'", "python", "-m", "uvicorn", "api:app", "--host", "0.0.0.0", "--port", "8000"]
