"""
Artists page - View and manage artist information
"""

import streamlit as st
import pandas as pd
from utils.db import execute_query

st.set_page_config(page_title="Artists", page_icon="🎤", layout="wide")

st.title("🎤 Artists")
st.markdown("---")

# Artist list
st.subheader("Artist Directory")

query = """
SELECT 
    a.artist_id,
    a.stage_name,
    a.full_name,
    a.debut_date,
    l.label_name
FROM artists a
LEFT JOIN labels l ON a.label_id = l.label_id
ORDER BY a.stage_name
"""

results = execute_query(query)

if results:
    df = pd.DataFrame(results)
    st.dataframe(df, use_container_width=True, hide_index=True)
else:
    st.info("No artists found. Please add data using seed scripts.")

st.markdown("---")

# Artist details section
st.subheader("Artist Details")
st.info("Select an artist to view detailed information including albums, tracks, and revenue")
