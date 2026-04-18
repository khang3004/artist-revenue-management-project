"""
Page 6: About / Tech Stack
"""

import streamlit as st
import os
from utils.db import run_query

# Load CSS
css_file = os.path.join(os.path.dirname(os.path.dirname(__file__)), "assets", "style.css")
if os.path.exists(css_file):
    with open(css_file) as f:
        st.markdown(f"<style>{f.read()}</style>", unsafe_allow_html=True)

st.title("⚙️ About — Tech Stack")
st.caption("Thông tin kỹ thuật & nhóm thực hiện")
st.divider()

# --- Tech Stack ---
st.subheader("🛠️ Công nghệ sử dụng")

c1, c2 = st.columns(2)
with c1:
    st.markdown("""
    | Component | Technology |
    |-----------|-----------|
    | **Database** | Neon Serverless PostgreSQL 16 |
    | **Frontend** | Streamlit + Plotly |
    | **Language** | Python 3.11+ |
    | **Connector** | psycopg2 + pandas |
    | **Slides** | LaTeX Beamer (xelatex) |
    | **VCS** | Git + GitHub |
    """)

with c2:
    st.markdown("""
    | Feature | Count |
    |---------|-------|
    | **Tables** | 25 |
    | **ISA Hierarchies** | 4 |
    | **Weak Entities** | 12 |
    | **Stored Procedures** | 14 |
    | **Analytics SPs** | 8 (ROLLUP, PIVOT, CTE, Window, JSONB) |
    | **OLTP SPs** | 6 (Multi-INSERT, Locking, FSM) |
    """)

st.divider()

# --- Database Info ---
st.subheader("🗄️ Database Info")
db_info, _, _ = run_query("SELECT version()")
if db_info is not None:
    st.code(db_info.iloc[0, 0], language="text")

c1, c2 = st.columns(2)
with c1:
    size_df, _, _ = run_query("""
        SELECT pg_size_pretty(pg_database_size(current_database())) AS db_size
    """)
    if size_df is not None:
        st.metric("Database Size", size_df.iloc[0, 0])

with c2:
    conn_df, _, _ = run_query("SELECT current_database(), current_user")
    if conn_df is not None:
        st.metric("Database", conn_df.iloc[0, 0])
        st.metric("User", conn_df.iloc[0, 1])

st.divider()

# --- SP Summary ---
st.subheader("📋 Stored Procedures Summary")
sp_data = [
    ["SP1", "sp_revenue_by_artist_rollup", "ROLLUP + GROUPING()", "✅ Đề bài"],
    ["SP2", "sp_revenue_pivot_by_source_v2", "PIVOT (FILTER)", "✅ Đề bài"],
    ["SP3", "sp_top_earning_artists", "Nested subquery 2 tầng", "✅ Đề bài"],
    ["SP4", "sp_contract_revenue_distribution", "LATERAL JOIN + ISA", "Nâng cao"],
    ["SP5", "sp_top_tracks_per_artist", "CTE + RANK() Window", "Nâng cao"],
    ["SP6", "sp_wallet_audit_report", "Multi-CTE", "Nâng cao"],
    ["SP7", "sp_venue_event_analytics", "CTE + ROLLUP + DENSE_RANK()", "✅ Đề bài"],
    ["SP8", "sp_search_artists", "GIN + JSONB @>", "Nâng cao"],
    ["SP9", "sp_register_artist", "Multi-table INSERT", "OLTP"],
    ["SP10", "sp_record_revenue", "ISA discriminator INSERT", "OLTP"],
    ["SP11", "sp_request_withdrawal", "SELECT FOR UPDATE", "OLTP"],
    ["SP12", "sp_process_withdrawal", "Finite State Machine", "OLTP"],
    ["SP13", "sp_create_contract_with_splits", "JSONB array + BR-01", "OLTP"],
    ["SP14", "sp_archive_artist", "Soft-delete + BR-04", "OLTP"],
]
import pandas as pd
sp_df = pd.DataFrame(sp_data, columns=["#", "Procedure", "Kỹ thuật", "Loại"])
st.dataframe(sp_df, use_container_width=True, hide_index=True)

st.divider()

# --- Team ---
st.subheader("👥 Nhóm thực hiện")
st.markdown("""
| STT | Họ tên | Vai trò |
|-----|--------|---------|
| 1 | KhangDSnAI | Database Design & Backend |
| 2 | Khanh Vu | Data Storyteller & Demo |
| 3 | Hung Mai | Schema & Procedures |
| 4 | Thanh Nguyen | Frontend & Slides |
""")

st.divider()
st.markdown("""
**MDL018 — Tổ chức và Quản lý Dữ liệu**
Đại học Khoa học Tự nhiên — ĐHQG-HCM
""")
st.caption("Neon Serverless PostgreSQL 16 | Streamlit + Plotly | 14 Stored Procedures")
