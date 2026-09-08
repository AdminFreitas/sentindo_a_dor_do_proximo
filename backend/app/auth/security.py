import hashlib
import secrets

from passlib.context import CryptContext

# Regra 3 de SDP_SEGURANCA.md: Argon2id, nunca texto puro ou MD5.
_pwd_context = CryptContext(schemes=["argon2"], deprecated="auto")


def hash_senha(senha_plana: str) -> str:
    return _pwd_context.hash(senha_plana)


def verificar_senha(senha_plana: str, senha_hash: str) -> bool:
    return _pwd_context.verify(senha_plana, senha_hash)


def gerar_token_sessao() -> str:
    """Token aleatorio de alta entropia, enviado ao cliente via cookie."""
    return secrets.token_urlsafe(32)


def hash_token_sessao(token: str) -> str:
    """
    SHA-256 e suficiente aqui (nao e senha de usuario memorizavel, ja e
    aleatorio de alta entropia) - so precisamos que o banco nunca guarde o
    token utilizavel em texto puro.
    """
    return hashlib.sha256(token.encode("utf-8")).hexdigest()
