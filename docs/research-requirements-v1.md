# Personal Research Requirements v1

Status: design only. This document defines the first research outputs and schema boundary. No production analytics implementation has been added yet.

## Project purpose

Extend the forked `lokhiufung/trading-data` repository into a SQL-first research database for:

- AI infrastructure market research;
- benchmark-relative performance analysis;
- overheat monitoring;
- later personal portfolio risk analysis.

The system provides research prioritization, not deterministic buy or sell signals.

## Five personal research questions

### 1. Which AI infrastructure securities are strengthening?

The system should calculate:

- 20-day, 60-day, 120-day, and one-year returns;
- excess return relative to QQQ and SOXX;
- ranking within an industry theme;
- ranking across themes.

Primary SQL topics:

- joins;
- CTEs;
- LAG;
- rolling calculations;
- RANK and ROW_NUMBER.

### 2. Is the strength becoming overheated?

The system should calculate:

- distance from the 20-day, 50-day, and 200-day moving averages;
- distance from the 52-week high;
- rolling volatility;
- abnormal volume;
- maximum drawdown;
- consecutive positive-return days.

The output should be a research status such as NORMAL, WARM, OVERHEATED, or SEVERELY_OVERHEATED.

Primary SQL topics:

- CASE WHEN;
- window functions;
- rolling windows;
- aggregate functions.

### 3. Is price strength supported by reported fundamentals?

A later module should compare price performance with:

- revenue growth;
- operating income and margin;
- free cash flow;
- cash, debt, and CapEx;
- sequential and year-over-year changes.

The join must use the actual filing or publication date, not only the fiscal period end date, to reduce look-ahead bias.

This module is planned and has not been implemented or verified.

### 4. Is the personal portfolio too concentrated?

A later module should calculate:

- security weights;
- theme and sector weights;
- realized and unrealized P&L;
- contribution to return and drawdown;
- exposure relative to QQQ and VOO;
- risk-limit breaches.

This module is planned and has not been implemented or verified.

### 5. Which securities deserve research priority?

The system should combine:

- relative strength;
- overheat status;
- fundamental confirmation;
- valuation or expectation fields when available;
- current personal exposure;
- data-quality warnings.

The result is an explainable research queue. It must not be presented as an automatic trading signal.

## First schema boundary

The first normalized schema group contains five tables:

### securities

Business purpose: one master record for each stock, ETF, index, or other tracked security.

Planned fields include:

- security_id;
- ticker;
- security_name;
- security_type;
- exchange;
- currency;
- is_active.

Important constraints:

- primary key on security_id;
- unique ticker within the appropriate identifier scope;
- checks for supported security types and currency values.

### daily_prices

Business purpose: one daily OHLCV observation per security.

Planned fields include:

- security_id;
- price_date;
- open_price;
- high_price;
- low_price;
- close_price;
- adjusted_close;
- volume;
- data_source.

Important constraints:

- composite primary key on security_id and price_date;
- foreign key to securities;
- checks for positive prices and non-negative volume;
- indexes for date-range and security/date queries.

### benchmarks

Business purpose: identify which tracked securities are used as comparison benchmarks.

Initial benchmarks:

- QQQ;
- SOXX;
- VOO.

A benchmark should reference the existing security record rather than duplicate price data.

### industry_themes

Business purpose: define controlled research themes such as:

- GPU and ASIC;
- HBM and storage;
- advanced packaging;
- optical networking;
- power and grid;
- cooling and data-center equipment;
- cloud infrastructure.

### theme_members

Business purpose: connect securities to themes.

A security may belong to multiple themes, so theme membership must not be stored as one text field in securities.

Planned fields include:

- theme_id;
- security_id;
- effective_from;
- effective_to;
- membership_source.

Important constraints:

- foreign keys to industry_themes and securities;
- uniqueness for an active membership period;
- checks that effective_to is after effective_from.

## Relationship summary

- One security has many daily price records.
- One security may be assigned as a benchmark.
- Securities and themes have a many-to-many relationship through theme_members.
- QQQ, SOXX, and VOO are stored once in securities and reused through benchmarks.

## Acceptance criteria for the next implementation step

Before adding research SQL, the repository must document:

1. the key and foreign-key design;
2. the expected uniqueness rules;
3. the required price-quality checks;
4. the initial 20–30-security research universe;
5. the manually reviewed theme membership list.

This document is a project design artifact, not evidence that the tables already exist.
