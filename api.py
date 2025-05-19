from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import asyncio
import os
from dotenv import load_dotenv
from langchain_google_genai import ChatGoogleGenerativeAI
from pydantic import SecretStr
from browser_use import Agent, BrowserConfig
from browser_use.browser.browser import Browser
from browser_use.browser.context import BrowserContextConfig

# Carrega variáveis de ambiente
load_dotenv()

app = FastAPI(title="Browser Use API")

class TaskRequest(BaseModel):
    task: str
    max_steps: int = 100
    max_actions_per_step: int = 4
    model: str = "gemini-2.0-flash"  # Modelo padrão

@app.post("/execute")
async def execute_task(request: TaskRequest):
    try:
        # Configuração do navegador
        browser = Browser(
            config=BrowserConfig(
                new_context_config=BrowserContextConfig(
                    viewport_expansion=0,
                )
            )
        )

        # Configuração do LLM
        api_key = os.getenv('GOOGLE_API_KEY')
        if not api_key:
            raise HTTPException(status_code=500, detail="GOOGLE_API_KEY não configurada")

        llm = ChatGoogleGenerativeAI(
            model=request.model,
            api_key=SecretStr(api_key)
        )

        # Criação e execução do agente
        agent = Agent(
            task=request.task,
            llm=llm,
            max_actions_per_step=request.max_actions_per_step,
            browser=browser,
        )

        # Executa a tarefa
        result = await agent.run(max_steps=request.max_steps)
        
        return {
            "status": "success",
            "result": result
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
