# syntax=docker/dockerfile:1
FROM python:3.11-bookworm

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    DEBIAN_FRONTEND=noninteractive \
    # Definir DISPLAY globalmente. Xvfb usará isso.
    DISPLAY=:99

# Instalação das dependências do sistema
RUN apt-get update -qq && \
    apt-get install -qq -y --no-install-recommends \
    xvfb \
    xauth \
    dbus-x11 \
    # Adicionar 'dbus' para garantir que o serviço possa ser iniciado
    dbus \
    x11-xkb-utils \
    xfonts-base \
    xfonts-100dpi \
    xfonts-75dpi \
    xfonts-scalable \
    libnss3 libxss1 libasound2 libx11-xcb1 libatk1.0-0 libatk-bridge2.0-0 \
    libcups2 libdrm2 libdbus-1-3 libxkbcommon0 libxcomposite1 libxdamage1 \
    libxfixes3 libxrandr2 libgbm1 libpango-1.0-0 libcairo2 libfontconfig1 \
    libfreetype6 libjpeg62-turbo libpng16-16 libxext6 libxrender1 libxtst6 \
    libglib2.0-0 libgtk-3-0 libnspr4 libexpat1 \
    wget curl gnupg2 ca-certificates apt-transport-https && \
    rm -rf /var/lib/apt/lists/*

# Criação do usuário não-root
RUN groupadd --system --gid 911 browseruse && \
    useradd --system --uid 911 --gid 911 --create-home --shell /bin/bash browseruse

WORKDIR /app

# Copia os arquivos de configuração do projeto
COPY --chown=browseruse:browseruse pyproject.toml README.md ./

# Copia o código da aplicação
COPY --chown=browseruse:browseruse browser_use ./browser_use
COPY --chown=browseruse:browseruse api.py ./

# Muda para o usuário não-root
USER browseruse

# Define o PATH para incluir os binários instalados pelo pip do usuário
ENV PATH="/home/browseruse/.local/bin:${PATH}" \
    # Garante que o Playwright saiba onde encontrar seus navegadores
    PLAYWRIGHT_BROWSERS_PATH="/home/browseruse/.cache/ms-playwright"

# Instala as dependências Python e o browser-use em modo editável
RUN pip install --no-cache-dir --user -e .[api] && \
    # Garante que o diretório do cache exista e tenha as permissões corretas ANTES de instalar
    mkdir -p /home/browseruse/.cache/ms-playwright && \
    chown -R browseruse:browseruse /home/browseruse/.cache && \
    playwright install chromium && \
    # Limpa o cache do pip após a instalação
    rm -rf /home/browseruse/.cache/pip

# Expõe a porta da aplicação
EXPOSE 8000

# Criar um script de entrada para gerenciar D-Bus e Xvfb
COPY --chown=browseruse:browseruse entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Comando para iniciar a aplicação através do entrypoint.sh
CMD ["/app/entrypoint.sh"]
