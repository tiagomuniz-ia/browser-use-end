# syntax=docker/dockerfile:1
FROM python:3.11-bookworm

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    DEBIAN_FRONTEND=noninteractive \
    # Define o display para o Xvfb
    DISPLAY=:99

# Instalação das dependências do sistema, incluindo xvfb, xauth, dbus e outras bibliotecas gráficas
RUN apt-get update -qq && \
    apt-get install -qq -y --no-install-recommends \
    xvfb \
    xauth \
    dbus-x11 \  # Importante para a comunicação com o D-Bus
    x11-xkb-utils \
    xfonts-base \
    xfonts-100dpi \
    xfonts-75dpi \
    xfonts-scalable \
    # Dependências do Playwright/Chromium
    libnss3 libxss1 libasound2 libx11-xcb1 libatk1.0-0 libatk-bridge2.0-0 \
    libcups2 libdrm2 libdbus-1-3 libxkbcommon0 libxcomposite1 libxdamage1 \
    libxfixes3 libxrandr2 libgbm1 libpango-1.0-0 libcairo2 libfontconfig1 \
    libfreetype6 libjpeg62-turbo libpng16-16 libxext6 libxrender1 libxtst6 \
    libglib2.0-0 libgtk-3-0 libnspr4 libexpat1 \
    # Utilitários
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
ENV PATH="/home/browseruse/.local/bin:${PATH}"

# Instala as dependências Python e o browser-use em modo editável
RUN pip install --no-cache-dir --user -e .[api] && \
    # Instala o Playwright e o Chromium (como usuário 'browseruse')
    # O --with-deps já foi tratado pela instalação de sistema, mas mantemos para garantir
    playwright install --with-deps chromium

# Expõe a porta da aplicação
EXPOSE 8000

# Comando para iniciar a aplicação com xvfb-run
# O -a faz o Xvfb escolher um número de display automaticamente se o :99 estiver ocupado
# O -s "-screen 0 1920x1080x24" define a resolução da tela virtual
CMD ["xvfb-run", "-a", "-s", "-screen 0 1920x1080x24", "uvicorn", "api:app", "--host", "0.0.0.0", "--port", "8000"]
