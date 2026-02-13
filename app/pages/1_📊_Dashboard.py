"""
Dashboard page - Overview statistics and charts
"""

import streamlit as st
import plotly.express as px
import plotly.graph_objects as go
import pandas as pd
from utils.db import execute_query, call_stored_procedure

st.set_page_config(page_title="Dashboard", page_icon="📊", layout="wide")

st.title("📊 Dashboard")
st.markdown("---")

# KPI Cards
col1, col2, col3, col4 = st.columns(4)

with col1:
    # Total artists
    result = execute_query("SELECT COUNT(*) as count FROM artists")
    if result:
        st.metric("Artists", result[0]['count'])
    else:
        st.metric("Artists", "N/A")

with col2:
    # Total tracks
    result = execute_query("SELECT COUNT(*) as count FROM tracks")
    if result:
        st.metric("Tracks", result[0]['count'])
    else:
        st.metric("Tracks", "N/A")

with col3:
    # Total revenue
    result = execute_query("SELECT SUM(amount) as total FROM revenue_logs")
    if result and result[0]['total']:
        st.metric("Total Revenue", f"${result[0]['total']:,.0f}")
    else:
        st.metric("Total Revenue", "$0")

with col4:
    # Total bookings
    result = execute_query("SELECT COUNT(*) as count FROM bookings")
    if result:
        st.metric("Bookings", result[0]['count'])
    else:
        st.metric("Bookings", "N/A")

st.markdown("---")

# Charts section
col1, col2 = st.columns(2)

with col1:
    st.subheader("Revenue by Source")
    # TODO: Add revenue by source chart
    st.info("Chart will be displayed here after implementing stored procedures")

with col2:
    st.subheader("Top Artists by Revenue")
    # TODO: Add top artists chart
    st.info("Chart will be displayed here after implementing stored procedures")

st.markdown("---")
st.caption("Use stored procedures to load data for visualizations")
