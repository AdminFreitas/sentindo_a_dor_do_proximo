from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class Sessao(Base):
    """
    Sessao controlada pelo servidor (T02 em SDP_DECISOES_PENDENTES.md).
    Guardamos apenas o HASH do token de sessao - nunca o token em texto puro -
    pelo mesmo motivo de nunca guardar senha em texto puro: se o banco vazar,
    o vazamento nao deve entregar sessoes utilizaveis.
    """

    __tablename__ = "sessoes"

    id: Mapped[int] = mapped_column(primary_key=True)
    usuario_id: Mapped[int] = mapped_column(ForeignKey("usuarios.id"), nullable=False, index=True)
    token_hash: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    criado_em: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
    expira_em: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    revogado_em: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    ip: Mapped[str | None] = mapped_column(String(45), nullable=True)


class Auditoria(Base):
    """
    Somente-insercao a nivel de aplicacao. Em producao, o usuario de banco usado
    pela aplicacao (app_runtime) deve ter UPDATE/DELETE revogado nesta tabela
    (T04 em SDP_DECISOES_PENDENTES.md) - a garantia real esta no banco, nao aqui.
    """

    __tablename__ = "auditoria"

    id: Mapped[int] = mapped_column(primary_key=True)
    usuario_id: Mapped[int | None] = mapped_column(ForeignKey("usuarios.id"), nullable=True)
    tabela: Mapped[str] = mapped_column(String(50), nullable=False)
    registro_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    acao: Mapped[str] = mapped_column(String(30), nullable=False)
    ip: Mapped[str | None] = mapped_column(String(45), nullable=True)
    criado_em: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
