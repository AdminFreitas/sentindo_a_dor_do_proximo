import logging
import uuid

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

logger = logging.getLogger("sdp")


class ApiError(Exception):
    """
    Erro de negocio/autorizacao com codigo publico estavel. Ver SDP_API.md
    (formato padrao de erro) e a regra de "nunca expor stack trace" em
    SDP_ROADMAP_DESENVOLVIMENTO.md / SDP_API.md secao 7.1.
    """

    def __init__(self, status_code: int, code: str, message: str):
        self.status_code = status_code
        self.code = code
        self.message = message


def _error_body(code: str, message: str, request_id: str) -> dict:
    return {"error": {"code": code, "message": message, "request_id": request_id}}


def registrar_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(ApiError)
    async def handle_api_error(request: Request, exc: ApiError):
        request_id = str(uuid.uuid4())
        return JSONResponse(
            status_code=exc.status_code,
            content=_error_body(exc.code, exc.message, request_id),
        )

    @app.exception_handler(Exception)
    async def handle_unexpected(request: Request, exc: Exception):
        request_id = str(uuid.uuid4())
        # Detalhe completo so no log interno - nunca na resposta ao cliente.
        logger.exception("Erro nao tratado [request_id=%s]", request_id)
        return JSONResponse(
            status_code=500,
            content=_error_body(
                "INTERNAL_ERROR",
                "Ocorreu um erro interno. Tente novamente mais tarde.",
                request_id,
            ),
        )
