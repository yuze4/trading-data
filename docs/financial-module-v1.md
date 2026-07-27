# Financial Statement Analysis Module v1

Status: the one-quarter pilot and five-quarter NVIDIA expansion were
runtime-verified in PostgreSQL 16. The ten-company research universe is now
registered; only NVIDIA has financial facts loaded so far.

This module is a new addition to the `yuze4/trading-data` fork. The upstream
repository supplies the market-data foundation; it does not contain the
financial-statement tables, mappings, views, or quality checks described here.

## Business purpose

The module turns a company's reported financial-statement data into a
repeatable research table. It is designed for questions such as:

- Is revenue growing?
- Is operating profitability improving?
- Is growth producing free cash flow?
- Is cash large relative to reported debt?
- Do we have enough history to calculate year-over-year growth?
- Are the facts complete and mapped to a known metric definition?

The output is a research aid. It is not a buy, sell, or guaranteed-return
system.

## What is retained from upstream

The fork retains the upstream project's market-data direction and source
integration work. The upstream repository's existing ingestion and CLI code
remain the foundation for later price-data integration.

## What this fork adds

| File | Addition |
|---|---|
| `sql/01_create_financial_reports.sql` | Normalized issuer and filing metadata tables |
| `sql/02_seed_nvidia_filing.sql` | Reproducible NVIDIA filing metadata seed |
| `sql/03_create_financial_facts.sql` | One-row-per-fact normalized financial table |
| `sql/04_seed_nvidia_financial_facts.sql` | Manual NVIDIA pilot facts and first calculations |
| `sql/05_create_financial_statement_summary_view.sql` | Margins, free cash flow, leverage summary, and structural status |
| `sql/06_create_financial_metric_mappings.sql` | Explicit source-concept-to-metric mapping table |
| `sql/07_create_financial_growth_view.sql` | Sequential and year-over-year growth using `LAG` |
| `sql/08_create_financial_quality_view.sql` | Missing, duplicate, unmapped, unit, period, and filing-date checks |
| `sql/09_validate_financial_module.sql` | One-pass validation queries for the complete module |
| `sql/10_seed_nvidia_historical_quarters.sql` | Four prior NVIDIA quarters for sequential and year-over-year analysis |
| `sql/11_seed_technology_research_universe.sql` | First-version ten-company AI infrastructure technology research universe |

## Data flow

```text
financial_reports
        |
        | report_id foreign key
        v
financial_facts  ---> financial_metric_mappings
        |
        v
vw_financial_statement_summary
        |
        +--> vw_financial_statement_growth
        |
        +--> vw_financial_data_quality_issues
```

## Run order

Run the files in one PostgreSQL session, preferably PostgreSQL 16 in the first
browser-based validation:

```text
01_create_financial_reports.sql
03_create_financial_facts.sql
02_seed_nvidia_filing.sql
11_seed_technology_research_universe.sql
04_seed_nvidia_financial_facts.sql
10_seed_nvidia_historical_quarters.sql
05_create_financial_statement_summary_view.sql
06_create_financial_metric_mappings.sql
07_create_financial_growth_view.sql
08_create_financial_quality_view.sql
09_validate_financial_module.sql
```

The order matters because the later views depend on tables and data created by
the earlier files.

## Expected pilot output

The first-version research universe should contain:

- ten active technology securities;
- one company with financial facts loaded so far: NVIDIA;
- nine additional securities registered for future filing ingestion.

The manually seeded NVIDIA pilot should contain:

- one issuer;
- five filings: Q1 FY26 through Q4 FY26 plus Q1 FY27;
- 45 financial facts, nine per filing;
- nine active manual mapping rows;
- five summary rows;
- five growth rows. The first four rows have incomplete comparison history;
  the current Q1 FY27 row can calculate sequential and year-over-year growth;
- zero quality issues, assuming all files run successfully.

The summary calculations use normalized positive CapEx:

```text
free cash flow = operating cash flow - CapEx
```

## SQL skills demonstrated

- primary keys, foreign keys, unique constraints, and `CHECK` constraints;
- transactions and idempotent `ON CONFLICT` upserts;
- `INNER JOIN` and `LEFT JOIN`;
- CTEs with `WITH`;
- conditional aggregation with `FILTER`;
- `CASE WHEN` data-quality classification;
- `NULLIF` for safe ratio calculations;
- `VIEW` for reusable analytical logic;
- `LAG` for sequential and year-over-year comparisons;
- `UNION ALL` for a unified quality-issue queue.

## Known limitations

1. The NVIDIA facts are a manually verified pilot seed, not an automatic
   SEC/XBRL ingestion pipeline.
2. The technology universe contains ten registered securities, but only NVIDIA
   has financial facts loaded at this stage. The other nine require the next
   filing-ingestion step.
3. The historical seed's `period_start` values are explicitly marked as
   unverified working boundaries. Production ingestion must read and validate
   the exact XBRL context for each fact.
4. Q2 and Q3 quarter-only operating cash flow and CapEx are derived from
   cumulative cash-flow statements; Q4 quarter-only values are derived from
   annual values less the first nine months. The seed documents that
   provenance, but it is not yet an automatic XBRL ingestion pipeline.
5. The quality view checks structural consistency; it does not prove that a
   source filing is economically correct.
6. Price performance, AI-infrastructure theme membership, portfolio holdings,
   and risk limits are future modules.

## Official source documents used for the historical seed

- [NVIDIA Q1 FY26 Form 10-Q](https://www.sec.gov/Archives/edgar/data/1045810/000104581025000116/nvda-20250427.htm)
- [NVIDIA Q2 FY26 Form 10-Q](https://www.sec.gov/Archives/edgar/data/1045810/000104581025000209/nvda-20250727.htm)
- [NVIDIA Q3 FY26 Form 10-Q](https://www.sec.gov/Archives/edgar/data/1045810/000104581025000230/nvda-20251026.htm)
- [NVIDIA FY26 Form 10-K](https://www.sec.gov/Archives/edgar/data/1045810/000104581026000021/nvda-20260125.htm)
- [NVIDIA Q4 FY26 earnings release](https://www.sec.gov/Archives/edgar/data/1045810/000104581026000019/q4fy26pr.htm)

## Career relevance

This module demonstrates financial data modeling, PostgreSQL constraints,
reproducible SQL transformations, data-quality controls, point-in-time filing
metadata, and window-function analysis. These are directly relevant to Data
Analyst, Financial Data Analyst, Investment Data Analyst, Performance Analyst,
Market Risk Analyst, and Junior Data Engineer applications.
