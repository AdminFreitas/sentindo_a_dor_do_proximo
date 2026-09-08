from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

from app.config import settings

# echo=False em producao - nunca logar SQL com dado sensivel em texto puro (regra 18/12)
engine = create_async_engine(settings.database_url, echo=False, pool_pre_ping=True)

AsyncSessionLocal = async_sessionmaker(engine, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


async def get_db():
    """Dependency do FastAPI: uma sessao de banco por requisicao."""
    async with AsyncSessionLocal() as session:
        yield session
