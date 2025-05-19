from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import asyncio
import os
import logging
from dotenv import load_dotenv
from langchain_google_genai import ChatGoogleGenerativeAI
from pydantic import SecretStr
from browser_use import Agent, BrowserConfig
from browser_use.browser.browser import Browser
from browser_use.browser.context import BrowserContextConfig

# Configuração de logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Carrega variáveis de ambiente
load_dotenv()
logger.info("Variáveis de ambiente carregadas")

app = FastAPI(title="Browser Use API")

class TaskRequest(BaseModel):
    task: str
    max_steps: int = 100
    max_actions_per_step: int = 4

@app.get("/")
async def root():
    """Endpoint raiz para verificar se a API está funcionando"""
    logger.info("Endpoint raiz acessado")
    return {"status": "API está funcionando"}

@app.get("/health")
async def health_check():
    """Endpoint para verificar a saúde da API"""
    logger.info("Health check realizado")
    return {"status": "healthy"}

@app.post("/execute")
async def execute_task(request: TaskRequest):
    try:
        logger.info(f"Iniciando execução da tarefa: {request.task}")
        
        # Verifica a chave da API do Google
        api_key = os.getenv('GOOGLE_API_KEY')
        if not api_key:
            logger.error("GOOGLE_API_KEY não configurada")
            raise HTTPException(status_code=500, detail="GOOGLE_API_KEY não configurada")

        logger.info("Configurando LLM")
        # Configuração do LLM
        llm = ChatGoogleGenerativeAI(
            model='gemini-2.0-flash',
            api_key=SecretStr(api_key)
        )

        logger.info("Configurando navegador")
        # Configuração do navegador
        browser = Browser(
            config=BrowserConfig(
                new_context_config=BrowserContextConfig(
                    viewport_expansion=0,
                    headless=True,  # Importante para Docker
                )
            )
        )

        logger.info("Criando agente")
        # Criação e execução do agente
        agent = Agent(
            task=request.task,
            llm=llm,
            max_actions_per_step=request.max_actions_per_step,
            browser=browser,
        )

        logger.info("Executando tarefa")
        # Executa a tarefa
        result = await agent.run(max_steps=request.max_steps)
        
        logger.info("Tarefa concluída com sucesso")
        return {
            "status": "success",
            "result": result
        }

    except Exception as e:
        logger.error(f"Erro durante a execução: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    host = os.getenv("HOST", "0.0.0.0")
    logger.info(f"Iniciando servidor na porta {port} e host {host}")
    uvicorn.run(app, host=host, port=port)
