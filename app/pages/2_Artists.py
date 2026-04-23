import streamlit as st
import pandas as pd
from utils.db import execute_query
from utils.ui import apply_apple_style

st.set_page_config(page_title="Artists", layout="wide")
apply_apple_style()

st.title("🎤 Artists")

st.subheader("Search Artists")

with st.container(border=True):
    col1, col2 = st.columns(2)
    with col1:
        genre = st.text_input("Genre", placeholder="e.g. Pop, Rock...")
    with col2:
        name = st.text_input("Artist Name", placeholder="e.g. Sơn Tùng M-TP...")

    query = f"""
    SELECT * FROM sp_search_artists(
        {f"'{genre}'" if genre else "NULL"}::VARCHAR,
        {f"'{name}'" if name else "NULL"}::VARCHAR
    )
    """

    cols, rows = execute_query(query)
    df = pd.DataFrame(rows, columns=cols)

    if not df.empty:
        st.dataframe(df, use_container_width=True)
    else:
        st.info("No artists found with the given criteria.")

st.divider()

st.subheader("Top Earning Artists")

with st.container(border=True):
    year = st.selectbox("Year", [2024, 2025, 2026], index=1)

    query = f"SELECT * FROM sp_top_earning_artists({year}::INTEGER)"

    cols, rows = execute_query(query)
    df_top = pd.DataFrame(rows, columns=cols)

    if not df_top.empty:
        st.dataframe(df_top, use_container_width=True)
    else:
        st.warning("No data found for the selected year.")

