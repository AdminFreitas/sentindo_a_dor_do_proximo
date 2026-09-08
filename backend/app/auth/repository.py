from datetime import datetime, timedelta, timezone

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.models import Auditoria, Sessao
from app.usuarios.models import Papel, Usuario, UsuarioPapel


async def buscar_usuario_por_email(db: AsyncSession, email: str) -> Usuario | None:
    stmt = select(Usuario).where(Usuario.email == email)
    result = await db.execute(stmt)
    return result.scalar_one_or_none()


async def listar_papeis_do_usuario(db: AsyncSession, usuario_id: int) -> list[str]:
    stmt = (
        select(Papel.nome)
        .join(UsuarioPapel, UsuarioPapel.papel_id == Papel.id)
        .where(UsuarioPapel.usuario_id == usuario_id)
    )
    result = await db.execute(stmt)
    return [row[0] for row in result.all()]


async def criar_sessao(
    db: AsyncSession, usuario_id: int, token_hash: str, ttl_minutos: int, ip: str | None
) -> Sessao:
    sessao = Sessao(
        usuario_id=usuario_id,
        token_hash=token_hash,
        expira_em=datetime.now(timezone.utc) + timedelta(minutes=ttl_minutos),
        ip=ip,
    )
    db.add(sessao)
    await db.flush()
    return sessao


async def buscar_sessao_valida(db: AsyncSession, token_hash: str) -> Sessao | None:
    stmt = select(Sessao).where(
        Sessao.token_hash == token_hash,
        Sessao.revogado_em.is_(None),
        Sessao.expira_em > datetime.now(timezone.utc),
    )
    result = await db.execute(stmt)
    return result.scalar_one_or_none()


async def revogar_sessao(db: AsyncSession, token_hash: str) -> None:
    stmt = (
        update(Sessao)
        .where(Sessao.token_hash == token_hash, Sessao.revogado_em.is_(None))
        .values(revogado_em=datetime.now(timezone.utc))
    )
    await db.execute(stmt)


async def revogar_todas_sessoes_do_usuario(db: AsyncSession, usuario_id: int) -> None:
    """Usado ao desativar um usuario - ver regra em SDP_DECISOES_PENDENTES.md (T02)."""
    stmt = (
        update(Sessao)
        .where(Sessao.usuario_id == usuario_id, Sessao.revogado_em.is_(None))
        .values(revogado_em=datetime.now(timezone.utc))
    )
    await db.execute(stmt)


async def registrar_auditoria(
    db: AsyncSession,
    acao: str,
    usuario_id: int | None,
    ip: str | None,
    tabela: str = "usuarios",
    registro_id: int | None = None,
) -> None:
    """
    Insercao pura - esta funcao nunca faz UPDATE/DELETE. A garantia de que
    ninguem mais consegue alterar isso depois vem do privilegio do usuario
    de banco (app_runtime), nao deste codigo.
    """
    db.add(
        Auditoria(
            usuario_id=usuario_id,
            tabela=tabela,
            registro_id=registro_id if registro_id is not None else usuario_id,
            acao=acao,
            ip=ip,
        )
    )
    await db.flush()
