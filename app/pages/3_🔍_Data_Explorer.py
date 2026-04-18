"""
Page 4: Data Explorer
Browse tables, view schema info, run custom SQL.
"""

import streamlit as st
import os
from utils.db import run_query, show_result

# Load CSS
css_file = os.path.join(os.path.dirname(os.path.dirname(__file__)), "assets", "style.css")
if os.path.exists(css_file):
    with open(css_file) as f:
        st.markdown(f"<style>{f.read()}</style>", unsafe_allow_html=True)

st.title("🔍 Khám phá dữ liệu")
st.caption("Browse tables, xem schema, chạy custom SQL")
st.divider()

# --- Get table list ---
tables_df, _, _ = run_query("""
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_type = 'BASE TABLE'
    ORDER BY table_name
""")

table_list = tables_df["table_name"].tolist() if tables_df is not None else []

if not table_list:
    st.error("Không lấy được danh sách bảng.")
    st.stop()

# --- Table selector ---
selected = st.selectbox(f"Chọn bảng ({len(table_list)} bảng)", table_list, key="explorer_table")

c1, c2 = st.columns([2, 1])

# --- Schema info ---
with c1:
    st.subheader("📐 Schema")
    schema_df, ms, _ = run_query(f"""
        SELECT column_name, data_type,
               character_maximum_length AS max_len,
               is_nullable,
               column_default
        FROM information_schema.columns
        WHERE table_name = '{selected}' AND table_schema = 'public'
        ORDER BY ordinal_position
    """)
    if schema_df is not None and not schema_df.empty:
        st.dataframe(schema_df, use_container_width=True, hide_index=True)
        st.caption(f"⏱️ {ms}ms")

# --- Constraints & indexes ---
with c2:
    st.subheader("🔑 Constraints")
    cons_df, _, _ = run_query(f"""
        SELECT conname AS constraint_name,
               contype AS type
        FROM pg_constraint
        WHERE conrelid = '{selected}'::regclass
        ORDER BY contype, conname
    """)
    if cons_df is not None and not cons_df.empty:
        # Map constraint types
        type_map = {"p": "PK", "f": "FK", "u": "UNIQUE", "c": "CHECK"}
        cons_df["type"] = cons_df["type"].map(type_map).fillna(cons_df["type"])
        st.dataframe(cons_df, use_container_width=True, hide_index=True)

    st.subheader("📇 Indexes")
    idx_df, _, _ = run_query(f"""
        SELECT indexname, indexdef
        FROM pg_indexes
        WHERE tablename = '{selected}' AND schemaname = 'public'
    """)
    if idx_df is not None and not idx_df.empty:
        for _, row in idx_df.iterrows():
            st.code(row["indexdef"], language="sql")

st.divider()

# --- Data preview ---
st.subheader(f"📊 Data Preview — `{selected}`")
limit = st.slider("Số dòng", 10, 200, 50, key="preview_limit")
data_df, ms, err = run_query(f"SELECT * FROM {selected} LIMIT {limit}")
if err:
    st.error(f"Lỗi: {err}")
elif data_df is not None:
    count_df, _, _ = run_query(f"SELECT COUNT(*) AS total FROM {selected}")
    total = count_df.iloc[0, 0] if count_df is not None else "?"
    st.caption(f"Showing {len(data_df)} / {total} rows | ⏱️ {ms}ms")
    st.dataframe(data_df, use_container_width=True)

# --- ISA children info ---
isa_parents = {
    "artists": ["solo_artists", "bands", "composers"],
    "contracts": ["recording_contracts", "distribution_contracts", "publishing_contracts"],
    "revenue_logs": ["streaming_revenue_details", "sync_revenue_details", "live_revenue_details"],
    "beneficiaries": ["artist_beneficiaries", "label_beneficiaries"],
}
if selected in isa_parents:
    st.markdown(f"**ISA children:**")
    child_cols = st.columns(len(isa_parents[selected]))
    for i, child in enumerate(isa_parents[selected]):
        cdf, _, _ = run_query(f"SELECT COUNT(*) FROM {child}")
        cnt = cdf.iloc[0, 0] if cdf is not None else 0
        child_cols[i].metric(child, cnt)

st.divider()

# --- Custom SQL ---
st.subheader("🖊️ Custom SQL")
st.markdown("Chỉ cho phép `SELECT` — dùng để verify dữ liệu khi GV hỏi.")

custom_sql = st.text_area(
    "SQL Query",
    value=f"SELECT * FROM {selected} LIMIT 10;",
    height=100,
    key="custom_sql",
)

if st.button("▶ Run", type="primary", key="btn_custom"):
    clean = custom_sql.strip().rstrip(";").strip()
    if not clean.upper().startswith("SELECT"):
        st.error("Chỉ cho phép câu lệnh SELECT.")
    else:
        with st.spinner("Đang thực thi..."):
            cdf, cms, cerr = run_query(clean)
        show_result(cdf, cms, cerr)
