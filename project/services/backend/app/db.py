from sqlalchemy import create_engine
from sqlalchemy.engine import Connection
from contextlib import contextmanager
from .config import settings

engine = create_engine(
    settings.DATABASE_URL,
    pool_pre_ping=settings.POOL_PRE_PING,
    pool_size=settings.POOL_SIZE,
    max_overflow=settings.MAX_OVERFLOW,
    pool_recycle=settings.POOL_RECYCLE,
    pool_timeout=settings.POOL_TIMEOUT,
    echo=settings.ECHO_SQL,
    future=True,
)

@contextmanager
def get_connection() -> Connection:
    conn = engine.connect()
    try:
        yield conn
    finally:
        conn.close()

# FastAPI dependency
def conn_dependency():
    with get_connection() as conn:
        yield conn
