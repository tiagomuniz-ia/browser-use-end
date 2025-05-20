# syntax=docker/dockerfile:1
FROM mcr.microsoft.com/playwright:v1.41.0-jammy

# Configuração do ambiente
ENV PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive \
    IN_DOCKER=true

# Instalação de dependências do sistema
RUN apt-get update && apt-get install -y \
    python3-pip \
    python3-venv \
    xvfb \
    xauth \
    && rm -rf /var/lib/apt/lists/*

# Criação do diretório da aplicação
WORKDIR /app

# Instalação das dependências Python diretamente
RUN python3 -m pip install --no-cache-dir \
    fastapi \
    uvicorn \
    python-dotenv \
    "browser-use[api]" \
    playwright

# Copia dos arquivos da aplicação
COPY . .

# Configuração do usuário não-root
RUN useradd -m browseruse && \
    chown -R browseruse:browseruse /app

USER browseruse

# Comando para iniciar a aplicação com Xvfb
CMD ["xvfb-run", "--server-args='-screen 0 1280x800x24'", "python3", "-m", "uvicorn", "api:app", "--host", "0.0.0.0", "--port", "8000"]
