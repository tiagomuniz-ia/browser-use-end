FROM python:3.11-slim

# Instalar dependências do sistema necessárias para o Playwright
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    xvfb \
    libgconf-2-4 \
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libdbus-1-3 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    libpango-1.0-0 \
    libcairo2 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copiar arquivos do projeto
COPY pyproject.toml README.md ./
COPY browser_use ./browser_use
COPY api.py ./

# Instalar dependências Python e Playwright
RUN pip install --no-cache-dir -e . && \
    pip install playwright && \
    playwright install chromium && \
    playwright install-deps

# Configurar variáveis de ambiente
ENV PYTHONUNBUFFERED=1 \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright \
    IN_DOCKER=true

# Executar com Xvfb
CMD ["xvfb-run", "--server-args='-screen 0 1280x800x24'", "python", "-m", "uvicorn", "api:app", "--host", "0.0.0.0", "--port", "8000"]
