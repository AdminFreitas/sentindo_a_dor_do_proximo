from fastapi import Cookie, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import repository
from app.auth.schemas import UsuarioAutenticado
from app.auth.security import hash_token_sessao
from app.config import settings
from app.database import get_db
from app.errors import ApiError


async def get_current_user(
    request: Request,
    db: AsyncSession = Depends(get_db),
) -> UsuarioAutenticado:
    """
    Fonte unica de verdade de autenticacao no backend (regra fundamental de
    SDP_SEGURANCA.md: Autenticacao -> Autorizacao -> ...). Nunca confiar em
    identidade enviada pelo cliente fora deste fluxo - regra 4.
    """
    token = request.cookies.get(settings.session_cookie_name)
    if not token:
        raise ApiError(401, "NOT_AUTHENTICATED", "Sessao ausente ou expirada.")

    sessao = await repository.buscar_sessao_valida(db, hash_token_sessao(token))
    if sessao is None:
        raise ApiError(401, "NOT_AUTHENTICATED", "Sessao ausente ou expirada.")

    from app.usuarios.models import Usuario  # import local evita ciclo

    result = await db.get(Usuario, sessao.usuario_id)
    if result is None or not result.ativo:
        raise ApiError(401, "NOT_AUTHENTICATED", "Sessao ausente ou expirada.")

    papeis = await repository.listar_papeis_do_usuario(db, result.id)
    return UsuarioAutenticado(id=result.id, email=result.email, papeis=papeis)


def exigir_papel(*papeis_permitidos: str):
    """
    Uso: Depends(exigir_papel("administrador", "gestor"))
    RBAC verificado sempre no backend (regra 5) - fonte unica de verdade e a
    tabela RBAC de SDP_DOCUMENTACAO_PROJETO.md secao 4.2, refletida nos papeis
    associados a cada endpoint quando os proximos modulos forem implementados.
    """

    async def checar(usuario: UsuarioAutenticado = Depends(get_current_user)) -> UsuarioAutenticado:
        if not any(p in usuario.papeis for p in papeis_permitidos):
            raise ApiError(403, "FORBIDDEN", "Voce nao tem permissao para esta acao.")
        return usuario

    return checar
