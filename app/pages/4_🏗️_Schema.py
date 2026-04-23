"""
Page 5: Schema Overview
ERD image, stats, FK relationships.
"""

import streamlit as st
import os
from utils.db import run_query

# Load CSS
css_file = os.path.join(os.path.dirname(os.path.dirname(__file__)), "assets", "style.css")
if os.path.exists(css_file):
    with open(css_file) as f:
        st.markdown(f"<style>{f.read()}</style>", unsafe_allow_html=True)

st.title("🏗️ Schema Overview")
st.caption("Cấu trúc database — 25 bảng, 4 ISA, partitioned revenue")
st.divider()

# --- ERD Image ---
erd_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "assets", "erd.png")
if os.path.exists(erd_path):
    st.image(erd_path, caption="Entity-Relationship Diagram", use_container_width=True)
else:
    st.info("ERD image chưa có. Đặt file `erd.png` vào `app/assets/`.")

st.divider()

# --- Stats ---
st.subheader("📊 Database Statistics")

stats_queries = {
    "📋 Tables": """
        SELECT COUNT(*) FROM information_schema.tables
        WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
    """,
    "🔗 ISA Hierarchies": "SELECT 4",
    "📇 Indexes": """
        SELECT COUNT(*) FROM pg_indexes WHERE schemaname = 'public'
    """,
    "⚙️ Functions": """
        SELECT COUNT(*) FROM information_schema.routines
        WHERE routine_schema = 'public' AND routine_type = 'FUNCTION'
    """,
    "🔧 Procedures": """
        SELECT COUNT(*) FROM information_schema.routines
        WHERE routine_schema = 'public' AND routine_type = 'PROCEDURE'
    """,
    "👁️ Views": """
        SELECT COUNT(*) FROM information_schema.views
        WHERE table_schema = 'public'
    """,
}

cols = st.columns(len(stats_queries))
for col, (label, q) in zip(cols, stats_queries.items()):
    df, _, _ = run_query(q)
    val = df.iloc[0, 0] if df is not None and not df.empty else 0
    col.metric(label, val)

st.divider()

# --- ISA Relationships ---
st.subheader("🧬 ISA Relationships")
isa_data = [
    ["Artists", "artists", "solo_artists, bands, composers", "Overlapping, Partial"],
    ["Contracts", "contracts", "recording_, distribution_, publishing_contracts", "Disjoint, Total"],
    ["Revenue", "revenue_logs", "streaming_, sync_, live_revenue_details", "Disjoint, Total"],
    ["Beneficiaries", "beneficiaries", "artist_beneficiaries, label_beneficiaries", "Disjoint, Total"],
]
import pandas as pd
isa_df = pd.DataFrame(isa_data, columns=["ISA", "Parent", "Children", "Constraint"])
st.dataframe(isa_df, use_container_width=True, hide_index=True)

st.divider()

# --- FK Relationships ---
st.subheader("🔗 Foreign Key Relationships")
fk_df, ms, err = run_query("""
    SELECT
        tc.table_name AS source_table,
        kcu.column_name AS source_column,
        ccu.table_name AS target_table,
        ccu.column_name AS target_column,
        rc.delete_rule AS on_delete,
        rc.update_rule AS on_update
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
        ON tc.constraint_name = kcu.constraint_name
    JOIN information_schema.constraint_column_usage ccu
        ON tc.constraint_name = ccu.constraint_name
    JOIN information_schema.referential_constraints rc
        ON tc.constraint_name = rc.constraint_name
    WHERE tc.constraint_type = 'FOREIGN KEY'
      AND tc.table_schema = 'public'
    ORDER BY tc.table_name, kcu.column_name
""")

if fk_df is not None and not fk_df.empty:
    st.dataframe(fk_df, use_container_width=True, hide_index=True)
    st.caption(f"⏱️ {ms}ms | {len(fk_df)} FK relationships")
else:
    st.info("Không tìm thấy FK relationships.")

st.divider()

# --- Partition info ---
st.subheader("📦 Partitioned Tables")
part_df, ms, _ = run_query("""
    SELECT
        parent.relname AS parent_table,
        child.relname AS partition_name,
        pg_get_expr(child.relpartbound, child.oid) AS partition_bound
    FROM pg_inherits
    JOIN pg_class parent ON pg_inherits.inhparent = parent.oid
    JOIN pg_class child ON pg_inherits.inhrelid = child.oid
    JOIN pg_namespace ns ON parent.relnamespace = ns.oid
    WHERE ns.nspname = 'public'
    ORDER BY parent.relname, child.relname
""")

if part_df is not None and not part_df.empty:
    st.dataframe(part_df, use_container_width=True, hide_index=True)
    st.caption(f"⏱️ {ms}ms")
else:
    st.info("Không có partition nào.")
