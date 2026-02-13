# 🎵 Artist Revenue Management System

> **MDL018 — Data Organization and Management**
> University of Science — VNU-HCM

---

## 🏗️ Tech Stack

| Layer    | Technology               |
| -------- | ------------------------ |
| Database | PostgreSQL 16 + pgvector |
| Backend  | SQL Stored Procedures    |
| Frontend | Streamlit + Plotly       |
| Infra    | Docker Compose           |
| VCS      | Git + GitHub             |

---

## 📁 Project Structure

```
artist-revenue-management/
│
├── README.md                       # This file
├── CONTRIBUTING.md                # Git conventions and workflow
├── .gitignore
├── .env.example                   # Environment variables template
├── docker-compose.yml             # PostgreSQL + pgAdmin + Streamlit
│
├── db/                             # 🗄️ Database scripts
│   ├── migrations/                 # DDL scripts (run in order)
│   │   ├── 001_create_tables.sql
│   │   ├── 002_create_isa.sql      # ISA tables (solo_artist, band)
│   │   └── 003_create_views.sql    # Views + Materialized Views
│   ├── seeds/                      # Sample data
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
├── docs/                           # 📝 Project documentation
│   ├── dac-ta-yeu-cau.md           # Data requirements specification
│   ├── thiet-ke-luan-ly.md         # Logical design
│   ├── thiet-ke-vat-ly.md          # Physical design
│   ├── stored-procedures-plan.md   # Stored procedures plan
│   └── erd/
│       ├── erd.dbml                # ERD source (dbdiagram.io)
│       └── erd.png                 # ERD image export
│
├── reports/                        # 📄 Deliverables
│   ├── MaNhom.docx                 # Final report
│   └── screenshots/                # Query results
│       ├── sp1_revenue_rollup.png
│       ├── sp2_revenue_pivot.png
│       └── ...
│
└── slides/                         # 🎬 Presentation slides
    └── main.tex                    # LaTeX presentation file
```

---

## 🚀 Quickstart

```bash
# 1. Clone repository
git clone https://github.com/<org>/artist-revenue-management.git
cd artist-revenue-management

# 2. Copy environment file
cp .env.example .env

# 3. Start services
docker compose up -d

# 4. Access applications
# Streamlit:  http://localhost:8501
# pgAdmin:    http://localhost:5050
```

---

## 👥 Team Members

| Role               | Member | Student ID |
| ------------------ | ------ | ---------- |
| DB Architect (A)   | [Name] | [ID]       |
| SQL Developer (B)  | [Name] | [ID]       |
| Query Engineer (C) | [Name] | [ID]       |
| Report & Demo (D)  | [Name] | [ID]       |

---

## 📝 Development Workflow

1. **Create feature branch**: See [CONTRIBUTING.md](CONTRIBUTING.md) for branch naming conventions
2. **Implement changes**: Follow code standards and commit conventions
3. **Test locally**: Use Docker Compose for local testing
4. **Create pull request**: Request team review before merging
5. **Merge to develop**: Integration branch for all features
6. **Release to main**: Production-ready code only

---

## 📚 Documentation

- **Data Specification**: [docs/dac-ta-yeu-cau.md](docs/dac-ta-yeu-cau.md)
- **Logical Design**: [docs/thiet-ke-luan-ly.md](docs/thiet-ke-luan-ly.md)
- **Physical Design**: [docs/thiet-ke-vat-ly.md](docs/thiet-ke-vat-ly.md)
- **Stored Procedures**: [docs/stored-procedures-plan.md](docs/stored-procedures-plan.md)
- **Git Workflow**: [CONTRIBUTING.md](CONTRIBUTING.md)

---

## 🎯 Project Status

- [x] Project structure initialized
- [x] Docker configuration completed
- [x] Documentation templates created
- [ ] Database schema implementation
- [ ] Sample data insertion
- [ ] Stored procedures development
- [ ] Streamlit dashboard development
- [ ] Final report and presentation

---

## 📞 Contact

For questions or issues, please open an issue in the repository or contact the team lead.
