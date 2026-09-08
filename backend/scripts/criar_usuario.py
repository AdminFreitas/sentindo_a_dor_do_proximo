"""
Cria um usuario e associa um papel. Uso principalmente para o primeiro
administrador, ja que nao existe endpoint publico de auto-cadastro.

Uso:
    python -m scripts.criar_usuario "Nome Completo" email@instituto.org senha123 administrador
"""

import asyncio
import sys

from sqlalchemy import select

from app.auth.security import hash_senha
from app.database import AsyncSessionLocal
from app.usuarios.models import Papel, Usuario, UsuarioPapel


async def criar(nome: str, email: str, senha: str, papel_nome: str):
    async with AsyncSessionLocal() as db:
        papel = (await db.execute(select(Papel).where(Papel.nome == papel_nome))).scalar_one_or_none()
        if papel is None:
            print(f"Papel '{papel_nome}' nao existe. Rode o bootstrap_dev primeiro.")
            return

        ja_existe = (await db.execute(select(Usuario).where(Usuario.email == email))).scalar_one_or_none()
        if ja_existe is not None:
            print(f"Usuario com e-mail {email} ja existe.")
            return

        usuario = Usuario(nome=nome, email=email, senha_hash=hash_senha(senha), ativo=True)
        db.add(usuario)
        await db.flush()
        db.add(UsuarioPapel(usuario_id=usuario.id, papel_id=papel.id))
        await db.commit()
        print(f"Usuario {email} criado com papel '{papel_nome}'.")


if __name__ == "__main__":
    if len(sys.argv) != 5:
        print("Uso: python -m scripts.criar_usuario <nome> <email> <senha> <papel>")
        sys.exit(1)
    asyncio.run(criar(*sys.argv[1:]))
