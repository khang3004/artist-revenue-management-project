"""
Load: Shared database engine, retry logic, and upsert helpers.
All load scripts import from here.
"""

import os
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine
import sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from config import DATABASE_URL


_engine: Engine | None = None


def get_engine() -> Engine:
    """Singleton SQLAlchemy engine (connection-pooled)."""
    global _engine
    if _engine is None:
        if not DATABASE_URL:
            raise RuntimeError("DATABASE_URL is not set in .env")
        connect_args = {}
        if "sslmode" not in DATABASE_URL:
            connect_args["sslmode"] = "require"
        _engine = create_engine(
            DATABASE_URL,
            pool_pre_ping=True,
            pool_size=5,
            max_overflow=10,
        )
    return _engine


def execute_sql(sql: str, params: dict | None = None):
    """Execute a single SQL statement."""
    engine = get_engine()
    with engine.begin() as conn:
        conn.execute(text(sql), params or {})


def execute_values_upsert(
    table: str,
    columns: list[str],
    rows: list[dict],
    conflict_columns: list[str],
    update_columns: list[str] | None = None,
):
    """
    Perform INSERT … ON CONFLICT DO UPDATE (upsert) for a batch of rows.

    Parameters
    ----------
    table : str
        Target table name (schema-qualified if needed).
    columns : list[str]
        Column names to insert.
    rows : list[dict]
        Each dict maps column-name → value.
    conflict_columns : list[str]
        Columns forming the UNIQUE / PK constraint.
    update_columns : list[str] | None
        Columns to update on conflict.  None ⇒ DO NOTHING.
    """
    if not rows:
        return

    placeholders = ", ".join(f":{c}" for c in columns)
    col_list = ", ".join(columns)
    conflict_list = ", ".join(conflict_columns)

    if update_columns:
        set_clause = ", ".join(
            f"{c} = EXCLUDED.{c}" for c in update_columns
        )
        sql = (
            f"INSERT INTO {table} ({col_list}) VALUES ({placeholders}) "
            f"ON CONFLICT ({conflict_list}) DO UPDATE SET {set_clause}"
        )
    else:
        sql = (
            f"INSERT INTO {table} ({col_list}) VALUES ({placeholders}) "
            f"ON CONFLICT ({conflict_list}) DO NOTHING"
        )

    engine = get_engine()
    with engine.begin() as conn:
        for row in rows:
            # Replace NaN / None consistently
            clean = {}
            for c in columns:
                val = row.get(c)
                if val is None or (isinstance(val, float) and val != val):
                    clean[c] = None
                else:
                    clean[c] = val
            conn.execute(text(sql), clean)
