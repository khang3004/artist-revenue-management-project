# 🎵 Artist Revenue Management System

> **MDL018 — Tổ chức và Quản lý Dữ liệu**
> Trường Đại học Khoa Học Tự Nhiên — ĐHQG-HCM
---

## 🏗️ Tech Stack

| Layer | Công nghệ |
|-------|-----------|
| Database | PostgreSQL 16 + pgvector |
| Backend | SQL Stored Procedures |
| Frontend | Streamlit + Plotly |
| Infra | Docker Compose |
| VCS | Git + GitHub |

---

## 📁 Cấu trúc thư mục

```
artist-revenue-management/
│
├── README.md                       # File này
├── CONTRIBUTING.md                  # Git conventions (xem bên dưới)
├── .gitignore
├── .env.example                    # Template biến môi trường
├── docker-compose.yml              # PostgreSQL + pgAdmin + Streamlit
│
├── db/                             # 🗄️ Database scripts
│   ├── migrations/                 # DDL scripts (chạy theo thứ tự)
│   │   ├── 001_create_tables.sql
│   │   ├── 002_create_isa.sql      # Bảng ISA (solo_artist, band)
│   │   └── 003_create_views.sql    # Views + Materialized Views
│   ├── seeds/                      # Dữ liệu mẫu
│   │   ├── 001_seed_labels.sql
│   │   ├── 002_seed_artists.sql
│   │   ├── 003_seed_albums_tracks.sql
│   │   ├── 004_seed_contracts.sql
│   │   ├── 005_seed_revenue.sql
│   │   └── 006_seed_bookings.sql
│   └── procedures/                 # Stored procedures
│       ├── sp_revenue_rollup.sql
│       ├── sp_revenue_pivot.sql
│       ├── sp_top_artists.sql
│       ├── sp_contract_splits.sql
│       └── sp_booking_stats.sql
│
├── app/                            # 🖥️ Streamlit application
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── app.py                      # Main entry point
│   ├── pages/
│   │   ├── 1_📊_Dashboard.py
│   │   ├── 2_🎤_Artists.py
│   │   └── 3_💰_Revenue.py
│   ├── utils/
│   │   └── db.py                   # Database connection helper
│   └── assets/
│       └── style.css
│
├── docs/                           # 📝 Tài liệu đồ án
│   ├── dac-ta-yeu-cau.md           # Đặc tả yêu cầu dữ liệu
│   ├── thiet-ke-luan-ly.md         # Thiết kế luận lý
│   ├── thiet-ke-vat-ly.md          # Thiết kế vật lý
│   ├── stored-procedures-plan.md   # Kế hoạch stored procedures
│   └── erd/
│       ├── erd.dbml                # Source ERD (dbdiagram.io)
│       └── erd.png                 # Export ERD image
│
├── reports/                        # 📄 Sản phẩm nộp
│   ├── MaNhom.docx                 # Báo cáo
│   └── screenshots/                # Kết quả khai thác
│       ├── sp1_revenue_rollup.png
│       ├── sp2_revenue_pivot.png
│       └── ...
│
└── slides/                         # 🎬 Slide trình bày
    └── MaNhom.tex                  #TODO: will add later for setting up
```

---

## 🚀 Quickstart

```bash
# 1. Clone repo
git clone https://github.com/<org>/artist-revenue-management.git
cd artist-revenue-management

# 2. Copy env
cp .env.example .env

# 3. Khởi chạy
docker compose up -d

# 4. Truy cập
# Streamlit:  http://localhost:8501
# pgAdmin:    http://localhost:5050
```

---

## 👥 Thành viên

| Vai trò | Thành viên | MSSV |
|---------|-----------|------|
| DB Architect (A) | [Tên] | [MSSV] |
| SQL Developer (B) | [Tên] | [MSSV] |
| Query Engineer (C) | [Tên] | [MSSV] |
| Report & Demo (D) | [Tên] | [MSSV] |
