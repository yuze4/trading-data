# Financial Statement Metrics v1

Status: design only. The metric definitions below are planned for the first financial-statement module. No live SEC data has been loaded and no calculation has been verified yet.

## Scope

The first financial-statement pilot will focus on U.S.-listed companies that file with the SEC. The module will preserve both:

- the fiscal reporting period;
- the actual filing date.

The filing date is required for point-in-time analysis and to reduce look-ahead bias.

The source data will use SEC EDGAR submissions and extracted XBRL facts where possible. Source URLs, accession numbers, units, forms, and filing dates must be retained.

## Ten base metrics

| # | Canonical metric | Typical financial statement | Initial XBRL concept examples | Business question |
|---|---|---|---|---|
| 1 | Revenue | Income statement | RevenueFromContractWithCustomerExcludingAssessedTax, SalesRevenueNet, Revenues | Is demand growing? |
| 2 | Gross Profit | Income statement | GrossProfit | How much remains after direct costs? |
| 3 | Operating Income | Income statement | OperatingIncomeLoss | Is the core business profitable? |
| 4 | Net Income | Income statement | NetIncomeLoss, ProfitLoss | Is the company profitable after all expenses? |
| 5 | Operating Cash Flow | Cash-flow statement | NetCashProvidedByUsedInOperatingActivities | Is the business generating cash? |
| 6 | Capital Expenditures | Cash-flow statement | PaymentsToAcquirePropertyPlantAndEquipment | How aggressively is the company investing? |
| 7 | Cash and Cash Equivalents | Balance sheet | CashAndCashEquivalentsAtCarryingValue | Does the company have liquidity? |
| 8 | Total Debt | Balance sheet | Current and non-current debt concepts | Is leverage increasing? |
| 9 | Diluted EPS | Income statement / EPS disclosure | EarningsPerShareDiluted | What is earnings per diluted share? |
| 10 | Free Cash Flow | Derived metric | Operating Cash Flow minus normalized CapEx | Is growth producing usable cash? |

## Derived analytics

The raw facts above will support these derived outputs:

- gross margin = gross profit / revenue;
- operating margin = operating income / revenue;
- net margin = net income / revenue;
- free-cash-flow margin = free cash flow / revenue;
- revenue year-over-year growth;
- revenue sequential-quarter growth;
- operating-income year-over-year growth;
- free-cash-flow year-over-year growth;
- CapEx intensity = CapEx / revenue;
- cash-to-debt ratio;
- growth acceleration = current growth rate minus prior comparable growth rate.

Derived metrics are outputs, not additional raw facts. They must retain the source fact IDs and calculation version used to produce them.

## Period rules

### Duration facts

Revenue, gross profit, operating income, net income, operating cash flow, CapEx, and free cash flow are measured over a period.

Each fact must retain:

- period_start;
- period_end;
- fiscal_year;
- fiscal_period;
- form_type;
- filed_at;
- unit;
- value;
- accession_number.

### Instantaneous facts

Cash and debt are measured at a point in time, normally the balance-sheet date.

They must not be treated like quarterly flows.

### Quarterly normalization

Many 10-Q filings report year-to-date amounts. The pipeline may need to derive a single quarter by subtracting the previous year-to-date value from the current year-to-date value.

This calculation must be explicit and tested. It must not assume that every SEC fact labeled as a quarter is already a standalone quarter.

## Data-model implications

The planned raw financial layer needs at least:

### financial_reports

One row per filing event.

Planned fields:

- report_id;
- security_id;
- accession_number;
- form_type;
- filing_date;
- period_end;
- fiscal_year;
- fiscal_period;
- source_url.

### financial_facts

One row per reported XBRL fact or normalized fact observation.

The first DDL implementation is in `sql/03_create_financial_facts.sql`.
Its fields are:

- fact_id;
- report_id;
- canonical_metric;
- taxonomy;
- concept;
- value;
- unit;
- observation_type (`INSTANT` or `DURATION`);
- period_start;
- period_end;
- filed_at;
- source_fact_hash.

`security_id` is intentionally reached through `report_id` and
`financial_reports.security_id` instead of being duplicated in this first
normalized table. This avoids storing two independent security relationships
that could disagree. A later performance optimization may denormalize this
key only if a consistency constraint is added.

### financial_metric_mappings

A controlled mapping from issuer-specific or XBRL concepts to canonical metrics.

This table is necessary because companies may use different concepts for similar business measures. Total debt, revenue, and free cash flow especially require documented mapping rules.

## SQL learning outcomes

This module will provide real practice with:

- CTEs for period normalization;
- LAG for year-over-year and sequential-quarter changes;
- ROW_NUMBER for selecting the latest fact available as of a given date;
- CASE WHEN for sign normalization and status classification;
- COALESCE for alternative XBRL concepts;
- conditional aggregation for statement sections;
- date joins using filing date and period end;
- data-quality queries for duplicate, missing, and inconsistent facts;
- materialized views for quarterly company summaries.

## Required data-quality checks

Before using a metric in research output, the pipeline should check:

1. value unit is compatible with the metric;
2. duration facts have valid start and end dates;
3. instant facts are not treated as duration facts;
4. one filing is not duplicated by accession number;
5. revenue is not zero when calculating margins;
6. CapEx sign convention is normalized;
7. total debt components are documented;
8. quarterly derived values reconcile with annual totals where possible;
9. filing date is not replaced by fiscal period end;
10. source URL and accession number are present.

## Research output

The first usable output should compare a small set of companies across several quarters:

- revenue and growth;
- operating margin;
- free cash flow and margin;
- CapEx intensity;
- cash and debt;
- filing date;
- price performance after the filing date.

The output is a research aid. It is not a buy, sell, or return guarantee.

## Status boundary

The fork now contains DDL for `financial_reports` and `financial_facts`, plus a
reproducible seed for one manually verified NVIDIA filing. The original
upstream repository does not contain these additions. SEC XBRL ingestion,
financial metric mappings, financial-fact seed data, quarterly normalization,
and financial analytics views are not implemented or runtime-verified yet.
