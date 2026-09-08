import pytest
from sqlalchemy import select

from app.auth.security import hash_senha
from app.config import settings
from app.usuarios.models import Papel, Usuario, UsuarioPapel

pytestmark = pytest.mark.asyncio


async def _criar_usuario_funcionario(db_session, email="funcionario@instituto.org", senha="senha-forte-123"):
    papel = Papel(nome="funcionario")
    db_session.add(papel)
    await db_session.flush()

    usuario = Usuario(nome="Fulano", email=email, senha_hash=hash_senha(senha), ativo=True)
    db_session.add(usuario)
    await db_session.flush()

    db_session.add(UsuarioPapel(usuario_id=usuario.id, papel_id=papel.id))
    await db_session.commit()
    return usuario


async def test_login_com_credenciais_corretas_retorna_200_e_cookie(client, db_session):
    await _criar_usuario_funcionario(db_session)

    resp = await client.post(
        "/api/auth/login", json={"email": "funcionario@instituto.org", "senha": "senha-forte-123"}
    )

    assert resp.status_code == 200
    body = resp.json()
    assert body["papeis"] == ["funcionario"]
    assert settings.session_cookie_name in resp.cookies


async def test_login_com_senha_errada_retorna_401(client, db_session):
    await _criar_usuario_funcionario(db_session)

    resp = await client.post(
        "/api/auth/login", json={"email": "funcionario@instituto.org", "senha": "senha-errada"}
    )

    assert resp.status_code == 401
    assert resp.json()["error"]["code"] == "INVALID_CREDENTIALS"


async def test_login_com_usuario_inexistente_retorna_401_mensagem_generica(client, db_session):
    resp = await client.post(
        "/api/auth/login", json={"email": "ninguem@instituto.org", "senha": "qualquer"}
    )

    assert resp.status_code == 401
    # Mesma mensagem de senha errada - nao revela se o e-mail existe.
    assert resp.json()["error"]["code"] == "INVALID_CREDENTIALS"


async def test_rate_limit_bloqueia_apos_varias_tentativas(client, db_session):
    await _criar_usuario_funcionario(db_session)

    for _ in range(settings.login_max_tentativas):
        resp = await client.post(
            "/api/auth/login", json={"email": "funcionario@instituto.org", "senha": "errada"}
        )
        assert resp.status_code == 401

    resp_bloqueado = await client.post(
        "/api/auth/login", json={"email": "funcionario@instituto.org", "senha": "errada"}
    )
    assert resp_bloqueado.status_code == 429
    assert resp_bloqueado.json()["error"]["code"] == "RATE_LIMIT_EXCEEDED"


async def test_me_sem_sessao_retorna_401(client):
    resp = await client.get("/api/auth/me")
    assert resp.status_code == 401


async def test_me_com_sessao_valida_retorna_usuario(client, db_session):
    await _criar_usuario_funcionario(db_session)
    login_resp = await client.post(
        "/api/auth/login", json={"email": "funcionario@instituto.org", "senha": "senha-forte-123"}
    )
    assert login_resp.status_code == 200

    resp = await client.get("/api/auth/me")
    assert resp.status_code == 200
    assert resp.json()["email"] == "funcionario@instituto.org"


async def test_logout_revoga_sessao_e_me_passa_a_negar(client, db_session):
    await _criar_usuario_funcionario(db_session)
    await client.post(
        "/api/auth/login", json={"email": "funcionario@instituto.org", "senha": "senha-forte-123"}
    )

    logout_resp = await client.post("/api/auth/logout")
    assert logout_resp.status_code == 200

    resp = await client.get("/api/auth/me")
    assert resp.status_code == 401


async def test_health_check_nao_exige_autenticacao(client):
    resp = await client.get("/health")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok"}
