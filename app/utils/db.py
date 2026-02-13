"""
Database connection utilities
"""

import os
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv
import streamlit as st

# Load environment variables
load_dotenv()

def get_db_config():
    """Get database configuration from environment variables"""
    return {
        'host': os.getenv('POSTGRES_HOST', 'postgres'),
        'port': os.getenv('POSTGRES_PORT', '5432'),
        'database': os.getenv('POSTGRES_DB', 'artist_revenue_db'),
        'user': os.getenv('POSTGRES_USER', 'postgres'),
        'password': os.getenv('POSTGRES_PASSWORD', 'postgres')
    }

@st.cache_resource
def get_db_connection():
    """
    Create and cache database connection
    Returns a connection pool for reuse
    """
    try:
        config = get_db_config()
        conn = psycopg2.connect(**config)
        return conn
    except Exception as e:
        st.error(f"Database connection error: {e}")
        return None

def test_connection():
    """Test if database connection is working"""
    try:
        conn = get_db_connection()
        if conn is None:
            return False
        
        cursor = conn.cursor()
        cursor.execute("SELECT 1")
        cursor.close()
        return True
    except Exception as e:
        print(f"Connection test failed: {e}")
        return False

def execute_query(query, params=None, fetch=True):
    """
    Execute a SQL query and return results
    
    Args:
        query: SQL query string
        params: Query parameters (optional)
        fetch: Whether to fetch results (default: True)
    
    Returns:
        Query results as list of dictionaries, or None
    """
    try:
        conn = get_db_connection()
        if conn is None:
            return None
        
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        if params:
            cursor.execute(query, params)
        else:
            cursor.execute(query)
        
        if fetch:
            results = cursor.fetchall()
            cursor.close()
            return results
        else:
            conn.commit()
            cursor.close()
            return True
            
    except Exception as e:
        st.error(f"Query execution error: {e}")
        return None

def call_stored_procedure(procedure_name, params=None):
    """
    Call a stored procedure
    
    Args:
        procedure_name: Name of the stored procedure
        params: Procedure parameters (optional)
    
    Returns:
        Procedure results as list of dictionaries
    """
    try:
        conn = get_db_connection()
        if conn is None:
            return None
        
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        if params:
            cursor.execute(f"SELECT * FROM {procedure_name}(%s)", params)
        else:
            cursor.execute(f"SELECT * FROM {procedure_name}()")
        
        results = cursor.fetchall()
        cursor.close()
        return results
        
    except Exception as e:
        st.error(f"Stored procedure error: {e}")
        return None
