"""
Database utilities for Neon PostgreSQL
- Cached connection with warm-up
- run_sp() with timing + error handling
"""

import psycopg2
import psycopg2.extras
import pandas as pd
import os
import time
import streamlit as st
from dotenv import load_dotenv

load_dotenv()


@st.cache_resource
def get_db_connection():
    """Cached Neon PostgreSQL connection."""
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        st.error("DATABASE_URL not set. Add it to .env")
        return None
    try:
        conn = psycopg2.connect(database_url, sslmode="require")
        conn.autocommit = True
        return conn
    except Exception as e:
        st.error(f"Connection error: {e}")
        return None


def _get_conn():
    """Get connection, reset if stale."""
    conn = get_db_connection()
    if conn is None:
        return None
    try:
        conn.rollback()
        cur = conn.cursor()
        cur.execute("SELECT 1")
        cur.fetchone()
        cur.close()
        return conn
    except Exception:
        # Connection died (Neon suspend) — clear cache & reconnect
        get_db_connection.clear()
        return get_db_connection()


def test_connection():
    """Test database connectivity."""
    try:
        return _get_conn() is not None
    except Exception:
        return False


def run_query(query, params=None):
    """
    Execute SELECT query. Returns (df, elapsed_ms, error).
    """
    conn = _get_conn()
    if conn is None:
        return None, 0, "No database connection"
    start = time.time()
    try:
        conn.rollback()
        df = pd.read_sql(query, conn, params=params)
        elapsed = round((time.time() - start) * 1000)
        return df, elapsed, None
    except Exception as e:
        elapsed = round((time.time() - start) * 1000)
        return None, elapsed, str(e).split("\n")[0]


def run_procedure(query, params=None):
    """
    Execute CALL procedure. Returns (message, elapsed_ms, error).
    """
    conn = _get_conn()
    if conn is None:
        return None, 0, "No database connection"
    start = time.time()
    try:
        conn.rollback()
        cur = conn.cursor()
        cur.execute(query, params)
        # Try to fetch OUT params
        try:
            result = cur.fetchone()
            cur.close()
            elapsed = round((time.time() - start) * 1000)
            return result, elapsed, None
        except psycopg2.ProgrammingError:
            cur.close()
            elapsed = round((time.time() - start) * 1000)
            return None, elapsed, None
    except Exception as e:
        elapsed = round((time.time() - start) * 1000)
        return None, elapsed, str(e).split("\n")[0]


def show_result(df, elapsed_ms, error):
    """Display query result with timing."""
    if error:
        st.error(f"Loi: {error}")
        st.info("Tip: Neon compute dang warm up. Thu lai sau 3 giay.")
    elif df is not None and not df.empty:
        st.dataframe(df, use_container_width=True)
        st.caption(f"⏱️ {elapsed_ms}ms | {len(df)} rows")
    elif df is not None:
        st.info("Khong co du lieu.")
        st.caption(f"⏱️ {elapsed_ms}ms | 0 rows")
