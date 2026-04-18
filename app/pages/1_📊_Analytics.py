"""
Page 2: Analytics — Stored Procedures (SP1–SP8)
QUAN TRỌNG NHẤT — Demo trực tiếp các SP analytics.
"""

import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import os
from utils.db import run_query, show_result

# Load CSS
css_file = os.path.join(os.path.dirname(os.path.dirname(__file__)), "assets", "style.css")
if os.path.exists(css_file):
    with open(css_file) as f:
        st.markdown(f"<style>{f.read()}</style>", unsafe_allow_html=True)

st.title("📊 Khai thác dữ liệu — Stored Procedures")
st.caption("Chọn SP từ dropdown → xem SQL → chạy → xem kết quả + chart")
st.divider()

# --- SP Config ---
SPs = {
    "SP1: ROLLUP — Doanh thu theo nghệ sĩ & tháng": {
        "function": "sp_revenue_by_artist_rollup",
        "params": {"p_year": "int", "p_currency": "str"},
        "defaults": {"p_year": 2025, "p_currency": "VND"},
        "technique": "ROLLUP + GROUPING()",
        "requirement": "✅ ROLLUP (đề bài yêu cầu)",
        "description": "Tổng doanh thu theo nghệ sĩ & tháng với sub-total và grand total.",
        "chart_type": "bar",
        "sql_template": "SELECT * FROM sp_revenue_by_artist_rollup({p_year}, '{p_currency}');",
    },
    "SP2: PIVOT — Doanh thu theo nguồn": {
        "function": "sp_revenue_pivot_by_source_v2",
        "params": {"p_year": "int"},
        "defaults": {"p_year": 2025},
        "technique": "PIVOT (FILTER aggregation)",
        "requirement": "✅ PIVOT (đề bài yêu cầu)",
        "description": "Pivot doanh thu theo nguồn: Streaming / Sync / Live cho mỗi nghệ sĩ.",
        "chart_type": "stacked_bar",
        "sql_template": "SELECT * FROM sp_revenue_pivot_by_source_v2({p_year});",
    },
    "SP3: Subquery lồng — Top nghệ sĩ": {
        "function": "sp_top_earning_artists",
        "params": {"p_year": "int"},
        "defaults": {"p_year": 2025},
        "technique": "Nested subquery 2 tầng trong HAVING",
        "requirement": "✅ Truy vấn lồng (đề bài yêu cầu)",
        "description": "Top nghệ sĩ có doanh thu cao nhất bằng nested subquery trong HAVING.",
        "chart_type": "horizontal_bar",
        "sql_template": "SELECT * FROM sp_top_earning_artists({p_year});",
    },
    "SP4: LATERAL — Phân chia doanh thu hợp đồng": {
        "function": "sp_contract_revenue_distribution",
        "params": {},
        "defaults": {},
        "technique": "LATERAL JOIN + Beneficiaries ISA",
        "requirement": "Nâng cao",
        "description": "Phân bổ doanh thu theo contract splits, resolve beneficiary via ISA.",
        "chart_type": "treemap",
        "sql_template": "SELECT * FROM sp_contract_revenue_distribution();",
    },
    "SP5: Window — Top tracks mỗi nghệ sĩ": {
        "function": "sp_top_tracks_per_artist",
        "params": {"p_top_n": "int", "p_year": "int"},
        "defaults": {"p_top_n": 3, "p_year": 2025},
        "technique": "CTE + RANK() Window function",
        "requirement": "Nâng cao",
        "description": "Top N tracks theo doanh thu cho mỗi nghệ sĩ, dùng RANK() window.",
        "chart_type": "bar",
        "sql_template": "SELECT * FROM sp_top_tracks_per_artist({p_top_n}, {p_year});",
    },
    "SP6: Audit — Đối soát wallet": {
        "function": "sp_wallet_audit_report",
        "params": {},
        "defaults": {},
        "technique": "Multi-CTE (earned/withdrawn/pending)",
        "requirement": "Nâng cao — Financial audit",
        "description": "Đối soát: earned − withdrawn = balance? Highlight CẢNH BÁO nếu sai lệch.",
        "chart_type": "table_highlight",
        "sql_template": "SELECT * FROM sp_wallet_audit_report();",
    },
    "SP7: ROLLUP+Window — Venue analytics": {
        "function": "sp_venue_event_analytics",
        "params": {"p_year": "int"},
        "defaults": {"p_year": 2025},
        "technique": "CTE + ROLLUP + DENSE_RANK()",
        "requirement": "✅ ROLLUP (đề bài yêu cầu)",
        "description": "Thống kê sự kiện theo venue với ROLLUP và xếp hạng DENSE_RANK().",
        "chart_type": "bar",
        "sql_template": "SELECT * FROM sp_venue_event_analytics({p_year});",
    },
    "SP8: JSONB — Tìm nghệ sĩ": {
        "function": "sp_search_artists",
        "params": {"p_genre": "str_nullable", "p_name": "str_nullable"},
        "defaults": {"p_genre": "pop", "p_name": ""},
        "technique": "GIN index + JSONB @>",
        "requirement": "Nâng cao — NoSQL trong SQL",
        "description": "Tìm nghệ sĩ theo genre (JSONB containment) và/hoặc tên (ILIKE).",
        "chart_type": "table",
        "sql_template": "SELECT * FROM sp_search_artists({p_genre}, {p_name});",
    },
}

# --- SP Selector ---
sp_name = st.selectbox("Chọn Stored Procedure", list(SPs.keys()), key="sp_select")
sp = SPs[sp_name]

# --- Info box ---
col_info, col_badge = st.columns([3, 1])
with col_info:
    st.markdown(f"**Mô tả:** {sp['description']}")
    st.markdown(f"**Kỹ thuật:** `{sp['technique']}`")
with col_badge:
    if sp["requirement"].startswith("✅"):
        st.success(sp["requirement"])
    else:
        st.info(sp["requirement"])

st.divider()

# --- Parameter inputs ---
param_values = {}
if sp["params"]:
    st.subheader("Tham số")
    pcols = st.columns(len(sp["params"]))
    for i, (pname, ptype) in enumerate(sp["params"].items()):
        default = sp["defaults"].get(pname, "")
        with pcols[i]:
            if ptype == "int":
                param_values[pname] = st.number_input(pname, value=default, key=f"p_{pname}")
            elif ptype == "str":
                param_values[pname] = st.text_input(pname, value=default, key=f"p_{pname}")
            elif ptype == "str_nullable":
                val = st.text_input(pname, value=str(default) if default else "", key=f"p_{pname}")
                param_values[pname] = val if val.strip() else None

# --- Build SQL ---
def build_sql(sp_cfg, params):
    fmt = {}
    for k, v in params.items():
        if v is None:
            fmt[k] = "NULL"
        elif isinstance(v, str):
            fmt[k] = f"'{v}'"
        else:
            fmt[k] = str(int(v))
    return sp_cfg["sql_template"].format(**fmt)

sql = build_sql(sp, param_values)

# --- SQL display ---
with st.expander("📝 SQL Query", expanded=True):
    st.code(sql, language="sql")

# --- Run button ---
if st.button("🚀 Chạy SP", type="primary", use_container_width=True):
    with st.spinner("Đang thực thi..."):
        df, ms, err = run_query(sql)

    if err:
        st.error(f"Lỗi: {err}")
        st.info("💡 Tip: Neon compute đang warm up. Thử lại sau 3 giây.")
    elif df is not None and not df.empty:
        st.success(f"⏱️ {ms}ms | {len(df)} rows")

        # --- Data table ---
        st.subheader("📋 Kết quả")

        if sp["chart_type"] == "table_highlight":
            # Highlight warning rows for wallet audit
            def highlight_warning(row):
                if "trang_thai" in row.index and row["trang_thai"] == "CẢNH BÁO":
                    return ["background-color: #F96167; color: white"] * len(row)
                return [""] * len(row)
            st.dataframe(df.style.apply(highlight_warning, axis=1), use_container_width=True)
        else:
            st.dataframe(df, use_container_width=True)

        # --- Charts ---
        st.subheader("📊 Visualization")

        chart_type = sp["chart_type"]

        if chart_type == "bar":
            # Generic grouped bar — use first text col as x, last numeric col as y
            text_cols = df.select_dtypes(include=["object"]).columns.tolist()
            num_cols = df.select_dtypes(include=["number"]).columns.tolist()
            if text_cols and num_cols:
                # Filter out summary rows for chart
                x_col = text_cols[0]
                y_col = num_cols[-1]
                chart_df = df[~df[x_col].str.contains("TỔNG CỘNG|Tất cả", na=False)]
                if not chart_df.empty:
                    fig = px.bar(
                        chart_df, x=x_col, y=y_col,
                        color=text_cols[1] if len(text_cols) > 1 else None,
                        text_auto=True,
                        color_discrete_sequence=px.colors.qualitative.Set2,
                    )
                    fig.update_layout(height=450, xaxis_tickangle=-45)
                    st.plotly_chart(fig, use_container_width=True)

        elif chart_type == "stacked_bar":
            if "nghe_si" in df.columns:
                value_cols = [c for c in df.columns if c not in ("nghe_si", "tong")]
                if value_cols:
                    fig = go.Figure()
                    colors = ["#1E2761", "#F96167", "#CADCFC"]
                    for i, col in enumerate(value_cols):
                        fig.add_trace(go.Bar(
                            name=col, x=df["nghe_si"], y=df[col],
                            marker_color=colors[i % len(colors)],
                        ))
                    fig.update_layout(barmode="stack", height=450, xaxis_tickangle=-45)
                    st.plotly_chart(fig, use_container_width=True)

        elif chart_type == "horizontal_bar":
            text_cols = df.select_dtypes(include=["object"]).columns.tolist()
            num_cols = df.select_dtypes(include=["number"]).columns.tolist()
            if text_cols and num_cols:
                fig = px.bar(
                    df, y=text_cols[0], x=num_cols[0], orientation="h",
                    text_auto=True,
                    color_discrete_sequence=["#1E2761"],
                )
                fig.update_layout(height=400)
                st.plotly_chart(fig, use_container_width=True)

        elif chart_type == "treemap":
            text_cols = df.select_dtypes(include=["object"]).columns.tolist()
            num_cols = df.select_dtypes(include=["number"]).columns.tolist()
            if len(text_cols) >= 2 and num_cols:
                val_col = num_cols[-1]
                chart_df = df[df[val_col] > 0] if not df.empty else df
                if not chart_df.empty:
                    fig = px.treemap(
                        chart_df,
                        path=[text_cols[0], text_cols[1]],
                        values=val_col,
                        color_discrete_sequence=["#1E2761", "#F96167", "#CADCFC"],
                    )
                    fig.update_layout(height=500)
                    st.plotly_chart(fig, use_container_width=True)

        elif chart_type == "table":
            pass  # Already shown as dataframe above

    elif df is not None:
        st.info("Không có dữ liệu.")
        st.caption(f"⏱️ {ms}ms | 0 rows")
