"""
Bootstrap de desenvolvimento: cria as tabelas via metadata do SQLAlchemy e
insere os papeis base.

ATENCAO: isto e um atalho de desenvolvimento (Base.metadata.create_all), nao
uma estrategia de migration real. Antes de existir dado de producao, trocar
por Alembic (versionamento de schema) - ver T09 em SDP_DECISOES_PENDENTES.md,
que ainda esta pendente de aprovacao formal.

Uso:
    python -m scripts.bootstrap_dev
"""

import asyncio

from sqlalchemy import select

from app.auth.models import Auditoria, Sessao  # noqa: F401 - garante que os modelos sejam registrados
from app.database import AsyncSessionLocal, Base, engine
from app.usuarios.models import Papel, Usuario, UsuarioPapel  # noqa: F401

PAPEIS_BASE = ["administrador", "gestor", "funcionario", "avaliador", "auditor"]


async def criar_tabelas():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


async def semear_papeis():
    async with AsyncSessionLocal() as db:
        for nome in PAPEIS_BASE:
            existe = await db.execute(select(Papel).where(Papel.nome == nome))
            if existe.scalar_one_or_none() is None:
                db.add(Papel(nome=nome))
        await db.commit()


async def main():
    await criar_tabelas()
    await semear_papeis()
    print("Tabelas criadas e papeis base inseridos.")


if __name__ == "__main__":
    asyncio.run(main())
