import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker

from app import database
from app.auth import rate_limit
from app.config import settings
from app.database import Base
from app.main import app

# Os testes rodam sobre HTTP puro (ASGITransport nao usa HTTPS real). Um cookie
# marcado Secure e corretamente recusado pelo cookie jar do cliente sobre HTTP -
# mesmo comportamento de um navegador real. Em dev/teste local isso e esperado
# (ver SESSION_COOKIE_SECURE=false em .env.example); em producao, com HTTPS real,
# o valor correto e True e nao deve ser alterado.
settings.session_cookie_secure = False


@pytest.fixture(autouse=True)
def limpar_rate_limit_entre_testes():
    """
    O rate limiter (app/auth/rate_limit.py) guarda estado em um dict de modulo -
    por design, para persistir entre requisicoes na mesma instancia do processo
    (ver nota sobre Redis em producao no proprio arquivo). Em teste, isso vaza
    estado de um teste para o outro se nao for limpo explicitamente.
    """
    rate_limit._tentativas.clear()
    yield
    rate_limit._tentativas.clear()

# SQLite em memoria so para teste rapido de fluxo - o comportamento de
# constraints especificas do Postgres (ex.: EXCLUDE de agenda, futuramente)
# precisa de teste de integracao contra Postgres real, nao entra aqui.
TEST_DATABASE_URL = "sqlite+aiosqlite:///:memory:"


@pytest_asyncio.fixture
async def db_engine():
    engine = create_async_engine(TEST_DATABASE_URL)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    await engine.dispose()


@pytest_asyncio.fixture
async def client(db_engine, monkeypatch):
    test_session_local = async_sessionmaker(db_engine, expire_on_commit=False)

    async def override_get_db():
        async with test_session_local() as session:
            yield session

    app.dependency_overrides[database.get_db] = override_get_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac

    app.dependency_overrides.clear()


@pytest_asyncio.fixture
async def db_session(db_engine):
    test_session_local = async_sessionmaker(db_engine, expire_on_commit=False)
    async with test_session_local() as session:
        yield session
