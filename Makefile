.PHONY: help install crawl crawl-mb crawl-tb etl etl-transform etl-load pipeline app db-up db-down db-clean docker-build docker-pipeline clean

# Default target
help:
	@echo "Artist Revenue Management Project"
	@echo "---------------------------------"
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  help              Show this help message"
	@echo "  install           Install dependencies using uv"
	@echo "  crawl             Run all crawlers (MusicBrainz & Ticketbox)"
	@echo "  crawl-mb          Run only MusicBrainz crawler"
	@echo "  crawl-tb          Run only Ticketbox crawler"
	@echo "  etl               Run full ETL pipeline (Transform & Load)"
	@echo "  etl-transform     Run only ETL Transform phase"
	@echo "  etl-load          Run only ETL Load phase"
	@echo "  pipeline          Run crawlers and full ETL locally"
	@echo "  app               Run the Streamlit application locally"
	@echo "  db-up             Start PostgreSQL and pgAdmin via Docker Compose"
	@echo "  db-down           Stop and remove Docker Compose services"
	@echo "  db-clean          Remove Docker volumes (WARNING: deletes database data)"
	@echo "  docker-build      Build all Docker images (App, Crawlers, ETL)"
	@echo "  docker-pipeline   Run Crawlers and ETL via Docker Compose profile"
	@echo "  clean             Remove Python cache and compiled files"

install:
	uv sync

crawl-mb:
	uv run -m crawlers.musicbrainz.crawl_musicbrainz

crawl-tb:
	uv run -m crawlers.ticketbox.crawl_ticketbox

crawl: crawl-mb crawl-tb

etl:
	uv run -m etl.run_etl

etl-transform:
	uv run -m etl.run_etl transform

etl-load:
	uv run -m etl.run_etl load

pipeline: crawl etl

app:
	cd app && uv run streamlit run app.py

db-up:
	docker compose up -d postgres pgadmin streamlit

db-down:
	docker compose down

db-clean:
	docker compose down -v

docker-build:
	docker compose --profile pipeline build

docker-pipeline:
	docker compose --profile pipeline up crawler etl

clean:
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type f -name "*.pyC" -delete
	find . -type f -name "*.pyo" -delete
