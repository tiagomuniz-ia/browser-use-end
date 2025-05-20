FROM mcr.microsoft.com/playwright/python:v1.41.0-jammy

WORKDIR /app

COPY pyproject.toml .
COPY browser_use ./browser_use
COPY api.py .

RUN pip install --no-cache-dir -e .

CMD ["python", "-m", "uvicorn", "api:app", "--host", "0.0.0.0", "--port", "8000"]
