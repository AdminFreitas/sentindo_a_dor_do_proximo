from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import rate_limit, repository
from app.auth.schemas import LoginResponse
from app.auth.security import gerar_token_sessao, hash_token_sessao, verificar_senha
from app.config import settings
from app.errors import ApiError


class LoginResult:
    def __init__(self, response: LoginResponse, token_sessao: str):
        self.response = response
        self.token_sessao = token_sessao


async def autenticar(db: AsyncSession, email: str, senha: str, ip: str | None) -> LoginResult:
    ip_normalizado = ip or "desconhecido"

    # Regra 14 de SDP_SEGURANCA.md - checar rate limit antes de qualquer acesso ao banco.
    if rate_limit.limite_excedido(email, ip_normalizado):
        raise ApiError(
            status_code=429,
            code="RATE_LIMIT_EXCEEDED",
            message="Muitas tentativas de login. Tente novamente mais tarde.",
        )

    usuario = await repository.buscar_usuario_por_email(db, email)

    # Mensagem identica para "nao existe" e "senha errada" - nao revelar qual delas
    # e verdade evita enumeracao de e-mails cadastrados.
    credenciais_invalidas = ApiError(
        status_code=401, code="INVALID_CREDENTIALS", message="E-mail ou senha invalidos."
    )

    if usuario is None or not usuario.ativo:
        rate_limit.registrar_tentativa_falha(email, ip_normalizado)
        await repository.registrar_auditoria(db, acao="LOGIN_FALHOU", usuario_id=None, ip=ip)
        await db.commit()
        raise credenciais_invalidas

    if not verificar_senha(senha, usuario.senha_hash):
        rate_limit.registrar_tentativa_falha(email, ip_normalizado)
        await repository.registrar_auditoria(db, acao="LOGIN_FALHOU", usuario_id=usuario.id, ip=ip)
        await db.commit()
        raise credenciais_invalidas

    rate_limit.limpar_tentativas(email, ip_normalizado)

    token = gerar_token_sessao()
    await repository.criar_sessao(
        db,
        usuario_id=usuario.id,
        token_hash=hash_token_sessao(token),
        ttl_minutos=settings.session_ttl_minutos,
        ip=ip,
    )
    papeis = await repository.listar_papeis_do_usuario(db, usuario.id)
    await repository.registrar_auditoria(db, acao="LOGIN", usuario_id=usuario.id, ip=ip)
    await db.commit()

    return LoginResult(
        response=LoginResponse(usuario_id=usuario.id, papeis=papeis),
        token_sessao=token,
    )


async def encerrar_sessao(db: AsyncSession, token: str, usuario_id: int | None, ip: str | None) -> None:
    await repository.revogar_sessao(db, hash_token_sessao(token))
    await repository.registrar_auditoria(db, acao="LOGOUT", usuario_id=usuario_id, ip=ip)
    await db.commit()
