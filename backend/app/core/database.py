from __future__ import annotations

from sqlalchemy import create_engine, event
from sqlalchemy.engine import Engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from app.core.config import settings

connect_args = (
    {"check_same_thread": False}
    if settings.database_url.startswith("sqlite")
    else {}
)
engine = create_engine(
    settings.database_url,
    connect_args=connect_args,
    echo=False,
    future=True,
)

if settings.database_url.startswith("sqlite"):

    @event.listens_for(engine, "connect")
    def _enable_sqlite_foreign_keys(dbapi_connection, connection_record) -> None:
        # SQLite ignores ForeignKey() declarations unless this is on per
        # connection. Without it the declared FKs are documentation only.
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()


SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    pass


def get_db():
    db = SessionLocal()
    try:
        yield db
    except Exception:
        # Without this, a handler that raises after mutating the session leaves
        # uncommitted-but-flushed changes behind and the connection returns to
        # the pool still holding them.
        db.rollback()
        raise
    finally:
        db.close()


def create_tables() -> None:
    from app import models  # noqa: F401

    Base.metadata.create_all(bind=engine)


def drop_tables() -> None:
    from app import models  # noqa: F401

    Base.metadata.drop_all(bind=engine)


__all__ = [
    "Base",
    "Engine",
    "SessionLocal",
    "create_tables",
    "drop_tables",
    "engine",
    "get_db",
]
