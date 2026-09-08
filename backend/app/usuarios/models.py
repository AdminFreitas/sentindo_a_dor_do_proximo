from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Usuario(Base):
    __tablename__ = "usuarios"

    id: Mapped[int] = mapped_column(primary_key=True)
    nome: Mapped[str] = mapped_column(String(150), nullable=False)
    email: Mapped[str] = mapped_column(String(150), unique=True, nullable=False, index=True)
    senha_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    ativo: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    criado_em: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    papeis: Mapped[list["UsuarioPapel"]] = relationship(back_populates="usuario")


class Papel(Base):
    __tablename__ = "papeis"

    # 'administrador','gestor','funcionario','avaliador','auditor'
    # Nota: 'avaliador' so existe de fato se D05 (SDP_DECISOES_PENDENTES.md) confirmar
    # que a avaliacao de elegibilidade e uma funcao separada do funcionario.
    id: Mapped[int] = mapped_column(primary_key=True)
    nome: Mapped[str] = mapped_column(String(30), unique=True, nullable=False)


class UsuarioPapel(Base):
    __tablename__ = "usuarios_papeis"

    usuario_id: Mapped[int] = mapped_column(ForeignKey("usuarios.id"), primary_key=True)
    papel_id: Mapped[int] = mapped_column(ForeignKey("papeis.id"), primary_key=True)

    usuario: Mapped["Usuario"] = relationship(back_populates="papeis")
    papel: Mapped["Papel"] = relationship()
