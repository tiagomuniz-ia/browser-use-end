from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import asyncio
import os
import logging
import io
import re # Adicionado para regex
from dotenv import load_dotenv
from langchain_google_genai import ChatGoogleGenerativeAI
from pydantic import SecretStr
from browser_use import Agent, BrowserConfig
from browser_use.browser.browser import Browser
from browser_use.browser.context import BrowserContextConfig

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

load_dotenv()
logger.info("Variáveis de ambiente carregadas")

app = FastAPI(title="Browser Use API")

class TaskRequest(BaseModel):
    task: str
    max_steps: int = 100
    max_actions_per_step: int = 4
    return_only_response: bool = False # Novo parâmetro

@app.get("/")
async def root():
    logger.info("Endpoint raiz acessado")
    return {"status": "API está funcionando"}

@app.get("/health")
async def health_check():
    logger.info("Health check realizado")
    return {"status": "healthy"}

def extract_response_content(logs: str) -> str:
    """Extrai conteúdo entre crases triplas dos logs."""
    matches = re.findall(r"```(.*?)```", logs, re.DOTALL)
    return "\n".join(match.strip() for match in matches)

@app.post("/execute")
async def execute_task(request: TaskRequest):
    log_stream = io.StringIO()
    root_logger = logging.getLogger()
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    stream_handler = logging.StreamHandler(log_stream)
    stream_handler.setFormatter(formatter)
    stream_handler.setLevel(logging.INFO)
    root_logger.addHandler(stream_handler)
    
    task_result = None
    response_data = {}
    browser_instance: Browser | None = None 
    original_exception = None

    try:
        logger.info(f"Iniciando execução da tarefa: {request.task}")
        
        api_key = os.getenv('GOOGLE_API_KEY')
        if not api_key:
            logger.error("GOOGLE_API_KEY não configurada")
            raise HTTPException(status_code=500, detail="GOOGLE_API_KEY não configurada")

        logger.info("Configurando LLM")
        llm = ChatGoogleGenerativeAI(
            model='gemini-2.0-flash', # Certifique-se que este modelo está correto
            api_key=SecretStr(api_key)
        )

        logger.info("Configurando navegador")
        browser_instance = Browser(
            config=BrowserConfig(
                new_context_config=BrowserContextConfig(
                    viewport_expansion=0,
                    headless=True,
                )
            )
        )

        logger.info("Criando agente")
        agent = Agent(
            task=request.task,
            llm=llm,
            max_actions_per_step=request.max_actions_per_step,
            browser=browser_instance,
        )

        logger.info("Executando tarefa")
        task_result = await agent.run(max_steps=request.max_steps)
        
        logger.info("Tarefa concluída com sucesso")
        response_data = {
            "status": "success",
            "result": task_result
        }

    except Exception as e:
        original_exception = e
        logger.error(f"Erro durante a execução: {str(e)}", exc_info=True)
        if isinstance(e, HTTPException):
            response_data = { "status": "error", "detail": e.detail }
        else:
            response_data = { "status": "error", "detail": str(e) }
            
    finally:
        if browser_instance:
            logger.info("Fechando navegador...")
            try:
                await browser_instance.close()
                logger.info("Navegador fechado com sucesso.")
            except Exception as close_exc:
                logger.error(f"Erro ao fechar o navegador: {str(close_exc)}", exc_info=True)
        
        captured_logs_full = log_stream.getvalue() 
        root_logger.removeHandler(stream_handler)
        stream_handler.close()
        log_stream.close()

    # Lógica de filtragem de logs
    final_logs_to_return = captured_logs_full
    if request.return_only_response:
        extracted_content = extract_response_content(captured_logs_full)
        if extracted_content: 
            final_logs_to_return = extracted_content
        else: 
            final_logs_to_return = "Nenhum conteúdo específico de resposta encontrado nos logs."


    if "logs" not in response_data:
        response_data["logs"] = final_logs_to_return

    if original_exception:
        if isinstance(original_exception, HTTPException):
            if isinstance(original_exception.detail, dict):
                 original_exception.detail["logs"] = final_logs_to_return
            else:
                 original_exception.detail = {"message": original_exception.detail, "logs": final_logs_to_return}
            raise original_exception
        else:
            raise HTTPException(status_code=500, detail={"message": str(original_exception), "logs": final_logs_to_return})

    return response_data

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    host = os.getenv("HOST", "0.0.0.0")
    logger.info(f"Iniciando servidor na porta {port} e host {host}")
    uvicorn.run("api:app", host=host, port=port, reload=True)
