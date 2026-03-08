import streamlit as st
import pandas as pd
from utils.db import execute_query

st.title("🎤 Artists")

st.subheader("Search Artists")

genre = st.text_input("Genre")
name = st.text_input("Artist Name")

query = f"""
SELECT * FROM sp_search_artists(
    {f"'{genre}'" if genre else "NULL"},
    {f"'{name}'" if name else "NULL"}
)
"""

cols, rows = execute_query(query)
df = pd.DataFrame(rows, columns=cols)

st.dataframe(df)

st.divider()

st.subheader("Top Earning Artists")

year = st.selectbox("Year", [2022, 2023, 2024], index=2)

query = f"SELECT * FROM sp_top_earning_artists({year})"

cols, rows = execute_query(query)
df = pd.DataFrame(rows, columns=cols)

st.dataframe(df)