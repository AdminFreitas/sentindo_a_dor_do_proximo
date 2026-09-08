from fastapi import FastAPI

from app.auth.router import router as auth_router
from app.errors import registrar_error_handlers

app = FastAPI(title="Sentindo a Dor do Próximo — API")

registrar_error_handlers(app)

app.include_router(auth_router)


@app.get("/health", tags=["infra"])
async def health():
    return {"status": "ok"}
