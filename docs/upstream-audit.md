# Upstream Repository Audit

## Scope

- Upstream repository: lokhiufung/trading-data
- Fork repository: yuze4/trading-data
- Audited commit: 34377ba6959b7628982cfd71e6406508a9401bbb
- Audit date: 2026-07-25
- Audit method: source and documentation inspection

Runtime downloads from Yahoo Finance, Interactive Brokers, and TimescaleDB were not executed during this audit.

## What the upstream project already provides

- Multi-source market-data adapters for Yahoo Finance, Interactive Brokers, Binance, Bybit, and FirstRate futures data.
- A local data-lake client using YAML data menus and Parquet files under the user data directory.
- A Click-based command-line interface for adding, updating, deleting, migrating, and inspecting data sources.
- SQLAlchemy models for data sources, products, and OHLCV bars.
- A migration path that attempts to load Parquet bars into PostgreSQL through SQLAlchemy.

## Verified implementation areas

| Area | Verified paths | Current role |
| --- | --- | --- |
| Yahoo Finance | trading_data/data_sources/yfinance_data_source.py | Daily OHLCV ingestion for stocks, ETFs, and FX |
| Interactive Brokers | trading_data/data_sources/ib_data_source.py | Historical TWS or IB Gateway ingestion |
| Local data lake | trading_data/datalake_client.py | Parquet storage, menus, reads, and updates |
| Database layer | trading_data/timescaledb/ | SQLAlchemy session and basic ORM models |
| CLI | trading_data/cli.py and setup.py | Command-line data management |
| Migration scripts | migrate_v1_to_v2.py and mirgrate_v2_to_v3.py | Legacy file naming and Parquet migration attempts |

## Audit findings

1. The current data lake writes Parquet files, while filename parsing and parts of the documentation still expect CSV files.
2. The Parquet migration script contains a commented-out Parquet write and an active CSV deletion path; it requires repair before use.
3. The repository has SQLAlchemy models but no SQL files, database migration system, table bootstrap, Timescale hypertable DDL, or automated tests.
4. The current OHLCV model does not yet provide the composite uniqueness, indexes, CHECK constraints, and security master required for research analytics.
5. The dependency list does not explicitly include an IB API package or a Parquet engine.
6. Runtime behavior against external data providers and a real PostgreSQL or TimescaleDB instance is not yet verified.

## What this project will retain

- The upstream repository structure and data-source interfaces.
- The original Apache License 2.0 and upstream attribution.
- The existing Yahoo Finance and Interactive Brokers ingestion concepts.
- Parquet as a raw or staging format, subject to reliability fixes.
- The existing CLI as the starting point for future data-quality and analytics commands.

## What this project will add

- A normalized PostgreSQL and TimescaleDB research schema.
- Securities, daily prices, benchmarks, industry themes, and theme membership tables.
- SQL views and materialized views for returns, rolling performance, benchmark-relative strength, rankings, and overheat states.
- Data-quality checks, pipeline-run records, and documented constraints and indexes.
- Financial-report data with actual publication dates to reduce look-ahead bias.
- Portfolio, trade, position, concentration, and risk-limit analytics.

## Attribution

This project is derived from lokhiufung/trading-data. The original Apache License 2.0, original author attribution, and project source must be preserved. New SQL schemas, data models, analytics, tests, and documentation will be identified as project contributions.

## Status

Phase 0 audit is complete. No production analytics code has been added yet.