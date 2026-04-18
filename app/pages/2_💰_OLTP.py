"""
Page 3: OLTP — Giao dịch (Demo transaction)
SP9: Register Artist, SP10: Record Revenue, SP11+SP12: Withdrawal
"""

import streamlit as st
import os
from utils.db import run_query, run_procedure

# Load CSS
css_file = os.path.join(os.path.dirname(os.path.dirname(__file__)), "assets", "style.css")
if os.path.exists(css_file):
    with open(css_file) as f:
        st.markdown(f"<style>{f.read()}</style>", unsafe_allow_html=True)

st.title("💰 Giao dịch OLTP")
st.caption("Demo multi-table INSERT, row-level locking, state machine")
st.divider()

tab1, tab2, tab3 = st.tabs(["🎤 Đăng ký nghệ sĩ", "🎵 Ghi doanh thu", "💸 Rút tiền"])

# ==================== Tab 1: Register Artist (SP9) ====================
with tab1:
    st.subheader("SP9 — Đăng ký nghệ sĩ mới")
    st.markdown("""
    **Kỹ thuật:** Multi-table INSERT (atomicity) — 1 transaction tạo:
    `artists` → ISA subtype → `artist_roles` → `artist_wallets` → `beneficiaries` + `artist_beneficiaries`
    """)

    with st.expander("📝 SQL Template", expanded=False):
        st.code("""CALL sp_register_artist(
    p_stage_name, p_full_name,
    NULL,  -- OUT new_artist_id
    p_label_id, p_metadata::jsonb, p_artist_type,
    p_vocal_range, p_pen_name, p_member_count
);""", language="sql")

    c1, c2 = st.columns(2)
    with c1:
        stage_name = st.text_input("Nghệ danh", value="Demo Artist", key="reg_stage")
        full_name = st.text_input("Tên thật", value="Nguyen Van A", key="reg_full")
        artist_type = st.selectbox("Loại", ["solo", "band", "composer"], key="reg_type")
    with c2:
        # Get labels for dropdown
        labels_df, _, _ = run_query("SELECT label_id, name FROM labels ORDER BY name")
        label_options = {"(Không có)": "NULL"}
        if labels_df is not None and not labels_df.empty:
            for _, row in labels_df.iterrows():
                label_options[row["name"]] = str(row["label_id"])
        label_choice = st.selectbox("Label", list(label_options.keys()), key="reg_label")
        label_id = label_options[label_choice]

        genre = st.text_input("Genre", value="pop", key="reg_genre")

        if artist_type == "solo":
            vocal_range = st.text_input("Vocal Range", value="C3-C6", key="reg_vocal")
        elif artist_type == "band":
            member_count = st.number_input("Số thành viên", min_value=2, value=4, key="reg_members")
        elif artist_type == "composer":
            pen_name = st.text_input("Bút danh", value="", key="reg_pen")

    if st.button("🎤 Đăng ký", type="primary", key="btn_register"):
        vocal = f"'{vocal_range}'" if artist_type == "solo" else "NULL"
        pen = f"'{pen_name}'" if artist_type == "composer" and pen_name else "NULL"
        members = str(member_count) if artist_type == "band" else "NULL"

        sql = f"""CALL sp_register_artist(
    '{stage_name}', '{full_name}',
    NULL,
    {label_id}, '{{"genre": "{genre}"}}'::jsonb, '{artist_type}',
    {vocal}, {pen}, {members}
);"""
        with st.expander("SQL thực thi", expanded=True):
            st.code(sql, language="sql")

        with st.spinner("Đang đăng ký..."):
            result, ms, err = run_procedure(sql)

        if err:
            st.error(f"Lỗi: {err}")
        else:
            new_id = result[0] if result else "?"
            st.success(f"✅ Thành công! Artist ID = {new_id}")
            isa_table = {"solo": "solo_artists", "band": "bands", "composer": "composers"}[artist_type]
            st.markdown(f"""
            → Đã tạo: `artists` + `{isa_table}` + `artist_roles` + `artist_wallets` + `beneficiaries`
            → **5 bảng INSERT trong 1 transaction**
            """)
            st.caption(f"⏱️ {ms}ms")

# ==================== Tab 2: Record Revenue (SP10) ====================
with tab2:
    st.subheader("SP10 — Ghi nhận doanh thu")
    st.markdown("**Kỹ thuật:** ISA discriminator insert (revenue_logs → streaming/sync/live)")

    with st.expander("📝 SQL Template", expanded=False):
        st.code("""CALL sp_record_revenue(
    p_track_id, p_amount, p_revenue_type,
    NULL,  -- OUT new_log_id
    p_currency, p_raw_data,
    p_stream_count, p_per_stream_rate, p_platform,
    p_licensee_name, p_usage_type,
    p_event_id, p_ticket_sold
);""", language="sql")

    c1, c2 = st.columns(2)
    with c1:
        # Get tracks
        tracks_df, _, _ = run_query("""
            SELECT t.track_id, t.title, a.stage_name
            FROM tracks t
            JOIN albums al ON t.album_id = al.album_id
            JOIN artists a ON al.artist_id = a.artist_id
            ORDER BY a.stage_name, t.title
            LIMIT 50
        """)
        track_options = {}
        if tracks_df is not None and not tracks_df.empty:
            for _, row in tracks_df.iterrows():
                track_options[f"{row['stage_name']} — {row['title']}"] = row["track_id"]
        track_choice = st.selectbox("Track", list(track_options.keys()), key="rev_track")
        track_id = track_options.get(track_choice, 1)

        amount = st.number_input("Số tiền (VND)", min_value=1000, value=50000000, step=1000000, key="rev_amount")
    with c2:
        rev_type = st.selectbox("Loại doanh thu", ["streaming", "sync", "live"], key="rev_type")
        currency = st.selectbox("Đơn vị tiền", ["VND", "USD"], key="rev_currency")

    # Type-specific params
    if rev_type == "streaming":
        sc1, sc2, sc3 = st.columns(3)
        with sc1:
            stream_count = st.number_input("Số lượt stream", value=1000000, key="rev_streams")
        with sc2:
            per_stream = st.number_input("Rate/stream", value=0.034, format="%.4f", key="rev_rate")
        with sc3:
            platform = st.selectbox("Platform", ["Spotify", "Apple Music", "Zing MP3", "YouTube Music"], key="rev_plat")
    elif rev_type == "sync":
        sc1, sc2 = st.columns(2)
        with sc1:
            licensee = st.text_input("Licensee", value="VTV", key="rev_licensee")
        with sc2:
            usage = st.selectbox("Usage type", ["Phim ảnh", "Quảng cáo", "Game", "Khác"], key="rev_usage")
    elif rev_type == "live":
        events_df, _, _ = run_query("SELECT event_id, event_name FROM events ORDER BY event_date DESC LIMIT 20")
        event_options = {}
        if events_df is not None and not events_df.empty:
            for _, row in events_df.iterrows():
                event_options[row["event_name"]] = row["event_id"]
        sc1, sc2 = st.columns(2)
        with sc1:
            event_choice = st.selectbox("Event", list(event_options.keys()) if event_options else ["N/A"], key="rev_event")
            event_id = event_options.get(event_choice)
        with sc2:
            ticket_sold = st.number_input("Số vé bán", value=3000, key="rev_tickets")

    if st.button("🎵 Ghi nhận", type="primary", key="btn_revenue"):
        # SP10 accepts lowercase and UPPER()s internally
        if rev_type == "streaming":
            sql = f"""CALL sp_record_revenue(
    {track_id}, {amount}, '{rev_type}',
    NULL,
    '{currency}', '{{}}'::jsonb,
    {stream_count}, {per_stream}, '{platform}',
    NULL, NULL, NULL, NULL
);"""
        elif rev_type == "sync":
            sql = f"""CALL sp_record_revenue(
    {track_id}, {amount}, '{rev_type}',
    NULL,
    '{currency}', '{{}}'::jsonb,
    NULL, NULL, NULL,
    '{licensee}', '{usage}', NULL, NULL
);"""
        else:
            sql = f"""CALL sp_record_revenue(
    NULL, {amount}, '{rev_type}',
    NULL,
    '{currency}', '{{}}'::jsonb,
    NULL, NULL, NULL,
    NULL, NULL, {event_id}, {ticket_sold}
);"""

        with st.expander("SQL thực thi", expanded=True):
            st.code(sql, language="sql")

        with st.spinner("Đang ghi nhận..."):
            result, ms, err = run_procedure(sql)

        if err:
            st.error(f"Lỗi: {err}")
            st.info("💡 Kiểm tra track_id và event_id có hợp lệ không.")
        else:
            new_id = result[0] if result else "?"
            st.success(f"✅ Revenue logged! Log ID = {new_id}")
            st.markdown(f"→ ISA child: `{rev_type}_revenue_details` đã được tạo")
            st.caption(f"⏱️ {ms}ms")

# ==================== Tab 3: Withdrawal (SP11 + SP12) ====================
with tab3:
    st.subheader("SP11 + SP12 — Rút tiền & State Machine")
    st.markdown("""
    **Kỹ thuật:**
    - `SELECT ... FOR UPDATE` (row-level locking)
    - State machine: `PENDING → APPROVED → COMPLETED` (hoặc `REJECTED`)
    - Balance chỉ giảm khi `COMPLETED` (BR-02)
    """)

    # Get artists with wallets
    wallet_df, _, _ = run_query("""
        SELECT a.artist_id, a.stage_name, w.balance,
               COALESCE((SELECT SUM(amount) FROM withdrawals
                         WHERE artist_id = a.artist_id AND status IN ('PENDING','APPROVED')), 0) AS pending
        FROM artists a
        JOIN artist_wallets w ON a.artist_id = w.artist_id
        ORDER BY a.stage_name
    """)

    if wallet_df is not None and not wallet_df.empty:
        artist_options = {}
        for _, row in wallet_df.iterrows():
            artist_options[row["stage_name"]] = row

        artist_choice = st.selectbox("Nghệ sĩ", list(artist_options.keys()), key="wd_artist")
        info = artist_options[artist_choice]

        mc1, mc2, mc3 = st.columns(3)
        mc1.metric("Balance", f"{info['balance']:,.0f} VND")
        mc2.metric("Pending", f"{info['pending']:,.0f} VND")
        mc3.metric("Available", f"{info['balance'] - info['pending']:,.0f} VND")

        st.divider()

        # --- Request withdrawal ---
        st.markdown("#### Yêu cầu rút tiền (SP11)")
        wc1, wc2 = st.columns(2)
        with wc1:
            wd_amount = st.number_input(
                "Số tiền rút (VND)", min_value=0, value=1000, step=1000, key="wd_amount"
            )
        with wc2:
            wd_method = st.selectbox("Phương thức", ["bank_transfer", "momo", "zalopay"], key="wd_method")

        if st.button("💸 Yêu cầu rút", type="primary", key="btn_withdraw"):
            sql = f"CALL sp_request_withdrawal({int(info['artist_id'])}, {wd_amount}, NULL, '{wd_method}', NULL);"
            with st.expander("SQL thực thi", expanded=True):
                st.code(sql, language="sql")
            with st.spinner("Đang xử lý..."):
                result, ms, err = run_procedure(sql)
            if err:
                st.error(f"Lỗi: {err}")
            else:
                new_id = result[0] if result else "?"
                st.success(f"✅ Withdrawal #{new_id} created (status: PENDING)")
                st.caption(f"⏱️ {ms}ms")

        st.divider()

        # --- Process withdrawal (SP12) ---
        st.markdown("#### Xử lý withdrawal (SP12) — State Machine")
        st.markdown("`PENDING` → `APPROVED` → `COMPLETED` | `REJECTED`")

        pending_df, _, _ = run_query(f"""
            SELECT withdrawal_id, amount, status, method,
                   TO_CHAR(requested_at, 'DD/MM HH24:MI') as requested
            FROM withdrawals
            WHERE artist_id = {int(info['artist_id'])}
            ORDER BY requested_at DESC LIMIT 10
        """)

        if pending_df is not None and not pending_df.empty:
            st.dataframe(pending_df, use_container_width=True)

            pc1, pc2 = st.columns(2)
            with pc1:
                wd_id = st.number_input("Withdrawal ID", min_value=1, value=int(pending_df.iloc[0]["withdrawal_id"]), key="wd_id")
            with pc2:
                action = st.selectbox("Action", ["approve", "reject", "complete"], key="wd_action")

            if st.button("⚡ Process", type="primary", key="btn_process"):
                sql = f"CALL sp_process_withdrawal({wd_id}, '{action}');"
                with st.expander("SQL thực thi", expanded=True):
                    st.code(sql, language="sql")
                with st.spinner("Đang xử lý..."):
                    result, ms, err = run_procedure(sql)
                if err:
                    st.error(f"Lỗi: {err}")
                else:
                    st.success(f"✅ Withdrawal #{wd_id} → {action}")
                    if action == "complete":
                        st.markdown("→ Balance đã bị trừ (BR-02)")
                    st.caption(f"⏱️ {ms}ms")
                    st.rerun()
        else:
            st.info("Chưa có withdrawal nào.")
    else:
        st.warning("Không tìm thấy nghệ sĩ nào có wallet.")
