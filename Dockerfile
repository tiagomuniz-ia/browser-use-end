FROM mcr.microsoft.com/playwright/python:v1.41.0-jammy

WORKDIR /app

# Copiar apenas os arquivos necessários primeiro
COPY pyproject.toml README.md ./
COPY browser_use ./browser_use
COPY api.py ./

# Instalar o pacote em modo editável
RUN pip install --no-cache-dir -e .

# Instalar o navegador
RUN playwright install chromium

# Configurar permissões para o Playwright
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

CMD ["python", "-m", "uvicorn", "api:app", "--host", "0.0.0.0", "--port", "8000"]
