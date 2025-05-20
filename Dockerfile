FROM mcr.microsoft.com/playwright/python:v1.41.0-jammy

WORKDIR /app

COPY . .

RUN pip install -e .

CMD ["python", "-m", "uvicorn", "api:app", "--host", "0.0.0.0", "--port", "8000"]
