from fastapi import APIRouter, Cookie, Depends, Request, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import service
from app.auth.dependencies import get_current_user
from app.auth.schemas import LoginRequest, LoginResponse, UsuarioAutenticado
from app.config import settings
from app.database import get_db

router = APIRouter(prefix="/api/auth", tags=["auth"])


def _ip_do_cliente(request: Request) -> str | None:
    return request.client.host if request.client else None


@router.post("/login", response_model=LoginResponse)
async def login(
    payload: LoginRequest,
    response: Response,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    resultado = await service.autenticar(
        db, email=payload.email, senha=payload.senha, ip=_ip_do_cliente(request)
    )

    # Cookie de sessao - regra 10 de SDP_SEGURANCA.md.
    response.set_cookie(
        key=settings.session_cookie_name,
        value=resultado.token_sessao,
        httponly=True,
        secure=settings.session_cookie_secure,
        samesite="strict",
        max_age=settings.session_ttl_minutos * 60,
        path="/",
    )
    return resultado.response


@router.post("/logout", status_code=200)
async def logout(
    request: Request,
    response: Response,
    db: AsyncSession = Depends(get_db),
    sdp_session: str | None = Cookie(default=None),
):
    usuario_id: int | None = None
    if sdp_session:
        try:
            usuario = await get_current_user(request, db)
            usuario_id = usuario.id
        except Exception:
            # Sessao ja invalida - segue o logout mesmo assim (idempotente).
            pass
        await service.encerrar_sessao(db, token=sdp_session, usuario_id=usuario_id, ip=_ip_do_cliente(request))

    response.delete_cookie(key=settings.session_cookie_name, path="/")
    return {"detail": "logout realizado"}


@router.get("/me", response_model=UsuarioAutenticado)
async def me(usuario: UsuarioAutenticado = Depends(get_current_user)):
    """Endpoint de apoio para validar a sessao manualmente durante o desenvolvimento."""
    return usuario
