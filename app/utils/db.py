"""
Database connection utilities for Neon PostgreSQL (Cloud only)
"""

import psycopg2
import os
import streamlit as st
from dotenv import load_dotenv

# Load environment variables
load_dotenv()


@st.cache_resource
def get_db_connection():
    """
    Create and cache Neon PostgreSQL connection
    """
    try:
        database_url = os.getenv("DATABASE_URL")

        if not database_url:
            raise Exception("DATABASE_URL environment variable not set")

        conn = psycopg2.connect(
            database_url,
            sslmode="require"
        )
        conn.autocommit = True

        return conn

    except Exception as e:
        st.error(f"Database connection error: {e}")
        return None


def test_connection():
    """
    Test database connection
    """
    try:
        conn = get_db_connection()

        if conn is None:
            return False

        conn.rollback()

        cur = conn.cursor()
        cur.execute("SELECT 1")
        cur.fetchone()
        cur.close()

        return True

    except Exception as e:
        print("Connection test failed:", e)
        return False


def execute_query(query, params=None):
    """
    Execute SELECT query and return results
    """
    try:
        conn = get_db_connection()

        if conn is None:
            st.error("Database connection not available")
            return [], []

        conn.rollback()

        cur = conn.cursor()

        cur.execute(query, params)

        columns = [desc[0] for desc in cur.description]
        rows = cur.fetchall()

        cur.close()

        return columns, rows

    except Exception as e:
        st.error(f"Query failed: {e}")
        return [], []


def execute_non_query(query, params=None):
    """
    Execute INSERT / UPDATE / DELETE queries
    """
    try:
        conn = get_db_connection()

        if conn is None:
            st.error("Database connection not available")
            return False

        cur = conn.cursor()

        cur.execute(query, params)
        conn.commit()

        cur.close()

        return True

    except Exception as e:
        st.error(f"Database operation failed: {e}")
        return False