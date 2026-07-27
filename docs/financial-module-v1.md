# Financial Statement Analysis Module v1

Status: implementation batch prepared; PostgreSQL runtime verification is pending.

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
04_seed_nvidia_financial_facts.sql
05_create_financial_statement_summary_view.sql
06_create_financial_metric_mappings.sql
07_create_financial_growth_view.sql
08_create_financial_quality_view.sql
09_validate_financial_module.sql
```

The order matters because the later views depend on tables and data created by
the earlier files.

## Expected pilot output

The manually seeded NVIDIA pilot should contain:

- one issuer;
- one filing;
- nine financial facts;
- nine active manual mapping rows;
- one summary row;
- one growth row with `NEEDS_MORE_PERIODS`, because one filing is not enough
  for a year-over-year comparison;
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
2. The pilot `period_start` value `2026-01-26` is explicitly marked as an
   unverified working boundary in the seed SQL. Production ingestion must read
   and validate the XBRL context.
3. Only one filing is loaded, so growth calculations correctly report that more
   periods are required.
4. The quality view checks structural consistency; it does not prove that a
   source filing is economically correct.
5. Price performance, AI-infrastructure theme membership, portfolio holdings,
   and risk limits are future modules.

## Career relevance

This module demonstrates financial data modeling, PostgreSQL constraints,
reproducible SQL transformations, data-quality controls, point-in-time filing
metadata, and window-function analysis. These are directly relevant to Data
Analyst, Financial Data Analyst, Investment Data Analyst, Performance Analyst,
Market Risk Analyst, and Junior Data Engineer applications.
