-- AI Infrastructure Investment Research & Portfolio Analytics Database
-- One-pass browser validation script for the financial-statement module.
-- This file is generated from the numbered SQL files in this repository.
-- Run it as one PostgreSQL script in db<>fiddle PostgreSQL 16.

-- ============================================================================
-- BEGIN sql/01_create_financial_reports.sql
-- ============================================================================
-- AI Infrastructure Investment Research & Portfolio Analytics Database
-- New SQL layer in the yuze4/trading-data fork.
-- The upstream repository does not contain these tables.

BEGIN;

-- One row identifies a stock or ETF used by the research database.
CREATE TABLE IF NOT EXISTS securities (
    security_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ticker VARCHAR(12) NOT NULL,
    security_name TEXT NOT NULL,
    asset_type VARCHAR(10) NOT NULL,
    exchange VARCHAR(20),
    cik VARCHAR(10),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_securities_ticker UNIQUE (ticker),
    CONSTRAINT uq_securities_cik UNIQUE (cik),
    CONSTRAINT chk_securities_asset_type
        CHECK (asset_type IN ('STOCK', 'ETF')),
    CONSTRAINT chk_securities_cik
        CHECK (cik IS NULL OR cik ~ '^[0-9]{10}$')
);

-- One row represents one SEC financial-statement filing event.
CREATE TABLE IF NOT EXISTS financial_reports (
    report_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    security_id BIGINT NOT NULL,
    accession_number VARCHAR(25) NOT NULL,
    form_type VARCHAR(10) NOT NULL,
    filing_date DATE NOT NULL,
    period_end DATE NOT NULL,
    fiscal_year INTEGER NOT NULL,
    fiscal_period VARCHAR(4) NOT NULL,
    source_url TEXT NOT NULL,
    is_amended BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_financial_reports_security
        FOREIGN KEY (security_id)
        REFERENCES securities (security_id),
    CONSTRAINT uq_financial_reports_accession
        UNIQUE (accession_number),
    CONSTRAINT chk_financial_reports_form_type
        CHECK (form_type IN ('10-K', '10-Q')),
    CONSTRAINT chk_financial_reports_fiscal_period
        CHECK (fiscal_period IN ('FY', 'Q1', 'Q2', 'Q3', 'Q4')),
    CONSTRAINT chk_financial_reports_fiscal_year
        CHECK (fiscal_year BETWEEN 1900 AND 2100),
    CONSTRAINT chk_financial_reports_dates
        CHECK (filing_date >= period_end),
    CONSTRAINT chk_financial_reports_source_url
        CHECK (source_url LIKE 'https://%')
);

-- These indexes support the main research lookup patterns:
-- "show one company's filings by reporting period" and
-- "show one company's filings by the date known to the market".
CREATE INDEX IF NOT EXISTS idx_financial_reports_security_period
    ON financial_reports (security_id, period_end DESC);

CREATE INDEX IF NOT EXISTS idx_financial_reports_security_filing_date
    ON financial_reports (security_id, filing_date DESC);

COMMIT;

-- ============================================================================
-- END sql/01_create_financial_reports.sql
-- ============================================================================

-- ============================================================================
-- BEGIN sql/03_create_financial_facts.sql
-- ============================================================================
-- AI Infrastructure Investment Research & Portfolio Analytics Database
-- New normalized financial-facts layer in the yuze4/trading-data fork.
-- The upstream repository does not contain this table.

BEGIN;

-- One row stores one reported or normalized financial-statement observation.
-- The security is reached through financial_reports.report_id so the
-- relationship is normalized instead of duplicating security_id here.
CREATE TABLE IF NOT EXISTS financial_facts (
    fact_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    report_id BIGINT NOT NULL,
    canonical_metric VARCHAR(40) NOT NULL,
    taxonomy VARCHAR(30) NOT NULL,
    concept TEXT NOT NULL,
    value NUMERIC(30, 6) NOT NULL,
    unit VARCHAR(30) NOT NULL,
    observation_type VARCHAR(10) NOT NULL,
    period_start DATE,
    period_end DATE NOT NULL,
    filed_at DATE NOT NULL,
    source_fact_hash VARCHAR(64) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_financial_facts_report
        FOREIGN KEY (report_id)
        REFERENCES financial_reports (report_id),
    CONSTRAINT uq_financial_facts_source_hash
        UNIQUE (source_fact_hash),
    CONSTRAINT chk_financial_facts_metric
        CHECK (canonical_metric IN (
            'REVENUE',
            'GROSS_PROFIT',
            'OPERATING_INCOME',
            'NET_INCOME',
            'OPERATING_CASH_FLOW',
            'CAPEX',
            'CASH_AND_EQUIVALENTS',
            'TOTAL_DEBT',
            'DILUTED_EPS'
        )),
    CONSTRAINT chk_financial_facts_observation_type
        CHECK (observation_type IN ('INSTANT', 'DURATION')),
    CONSTRAINT chk_financial_facts_periods
        CHECK (
            (
                observation_type = 'INSTANT'
                AND period_start IS NULL
            )
            OR
            (
                observation_type = 'DURATION'
                AND period_start IS NOT NULL
                AND period_start < period_end
            )
        ),
    CONSTRAINT chk_financial_facts_filed_at
        CHECK (filed_at >= period_end),
    CONSTRAINT chk_financial_facts_source_hash
        CHECK (source_fact_hash ~ '^[0-9a-fA-F]{64}$')
);

-- Main access paths for company filing analysis and point-in-time checks.
CREATE INDEX IF NOT EXISTS idx_financial_facts_report_metric
    ON financial_facts (report_id, canonical_metric, period_end);

CREATE INDEX IF NOT EXISTS idx_financial_facts_metric_period
    ON financial_facts (canonical_metric, period_end);

CREATE INDEX IF NOT EXISTS idx_financial_facts_filed_at
    ON financial_facts (filed_at);

COMMIT;

-- ============================================================================
-- END sql/03_create_financial_facts.sql
-- ============================================================================

-- ============================================================================
-- BEGIN sql/02_seed_nvidia_filing.sql
-- ============================================================================
-- AI Infrastructure Investment Research & Portfolio Analytics Database
-- New seed data in the yuze4/trading-data fork.
--
-- This file loads one manually verified NVIDIA filing metadata record.
-- It is a reproducible seed, not the production SEC ingestion pipeline.

BEGIN;

-- Insert the issuer once, or refresh its descriptive fields when rerun.
WITH nvda AS (
    INSERT INTO securities (
        ticker,
        security_name,
        asset_type,
        exchange,
        cik
    )
    VALUES (
        'NVDA',
        'NVIDIA Corporation',
        'STOCK',
        'NASDAQ',
        '0001045810'
    )
    ON CONFLICT (ticker) DO UPDATE
    SET security_name = EXCLUDED.security_name,
        asset_type = EXCLUDED.asset_type,
        exchange = EXCLUDED.exchange,
        cik = EXCLUDED.cik,
        is_active = TRUE
    RETURNING security_id
)
INSERT INTO financial_reports (
    security_id,
    accession_number,
    form_type,
    filing_date,
    period_end,
    fiscal_year,
    fiscal_period,
    source_url
)
SELECT
    security_id,
    '000104581026000052',
    '10-Q',
    DATE '2026-05-20',
    DATE '2026-04-26',
    2027,
    'Q1',
    'https://www.sec.gov/Archives/edgar/data/1045810/000104581026000052/nvda-20260426.htm'
FROM nvda
ON CONFLICT (accession_number) DO UPDATE
SET security_id = EXCLUDED.security_id,
    form_type = EXCLUDED.form_type,
    filing_date = EXCLUDED.filing_date,
    period_end = EXCLUDED.period_end,
    fiscal_year = EXCLUDED.fiscal_year,
    fiscal_period = EXCLUDED.fiscal_period,
    source_url = EXCLUDED.source_url,
    is_amended = EXCLUDED.is_amended;

COMMIT;

-- Verify the relationship between the issuer and its filing.
SELECT
    s.ticker,
    s.security_name,
    r.accession_number,
    r.form_type,
    r.filing_date,
    r.period_end,
    r.fiscal_year,
    r.fiscal_period
FROM securities AS s
INNER JOIN financial_reports AS r
    ON r.security_id = s.security_id
WHERE s.ticker = 'NVDA'
ORDER BY r.period_end;

-- ============================================================================
-- END sql/02_seed_nvidia_filing.sql
-- ============================================================================

-- ============================================================================
-- BEGIN sql/04_seed_nvidia_financial_facts.sql
-- ============================================================================
-- AI Infrastructure Investment Research & Portfolio Analytics Database
-- New manual pilot data in the yuze4/trading-data fork.
-- The upstream repository does not contain this financial-facts seed.
--
-- Source: NVIDIA Form 10-Q, accession 000104581026000052.
-- The source filing reports USD millions, except per-share data.
-- This is a controlled seed for learning and validation, not the production
-- SEC/XBRL ingestion pipeline.
--
-- UNVERIFIED BOUNDARY: 2026-01-26 is the working period_start used for this
-- pilot, inferred from the fiscal-calendar context. The production pipeline
-- must confirm period_start from the filing's XBRL context before using it.

BEGIN;

-- Fail early if the metadata seed has not been loaded. This prevents facts
-- from being attached to an arbitrary report_id or silently inserting zero rows.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM financial_reports AS r
        JOIN securities AS s
          ON s.security_id = r.security_id
        WHERE s.ticker = 'NVDA'
          AND r.accession_number = '000104581026000052'
    ) THEN
        RAISE EXCEPTION
            'Required NVIDIA filing metadata is missing. Run sql/02_seed_nvidia_filing.sql first.';
    END IF;
END
$$;

-- One row represents one reported observation for the selected filing.
-- CAPEX is stored as a positive outflow magnitude so that FCF can be written
-- as operating cash flow - CAPEX in the later analytical layer.
WITH target_report AS (
    SELECT r.report_id
    FROM financial_reports AS r
    JOIN securities AS s
      ON s.security_id = r.security_id
    WHERE s.ticker = 'NVDA'
      AND r.accession_number = '000104581026000052'
),
seed_facts (
    canonical_metric,
    taxonomy,
    concept,
    value,
    unit,
    observation_type,
    period_start,
    period_end,
    filed_at,
    source_fact_hash
) AS (
    VALUES
        (
            'REVENUE',
            'manual_seed_v1',
            'Income statement: Revenue',
            81615.000000,
            'USD_MILLIONS',
            'DURATION',
            DATE '2026-01-26',
            DATE '2026-04-26',
            DATE '2026-05-20',
            'bfea59b642e446e1a9b3805277d9c9982f53c428a8c9f0bf6742ea5e78be58e7'
        ),
        (
            'GROSS_PROFIT',
            'manual_seed_v1',
            'Income statement: Gross profit',
            61157.000000,
            'USD_MILLIONS',
            'DURATION',
            DATE '2026-01-26',
            DATE '2026-04-26',
            DATE '2026-05-20',
            '7eed74e689b6dbeb27bb717b0dbcda13cae8b64e2dde7af8fbffe219cdbba64b'
        ),
        (
            'OPERATING_INCOME',
            'manual_seed_v1',
            'Income statement: Operating income',
            53536.000000,
            'USD_MILLIONS',
            'DURATION',
            DATE '2026-01-26',
            DATE '2026-04-26',
            DATE '2026-05-20',
            'e8f08b490acd83eabd787fbddc1e244b97c4847f6847d30369cd2f27e340eee8'
        ),
        (
            'NET_INCOME',
            'manual_seed_v1',
            'Income statement: Net income',
            58321.000000,
            'USD_MILLIONS',
            'DURATION',
            DATE '2026-01-26',
            DATE '2026-04-26',
            DATE '2026-05-20',
            'f64c4b1f22497aa0d08e715549c9ed2f7d1ef7927442a0baf41e344e1b6dfeee'
        ),
        (
            'OPERATING_CASH_FLOW',
            'manual_seed_v1',
            'Cash-flow statement: Net cash provided by operating activities',
            50344.000000,
            'USD_MILLIONS',
            'DURATION',
            DATE '2026-01-26',
            DATE '2026-04-26',
            DATE '2026-05-20',
            'fea2c8f911b2cd9ab25fa01be0bc88dea04598e5ac84480068f7da94793df997'
        ),
        (
            'CAPEX',
            'manual_seed_v1',
            'Cash-flow statement: Purchases related to property and equipment and intangible assets',
            1757.000000,
            'USD_MILLIONS',
            'DURATION',
            DATE '2026-01-26',
            DATE '2026-04-26',
            DATE '2026-05-20',
            '4ec2e135e3cbf276f674baf3ccf07e4d1bf74f5b331d3dc50ba8f45fc009606b'
        ),
        (
            'CASH_AND_EQUIVALENTS',
            'manual_seed_v1',
            'Balance sheet: Cash and cash equivalents',
            13237.000000,
            'USD_MILLIONS',
            'INSTANT',
            NULL,
            DATE '2026-04-26',
            DATE '2026-05-20',
            'a54f5ba26c0724a4a65f1eca0da865a28a4972c0c67b46600270ebc837d19516'
        ),
        (
            'TOTAL_DEBT',
            'manual_seed_v1',
            'Balance sheet: Debt net carrying amount',
            8470.000000,
            'USD_MILLIONS',
            'INSTANT',
            NULL,
            DATE '2026-04-26',
            DATE '2026-05-20',
            '6abf3ae3f615bc50746bd9c4d4ca68e7236e853557fb702e6c95e42028244660'
        ),
        (
            'DILUTED_EPS',
            'manual_seed_v1',
            'Income statement: Net income per diluted share',
            2.390000,
            'USD_PER_SHARE',
            'DURATION',
            DATE '2026-01-26',
            DATE '2026-04-26',
            DATE '2026-05-20',
            'f639e4b1eeb8850a22928bee534a0cc74ffc27b686f8b1009615ec45c84c93be'
        )
)
INSERT INTO financial_facts (
    report_id,
    canonical_metric,
    taxonomy,
    concept,
    value,
    unit,
    observation_type,
    period_start,
    period_end,
    filed_at,
    source_fact_hash
)
SELECT
    tr.report_id,
    sf.canonical_metric,
    sf.taxonomy,
    sf.concept,
    sf.value,
    sf.unit,
    sf.observation_type,
    sf.period_start,
    sf.period_end,
    sf.filed_at,
    sf.source_fact_hash
FROM target_report AS tr
CROSS JOIN seed_facts AS sf
ON CONFLICT (source_fact_hash) DO UPDATE
SET report_id = EXCLUDED.report_id,
    canonical_metric = EXCLUDED.canonical_metric,
    taxonomy = EXCLUDED.taxonomy,
    concept = EXCLUDED.concept,
    value = EXCLUDED.value,
    unit = EXCLUDED.unit,
    observation_type = EXCLUDED.observation_type,
    period_start = EXCLUDED.period_start,
    period_end = EXCLUDED.period_end,
    filed_at = EXCLUDED.filed_at;

COMMIT;

-- Verification 1: exactly nine current-period facts should be visible.
SELECT
    s.ticker,
    r.accession_number,
    f.canonical_metric,
    f.value,
    f.unit,
    f.observation_type,
    f.period_start,
    f.period_end,
    f.filed_at
FROM financial_facts AS f
JOIN financial_reports AS r
  ON r.report_id = f.report_id
JOIN securities AS s
  ON s.security_id = r.security_id
WHERE s.ticker = 'NVDA'
  AND r.accession_number = '000104581026000052'
ORDER BY f.canonical_metric;

-- Verification 2: first research calculation, using a CTE and conditional
-- aggregation. Free cash flow is derived, so it is not stored as a raw fact.
WITH nvda_facts AS (
    SELECT
        MAX(value) FILTER (WHERE canonical_metric = 'REVENUE') AS revenue,
        MAX(value) FILTER (WHERE canonical_metric = 'GROSS_PROFIT') AS gross_profit,
        MAX(value) FILTER (WHERE canonical_metric = 'OPERATING_INCOME') AS operating_income,
        MAX(value) FILTER (WHERE canonical_metric = 'OPERATING_CASH_FLOW') AS operating_cash_flow,
        MAX(value) FILTER (WHERE canonical_metric = 'CAPEX') AS capex
    FROM financial_facts AS f
    JOIN financial_reports AS r
      ON r.report_id = f.report_id
    JOIN securities AS s
      ON s.security_id = r.security_id
    WHERE s.ticker = 'NVDA'
      AND r.accession_number = '000104581026000052'
)
SELECT
    revenue,
    gross_profit,
    ROUND(100 * gross_profit / NULLIF(revenue, 0), 2) AS gross_margin_pct,
    operating_income,
    ROUND(100 * operating_income / NULLIF(revenue, 0), 2) AS operating_margin_pct,
    operating_cash_flow,
    capex,
    operating_cash_flow - capex AS free_cash_flow
FROM nvda_facts;

-- ============================================================================
-- END sql/04_seed_nvidia_financial_facts.sql
-- ============================================================================

+-- ============================================================================
-- BEGIN sql/10_seed_nvidia_historical_quarters.sql
-- ============================================================================
-- AI Infrastructure Investment Research & Portfolio Analytics Database
-- Historical NVIDIA quarterly expansion in the yuze4/trading-data fork.
-- The upstream repository does not contain this financial-statement seed.
--
-- Official SEC sources used for the filing metadata and facts:
-- Q1 FY26 10-Q: https://www.sec.gov/Archives/edgar/data/1045810/000104581025000116/nvda-20250427.htm
-- Q2 FY26 10-Q: https://www.sec.gov/Archives/edgar/data/1045810/000104581025000209/nvda-20250727.htm
-- Q3 FY26 10-Q: https://www.sec.gov/Archives/edgar/data/1045810/000104581025000230/nvda-20251026.htm
-- Q4 FY26 10-K: https://www.sec.gov/Archives/edgar/data/1045810/000104581026000021/nvda-20260125.htm
-- Q4 FY26 earnings release: https://www.sec.gov/Archives/edgar/data/1045810/000104581026000019/q4fy26pr.htm
--
-- Important provenance note:
-- * Income-statement, balance-sheet, and Q1 cash-flow values are reported in
--   the cited SEC filings.
-- * Q2 and Q3 quarter-only operating cash flow and CapEx are derived by
--   subtracting the previous cumulative cash-flow period from the current
--   cumulative period.
-- * Q4 quarter-only income and cash-flow values are derived from FY26 annual
--   values less the first nine months; Q4 EPS and the quarter summary are
--   cross-checked against the SEC earnings release.
-- * The period_start dates are working boundaries derived from consecutive
--   NVIDIA fiscal quarter ends. Production ingestion must read and validate
--   the exact XBRL context instead of relying on this seed.
--
-- This is a controlled historical seed for SQL learning and validation, not
-- the production SEC/XBRL ingestion pipeline.

BEGIN;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM securities
        WHERE ticker = 'NVDA'
    ) THEN
        RAISE EXCEPTION
            'Required NVIDIA security is missing. Run sql/02_seed_nvidia_filing.sql first.';
    END IF;
END
$$;

-- Add four prior fiscal quarters. Q4 is represented by the 10-K filing while
-- fiscal_period remains Q4 because the facts below are quarter-only values.
WITH nvda AS (
    SELECT security_id
    FROM securities
    WHERE ticker = 'NVDA'
), historical_reports (
    accession_number,
    form_type,
    filing_date,
    period_end,
    fiscal_year,
    fiscal_period,
    source_url
) AS (
    VALUES
        (
            '000104581025000116',
            '10-Q',
            DATE '2025-05-28',
            DATE '2025-04-27',
            2026,
            'Q1',
            'https://www.sec.gov/Archives/edgar/data/1045810/000104581025000116/nvda-20250427.htm'
        ),
        (
            '000104581025000209',
            '10-Q',
            DATE '2025-08-27',
            DATE '2025-07-27',
            2026,
            'Q2',
            'https://www.sec.gov/Archives/edgar/data/1045810/000104581025000209/nvda-20250727.htm'
        ),
        (
            '000104581025000230',
            '10-Q',
            DATE '2025-11-19',
            DATE '2025-10-26',
            2026,
            'Q3',
            'https://www.sec.gov/Archives/edgar/data/1045810/000104581025000230/nvda-20251026.htm'
        ),
        (
            '000104581026000021',
            '10-K',
            DATE '2026-02-25',
            DATE '2026-01-25',
            2026,
            'Q4',
            'https://www.sec.gov/Archives/edgar/data/1045810/000104581026000021/nvda-20260125.htm'
        )
)
INSERT INTO financial_reports (
    security_id,
    accession_number,
    form_type,
    filing_date,
    period_end,
    fiscal_year,
    fiscal_period,
    source_url
)
SELECT
    n.security_id,
    h.accession_number,
    h.form_type,
    h.filing_date,
    h.period_end,
    h.fiscal_year,
    h.fiscal_period,
    h.source_url
FROM nvda AS n
CROSS JOIN historical_reports AS h
ON CONFLICT (accession_number) DO UPDATE
SET security_id = EXCLUDED.security_id,
    form_type = EXCLUDED.form_type,
    filing_date = EXCLUDED.filing_date,
    period_end = EXCLUDED.period_end,
    fiscal_year = EXCLUDED.fiscal_year,
    fiscal_period = EXCLUDED.fiscal_period,
    source_url = EXCLUDED.source_url,
    is_amended = EXCLUDED.is_amended;

-- The facts use the same nine canonical metrics as the current pilot. The
-- hashes are deterministic row identifiers for this reproducible seed.
WITH seed_facts (
    accession_number,
    canonical_metric,
    taxonomy,
    concept,
    value,
    unit,
    observation_type,
    period_start,
    period_end,
    filed_at,
    source_fact_hash
) AS (
    VALUES
        -- Q1 FY26: 2025-04-27
        (
            '000104581025000116', 'REVENUE', 'manual_seed_v1',
            'Income statement: Revenue', 44062.000000, 'USD_MILLIONS',
            'DURATION', DATE '2025-01-27', DATE '2025-04-27', DATE '2025-05-28',
            'a9eaee3c23c2d154d0287b8980c4dec16e17073018939d5917188af00c55f9b6'
        ),
        (
            '000104581025000116', 'GROSS_PROFIT', 'manual_seed_v1',
            'Income statement: Gross profit', 26668.000000, 'USD_MILLIONS',
            'DURATION', DATE '2025-01-27', DATE '2025-04-27', DATE '2025-05-28',
            '848a9995b3c6432bd5869f27173f37ead3bb324a0adf9497602d5857daacd618'
        ),
        (
            '000104581025000116', 'OPERATING_INCOME', 'manual_seed_v1',
            'Income statement: Operating income', 21638.000000, 'USD_MILLIONS',
            'DURATION', DATE '2025-01-27', DATE '2025-04-27', DATE '2025-05-28',
            '4d126873f5a8bed7e63979800a43fbc2eb499779e44622d752f5b4481d3e0fd2'
        ),
        (
            '000104581025000116', 'NET_INCOME', 'manual_seed_v1',
            'Income statement: Net income', 18775.000000, 'USD_MILLIONS',
            'DURATION', DATE '2025-01-27', DATE '2025-04-27', DATE '2025-05-28',
            '9b0d753d3e786cd743358d50bddae13cf9bac5c0dd3ae833813f1b6834f72d3a'
        ),
        (
            '000104581025000116', 'OPERATING_CASH_FLOW', 'manual_seed_v1',
            'Cash-flow statement: Net cash provided by operating activities',
            27414.000000, 'USD_MILLIONS', 'DURATION',
            DATE '2025-01-27', DATE '2025-04-27', DATE '2025-05-28',
            '5d26103e8433b73426c03d35a675860b4815dac72b2a234c32cffe13f4490348'
        ),
        (
            '000104581025000116', 'CAPEX', 'manual_seed_v1',
            'Cash-flow statement: Purchases related to property and equipment and intangible assets',
            1227.000000, 'USD_MILLIONS', 'DURATION',
            DATE '2025-01-27', DATE '2025-04-27', DATE '2025-05-28',
            '745b0751564198d65cdb44850eea61fc6a66caa43c8eea389ef87d277c1b0d73'
        ),
        (
            '000104581025000116', 'CASH_AND_EQUIVALENTS', 'manual_seed_v1',
            'Balance sheet: Cash and cash equivalents', 15234.000000,
            'USD_MILLIONS', 'INSTANT', NULL, DATE '2025-04-27', DATE '2025-05-28',
            '2537b22073512ef671accd9818393c4e74ba06635c19670b83d9c9c2504c864f'
        ),
        (
            '000104581025000116', 'TOTAL_DEBT', 'manual_seed_v1',
            'Balance sheet: Debt net carrying amount', 8464.000000,
            'USD_MILLIONS', 'INSTANT', NULL, DATE '2025-04-27', DATE '2025-05-28',
            '5d4baebdafecb2d4702606df2876ab07552128432a7932d079967541d2755720'
        ),
        (
            '000104581025000116', 'DILUTED_EPS', 'manual_seed_v1',
            'Income statement: Net income per diluted share', 0.760000,
            'USD_PER_SHARE', 'DURATION', DATE '2025-01-27', DATE '2025-04-27', DATE '2025-05-28',
            '5bfa437e6793c8e602aa6b0ff71bc73c9647ea5bfe23a05863ecd32a367a1b31'
        ),

        -- Q2 FY26: 2025-07-27. OCF and CapEx are six-month cumulative
        -- values less the Q1 values.
        (
            '000104581025000209', 'REVENUE', 'manual_seed_v1',
            'Income statement: Revenue', 46743.000000, 'USD_MILLIONS',
            'DURATION', DATE '2025-04-28', DATE '2025-07-27', DATE '2025-08-27',
            '03e651f7e17f65973a61a8b67e3a4f903766967d0dc31e3c648fc936180773ec'
        ),
        (
            '000104581025000209', 'GROSS_PROFIT', 'manual_seed_v1',
            'Income statement: Gross profit', 33853.000000, 'USD_MILLIONS',
            'DURATION', DATE '2025-04-28', DATE '2025-07-27', DATE '2025-08-27',
            '3fc1f47f2b80567da1a4634e0eac76cb7e7502bd8f51159be21b4235b41963f5'
        ),
        (
            '000104581025000209', 'OPERATING_INCOME', 'manual_seed_v1',
            'Income statement: Operating income', 28440.000000, 'USD_MILLIONS',
            'DURATION', DATE '2025-04-28', DATE '2025-07-27', DATE '2025-08-27',
            'f100ed21771cff662d760334a5cf85e73bfe950a1828bf007d9ccc3c51f76574'
        ),
        (
            '000104581025000209', 'NET_INCOME', 'manual_seed_v1',
            'Income statement: Net income', 26422.000000, 'USD_MILLIONS',
            'DURATION', DATE '2025-04-28', DATE '2025-07-27', DATE '2025-08-27',
            'a4909fe3584490fdb684acd380f984f6162cbaed381df80aca6109131d614bd7'
        ),
        (
            '000104581025000209', 'OPERATING_CASH_FLOW', 'manual_seed_v1',
            'Cash-flow statement: Net cash provided by operating activities',
            15365.000000, 'USD_MILLIONS', 'DURATION',
            DATE '2025-04-28', DATE '2025-07-27', DATE '2025-08-27',
            '5b1b205c612026b0ba2ae1c72d9217865452247052577227b2030396910139ea'
        ),
        (
            '000104581025000209', 'CAPEX', 'manual_seed_v1',
            'Cash-flow statement: Purchases related to property and equipment and intangible assets',
            1895.000000, 'USD_MILLIONS', 'DURATION',
            DATE '2025-04-28', DATE '2025-07-27', DATE '2025-08-27',
            '7b4dd9777422711c4b65ed27cd3a4304d3474e43be45dae766547c36f9246383'
        ),
        (
            '000104581025000209', 'CASH_AND_EQUIVALENTS', 'manual_seed_v1',
            'Balance sheet: Cash and cash equivalents', 11639.000000,
            'USD_MILLIONS', 'INSTANT', NULL, DATE '2025-07-27', DATE '2025-08-27',
            '47baa5239af8ccc7aafd40b76acae3c26e82d2fe2d792dd3b1006a7826f8d18f'
        ),
        (
            '000104581025000209', 'TOTAL_DEBT', 'manual_seed_v1',
            'Balance sheet: Debt net carrying amount', 8466.000000,
            'USD_MILLIONS', 'INSTANT', NULL, DATE '2025-07-27', DATE '2025-08-27',
            '37857733083954edec9f86a23be1a380ee6d46ed74705564e21a2551345d2bc7'
        ),
        (
            '000104581025000209', 'DILUTED_EPS', 'manual_seed_v1',
            'Income statement: Net income per diluted share', 1.080000,
            'USD_PER_SHARE', 'DURATION', DATE '2025-04-28', DATE '2025-07-27', DATE '2025-08-27',
            'd30f405ebdf311211c1d685c82fa5af07fa026ee5012a3ff3f7414372c56e9ad'
        ),

        -- Q3 FY26: 2025-10-26. OCF and CapEx are nine-month cumulative
        -- values less the six-month cumulative values.
        (
            '000104581025000230', 'REVENUE', 'manual_seed_v1',
            'Income statement: Revenue', 57006.000000, 'USD_MILLIONS',
            'DURATION', DATE '2025-07-28', DATE '2025-10-26', DATE '2025-11-19',
            '3b89cf6ff9f6f1314b163586e0e7fdb41fc6df06281a2c34c94ca2a86d8ec084'
        ),
        (
            '000104581025000230', 'GROSS_PROFIT', 'manual_seed_v1',
            'Income statement: Gross profit', 41849.000000, 'USD_MILLIONS',
            'DURATION', DATE '2025-07-28', DATE '2025-10-26', DATE '2025-11-19',
            'd4e690236c89c584ba08fde042f879f7ae222bfb0b0c9d39259c1f9d5bd4c6d8'
        ),
        (
            '000104581025000230', 'OPERATING_INCOME', 'manual_seed_v1',
            'Income statement: Operating income', 36010.000000, 'USD_MILLIONS',
            'DURATION', DATE '2025-07-28', DATE '2025-10-26', DATE '2025-11-19',
            'bd659c97c573b42b3ff4e4732614980376e4f4e303fe4147f4a750415760d616'
        ),
        (
            '000104581025000230', 'NET_INCOME', 'manual_seed_v1',
            'Income statement: Net income', 31910.000000, 'USD_MILLIONS',
            'DURATION', DATE '2025-07-28', DATE '2025-10-26', DATE '2025-11-19',
            '5928e3b97c256a4498634274840362a3e80ac2cc7de52fc7760e91ec10351619'
        ),
        (
            '000104581025000230', 'OPERATING_CASH_FLOW', 'manual_seed_v1',
            'Cash-flow statement: Net cash provided by operating activities',
            23751.000000, 'USD_MILLIONS', 'DURATION',
            DATE '2025-07-28', DATE '2025-10-26', DATE '2025-11-19',
            'a78f2f09b15ae66e13f7dcb9b326a69ec5e3dbd735d7a176991fb7525ff0d250'
        ),
        (
            '000104581025000230', 'CAPEX', 'manual_seed_v1',
            'Cash-flow statement: Purchases related to property and equipment and intangible assets',
            1636.000000, 'USD_MILLIONS', 'DURATION',
            DATE '2025-07-28', DATE '2025-10-26', DATE '2025-11-19',
            'b788a7c46f43472615ab5d80c7439530e0d1c67bab815441835d09c096a7bb11'
        ),
        (
            '000104581025000230', 'CASH_AND_EQUIVALENTS', 'manual_seed_v1',
            'Balance sheet: Cash and cash equivalents', 11486.000000,
            'USD_MILLIONS', 'INSTANT', NULL, DATE '2025-10-26', DATE '2025-11-19',
            '6b3aaf802d9912d31b2a33f6fdd6b029301b8bf5bab2b4511ec7b8aa4a867b33'
        ),
        (
            '000104581025000230', 'TOTAL_DEBT', 'manual_seed_v1',
            'Balance sheet: Debt net carrying amount', 8467.000000,
            'USD_MILLIONS', 'INSTANT', NULL, DATE '2025-10-26', DATE '2025-11-19',
            'a28596edca5bab387cf074eafdb24d9a17aec5030b22eef78df028d90bd934e5'
        ),
        (
            '000104581025000230', 'DILUTED_EPS', 'manual_seed_v1',
            'Income statement: Net income per diluted share', 1.300000,
            'USD_PER_SHARE', 'DURATION', DATE '2025-07-28', DATE '2025-10-26', DATE '2025-11-19',
            '0935a4687b505f90c10ec44bd187a72dd749aeb79d5826419243c42153f22e8f'
        ),

        -- Q4 FY26: 2026-01-25. Quarter-only income and cash-flow values
        -- are derived from FY26 annual values less the first nine months.
        (
            '000104581026000021', 'REVENUE', 'manual_seed_v1',
            'Income statement: Revenue', 68127.000000, 'USD_MILLIONS',
            'DURATION', DATE '2025-10-27', DATE '2026-01-25', DATE '2026-02-25',
            'bee37f1a7cf2f4a319b6f4ae6efc51ad77cc5e0071280cb72555156e0abd995f'
        ),
        (
            '000104581026000021', 'GROSS_PROFIT', 'manual_seed_v1',
            'Income statement: Gross profit', 51093.000000, 'USD_MILLIONS',
            'DURATION', DATE '2025-10-27', DATE '2026-01-25', DATE '2026-02-25',
            '88681014d81fd668ddbe025a89f15d8a59c79150b7964035e4ddc657c6317fec'
        ),
        (
            '000104581026000021', 'OPERATING_INCOME', 'manual_seed_v1',
            'Income statement: Operating income', 44299.000000, 'USD_MILLIONS',
            'DURATION', DATE '2025-10-27', DATE '2026-01-25', DATE '2026-02-25',
            'c4d96d2eeb9e9ec64531eb047020875dc1f4d0925d5a53efa6c35ab572234fd5'
        ),
        (
            '000104581026000021', 'NET_INCOME', 'manual_seed_v1',
            'Income statement: Net income', 42960.000000, 'USD_MILLIONS',
            'DURATION', DATE '2025-10-27', DATE '2026-01-25', DATE '2026-02-25',
            'd79792e0d02f145adea403391e82aba0cf9099ea4e7ff2ab76aecb8aba1a455c'
        ),
        (
            '000104581026000021', 'OPERATING_CASH_FLOW', 'manual_seed_v1',
            'Cash-flow statement: Net cash provided by operating activities',
            36188.000000, 'USD_MILLIONS', 'DURATION',
            DATE '2025-10-27', DATE '2026-01-25', DATE '2026-02-25',
            '12a4d8b0e7c7dd95a19b9f5baffc17f9d91c2d682133260df05f53bac5ccc6a1'
        ),
        (
            '000104581026000021', 'CAPEX', 'manual_seed_v1',
            'Cash-flow statement: Purchases related to property and equipment and intangible assets',
            1284.000000, 'USD_MILLIONS', 'DURATION',
            DATE '2025-10-27', DATE '2026-01-25', DATE '2026-02-25',
            '54b727b007e7ca91541c1501c950203da0511524cfffd9ae7c5c9b4c5768bd92'
        ),
        (
            '000104581026000021', 'CASH_AND_EQUIVALENTS', 'manual_seed_v1',
            'Balance sheet: Cash and cash equivalents', 10605.000000,
            'USD_MILLIONS', 'INSTANT', NULL, DATE '2026-01-25', DATE '2026-02-25',
            '4c3f6f9cf8ce76143c8eca35bf2d8cef8a50b28762fe546cec2cf47564b3e6fa'
        ),
        (
            '000104581026000021', 'TOTAL_DEBT', 'manual_seed_v1',
            'Balance sheet: Debt net carrying amount', 8468.000000,
            'USD_MILLIONS', 'INSTANT', NULL, DATE '2026-01-25', DATE '2026-02-25',
            '83926457f491fc1c31b8e3c006ef5e0b06672e904094614be3c139f144e829f9'
        ),
        (
            '000104581026000021', 'DILUTED_EPS', 'manual_seed_v1',
            'Income statement: Net income per diluted share', 1.760000,
            'USD_PER_SHARE', 'DURATION', DATE '2025-10-27', DATE '2026-01-25', DATE '2026-02-25',
            '963029dde5882ba2d17510efd2474847c177a97599919cfbc200796c221686a0'
        )
),
target_reports AS (
    SELECT
        r.report_id,
        r.accession_number
    FROM financial_reports AS r
    JOIN securities AS s
      ON s.security_id = r.security_id
    WHERE s.ticker = 'NVDA'
      AND r.accession_number IN (
          '000104581025000116',
          '000104581025000209',
          '000104581025000230',
          '000104581026000021'
      )
)
INSERT INTO financial_facts (
    report_id,
    canonical_metric,
    taxonomy,
    concept,
    value,
    unit,
    observation_type,
    period_start,
    period_end,
    filed_at,
    source_fact_hash
)
SELECT
    tr.report_id,
    sf.canonical_metric,
    sf.taxonomy,
    sf.concept,
    sf.value,
    sf.unit,
    sf.observation_type,
    sf.period_start,
    sf.period_end,
    sf.filed_at,
    sf.source_fact_hash
FROM target_reports AS tr
JOIN seed_facts AS sf
  ON sf.accession_number = tr.accession_number
ON CONFLICT (source_fact_hash) DO UPDATE
SET report_id = EXCLUDED.report_id,
    canonical_metric = EXCLUDED.canonical_metric,
    taxonomy = EXCLUDED.taxonomy,
    concept = EXCLUDED.concept,
    value = EXCLUDED.value,
    unit = EXCLUDED.unit,
    observation_type = EXCLUDED.observation_type,
    period_start = EXCLUDED.period_start,
    period_end = EXCLUDED.period_end,
    filed_at = EXCLUDED.filed_at;

COMMIT;

-- Verification 1: four historical reports should now be present.
SELECT
    s.ticker,
    r.accession_number,
    r.form_type,
    r.filing_date,
    r.period_end,
    r.fiscal_year,
    r.fiscal_period,
    COUNT(f.fact_id) AS fact_count
FROM financial_reports AS r
JOIN securities AS s
  ON s.security_id = r.security_id
LEFT JOIN financial_facts AS f
  ON f.report_id = r.report_id
WHERE s.ticker = 'NVDA'
  AND r.accession_number IN (
      '000104581025000116',
      '000104581025000209',
      '000104581025000230',
      '000104581026000021'
  )
GROUP BY
    s.ticker,
    r.accession_number,
    r.form_type,
    r.filing_date,
    r.period_end,
    r.fiscal_year,
    r.fiscal_period
ORDER BY r.period_end;

-- Verification 2: every historical report should contain nine facts.
SELECT
    COUNT(*) AS historical_report_count,
    COALESCE(SUM(fact_count), 0) AS historical_fact_count,
    COUNT(*) FILTER (WHERE fact_count = 9) AS complete_historical_report_count
FROM (
    SELECT
        r.report_id,
        COUNT(f.fact_id) AS fact_count
    FROM financial_reports AS r
    JOIN securities AS s
      ON s.security_id = r.security_id
    LEFT JOIN financial_facts AS f
      ON f.report_id = r.report_id
    WHERE s.ticker = 'NVDA'
      AND r.accession_number IN (
          '000104581025000116',
          '000104581025000209',
          '000104581025000230',
          '000104581026000021'
      )
    GROUP BY r.report_id
) AS historical_counts;

-- ============================================================================
-- END sql/10_seed_nvidia_historical_quarters.sql
-- ============================================================================

-- ============================================================================
-- BEGIN sql/05_create_financial_statement_summary_view.sql
-- ============================================================================
-- AI Infrastructure Investment Research & Portfolio Analytics Database
-- New SQL analysis layer in the yuze4/trading-data fork.
-- The upstream repository does not contain this financial-statement view.
--
-- This is a regular VIEW, not a materialized view. It always reads the
-- current financial_facts rows and is appropriate for the browser pilot.

BEGIN;

CREATE OR REPLACE VIEW vw_financial_statement_summary AS
WITH fact_pivot AS (
    -- Convert the row-based facts table into one analytical row per
    -- report and fact period. FILTER is PostgreSQL conditional aggregation.
    SELECT
        f.report_id,
        f.period_end,
        MIN(f.period_start) FILTER (
            WHERE f.observation_type = 'DURATION'
        ) AS period_start,
        MAX(f.filed_at) AS latest_fact_filed_at,
        COUNT(*) AS fact_row_count,
        COUNT(DISTINCT f.canonical_metric) AS distinct_metric_count,
        MAX(f.value) FILTER (
            WHERE f.canonical_metric = 'REVENUE'
        ) AS revenue_usd_millions,
        MAX(f.value) FILTER (
            WHERE f.canonical_metric = 'GROSS_PROFIT'
        ) AS gross_profit_usd_millions,
        MAX(f.value) FILTER (
            WHERE f.canonical_metric = 'OPERATING_INCOME'
        ) AS operating_income_usd_millions,
        MAX(f.value) FILTER (
            WHERE f.canonical_metric = 'NET_INCOME'
        ) AS net_income_usd_millions,
        MAX(f.value) FILTER (
            WHERE f.canonical_metric = 'OPERATING_CASH_FLOW'
        ) AS operating_cash_flow_usd_millions,
        MAX(f.value) FILTER (
            WHERE f.canonical_metric = 'CAPEX'
        ) AS capex_usd_millions,
        MAX(f.value) FILTER (
            WHERE f.canonical_metric = 'CASH_AND_EQUIVALENTS'
        ) AS cash_and_equivalents_usd_millions,
        MAX(f.value) FILTER (
            WHERE f.canonical_metric = 'TOTAL_DEBT'
        ) AS total_debt_usd_millions,
        MAX(f.value) FILTER (
            WHERE f.canonical_metric = 'DILUTED_EPS'
        ) AS diluted_eps_usd
    FROM financial_facts AS f
    GROUP BY
        f.report_id,
        f.period_end
),
calculated AS (
    -- Calculate research ratios only after the raw facts have been pivoted.
    -- NULLIF prevents a zero revenue value from causing a division error.
    SELECT
        s.security_id,
        s.ticker,
        s.security_name,
        r.report_id,
        r.accession_number,
        r.form_type,
        r.filing_date,
        r.period_end AS report_period_end,
        r.fiscal_year,
        r.fiscal_period,
        p.period_start,
        p.period_end AS fact_period_end,
        p.latest_fact_filed_at,
        p.fact_row_count,
        p.distinct_metric_count,
        p.period_end = r.period_end AS period_end_matches_report,
        p.latest_fact_filed_at = r.filing_date AS filing_date_matches_facts,
        p.revenue_usd_millions,
        p.gross_profit_usd_millions,
        ROUND(
            100 * p.gross_profit_usd_millions
            / NULLIF(p.revenue_usd_millions, 0),
            2
        ) AS gross_margin_pct,
        p.operating_income_usd_millions,
        ROUND(
            100 * p.operating_income_usd_millions
            / NULLIF(p.revenue_usd_millions, 0),
            2
        ) AS operating_margin_pct,
        p.net_income_usd_millions,
        ROUND(
            100 * p.net_income_usd_millions
            / NULLIF(p.revenue_usd_millions, 0),
            2
        ) AS net_margin_pct,
        p.operating_cash_flow_usd_millions,
        ROUND(
            100 * p.operating_cash_flow_usd_millions
            / NULLIF(p.revenue_usd_millions, 0),
            2
        ) AS operating_cash_flow_margin_pct,
        p.capex_usd_millions,
        p.operating_cash_flow_usd_millions - p.capex_usd_millions
            AS free_cash_flow_usd_millions,
        ROUND(
            100 * (
                p.operating_cash_flow_usd_millions - p.capex_usd_millions
            ) / NULLIF(p.revenue_usd_millions, 0),
            2
        ) AS free_cash_flow_margin_pct,
        p.cash_and_equivalents_usd_millions,
        p.total_debt_usd_millions,
        ROUND(
            p.cash_and_equivalents_usd_millions
            / NULLIF(p.total_debt_usd_millions, 0),
            2
        ) AS cash_to_debt_ratio,
        p.diluted_eps_usd
    FROM fact_pivot AS p
    JOIN financial_reports AS r
      ON r.report_id = p.report_id
    JOIN securities AS s
      ON s.security_id = r.security_id
)
SELECT
    c.*,
    CASE
        WHEN NOT c.period_end_matches_report THEN 'CHECK_PERIOD'
        WHEN NOT c.filing_date_matches_facts THEN 'CHECK_FILING_DATE'
        WHEN c.fact_row_count <> c.distinct_metric_count
            THEN 'DUPLICATE_METRIC'
        WHEN c.distinct_metric_count < 9
            OR c.revenue_usd_millions IS NULL
            OR c.gross_profit_usd_millions IS NULL
            OR c.operating_income_usd_millions IS NULL
            OR c.net_income_usd_millions IS NULL
            OR c.operating_cash_flow_usd_millions IS NULL
            OR c.capex_usd_millions IS NULL
            OR c.cash_and_equivalents_usd_millions IS NULL
            OR c.total_debt_usd_millions IS NULL
            OR c.diluted_eps_usd IS NULL
            THEN 'INCOMPLETE'
        ELSE 'COMPLETE'
    END AS data_quality_status
FROM calculated AS c;

COMMENT ON VIEW vw_financial_statement_summary IS
    'SQL-derived financial-statement summary; structural completeness only, not investment advice.';

COMMIT;

-- Verification: the NVIDIA pilot should produce one summary row per loaded
-- filing (five rows after the historical seed is included).
SELECT
    ticker,
    fiscal_year,
    fiscal_period,
    filing_date,
    report_period_end,
    revenue_usd_millions,
    gross_margin_pct,
    operating_margin_pct,
    free_cash_flow_usd_millions,
    cash_to_debt_ratio,
    data_quality_status
FROM vw_financial_statement_summary
WHERE ticker = 'NVDA'
ORDER BY report_period_end;

-- ============================================================================
-- END sql/05_create_financial_statement_summary_view.sql
-- ============================================================================

-- ============================================================================
-- BEGIN sql/06_create_financial_metric_mappings.sql
-- ============================================================================
-- AI Infrastructure Investment Research & Portfolio Analytics Database
-- New controlled mapping layer in the yuze4/trading-data fork.
-- The upstream repository does not contain this table.

BEGIN;

-- Issuers may use different source concepts for the same analytical metric.
-- This table keeps that translation explicit instead of hiding it in Python.
CREATE TABLE IF NOT EXISTS financial_metric_mappings (
    mapping_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_system VARCHAR(30) NOT NULL,
    taxonomy VARCHAR(30) NOT NULL,
    concept TEXT NOT NULL,
    canonical_metric VARCHAR(40) NOT NULL,
    expected_unit VARCHAR(30) NOT NULL,
    expected_observation_type VARCHAR(10) NOT NULL,
    value_multiplier NUMERIC(20, 6) NOT NULL DEFAULT 1,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_financial_metric_mapping_source
        UNIQUE (source_system, taxonomy, concept),
    CONSTRAINT uq_financial_metric_mapping_concept_metric
        UNIQUE (taxonomy, concept, canonical_metric),
    CONSTRAINT chk_financial_metric_mapping_metric
        CHECK (canonical_metric IN (
            'REVENUE',
            'GROSS_PROFIT',
            'OPERATING_INCOME',
            'NET_INCOME',
            'OPERATING_CASH_FLOW',
            'CAPEX',
            'CASH_AND_EQUIVALENTS',
            'TOTAL_DEBT',
            'DILUTED_EPS'
        )),
    CONSTRAINT chk_financial_metric_mapping_unit
        CHECK (expected_unit IN ('USD_MILLIONS', 'USD_PER_SHARE')),
    CONSTRAINT chk_financial_metric_mapping_observation
        CHECK (expected_observation_type IN ('INSTANT', 'DURATION')),
    CONSTRAINT chk_financial_metric_mapping_multiplier
        CHECK (value_multiplier <> 0)
);

CREATE INDEX IF NOT EXISTS idx_financial_metric_mappings_lookup
    ON financial_metric_mappings (taxonomy, concept, is_active);

-- These mappings correspond to the manually verified NVIDIA pilot facts.
-- They are deliberately labeled MANUAL_FILING, not SEC_XBRL, because the
-- automatic XBRL concept-ingestion path has not been implemented yet.
INSERT INTO financial_metric_mappings (
    source_system,
    taxonomy,
    concept,
    canonical_metric,
    expected_unit,
    expected_observation_type,
    value_multiplier,
    notes
)
VALUES
    (
        'MANUAL_FILING',
        'manual_seed_v1',
        'Income statement: Revenue',
        'REVENUE',
        'USD_MILLIONS',
        'DURATION',
        1,
        'Three-month revenue from the NVIDIA pilot filing.'
    ),
    (
        'MANUAL_FILING',
        'manual_seed_v1',
        'Income statement: Gross profit',
        'GROSS_PROFIT',
        'USD_MILLIONS',
        'DURATION',
        1,
        'Three-month gross profit from the NVIDIA pilot filing.'
    ),
    (
        'MANUAL_FILING',
        'manual_seed_v1',
        'Income statement: Operating income',
        'OPERATING_INCOME',
        'USD_MILLIONS',
        'DURATION',
        1,
        'Three-month operating income from the NVIDIA pilot filing.'
    ),
    (
        'MANUAL_FILING',
        'manual_seed_v1',
        'Income statement: Net income',
        'NET_INCOME',
        'USD_MILLIONS',
        'DURATION',
        1,
        'Three-month net income from the NVIDIA pilot filing.'
    ),
    (
        'MANUAL_FILING',
        'manual_seed_v1',
        'Cash-flow statement: Net cash provided by operating activities',
        'OPERATING_CASH_FLOW',
        'USD_MILLIONS',
        'DURATION',
        1,
        'Three-month operating cash flow from the NVIDIA pilot filing.'
    ),
    (
        'MANUAL_FILING',
        'manual_seed_v1',
        'Cash-flow statement: Purchases related to property and equipment and intangible assets',
        'CAPEX',
        'USD_MILLIONS',
        'DURATION',
        1,
        'Stored as a positive outflow magnitude for the FCF calculation.'
    ),
    (
        'MANUAL_FILING',
        'manual_seed_v1',
        'Balance sheet: Cash and cash equivalents',
        'CASH_AND_EQUIVALENTS',
        'USD_MILLIONS',
        'INSTANT',
        1,
        'Balance-sheet cash at the filing period end.'
    ),
    (
        'MANUAL_FILING',
        'manual_seed_v1',
        'Balance sheet: Debt net carrying amount',
        'TOTAL_DEBT',
        'USD_MILLIONS',
        'INSTANT',
        1,
        'Debt net carrying amount from short- and long-term debt components.'
    ),
    (
        'MANUAL_FILING',
        'manual_seed_v1',
        'Income statement: Net income per diluted share',
        'DILUTED_EPS',
        'USD_PER_SHARE',
        'DURATION',
        1,
        'Three-month diluted EPS from the NVIDIA pilot filing.'
    )
ON CONFLICT (source_system, taxonomy, concept) DO UPDATE
SET canonical_metric = EXCLUDED.canonical_metric,
    expected_unit = EXCLUDED.expected_unit,
    expected_observation_type = EXCLUDED.expected_observation_type,
    value_multiplier = EXCLUDED.value_multiplier,
    is_active = EXCLUDED.is_active,
    notes = EXCLUDED.notes;

COMMIT;

-- Verification: the pilot should contain nine active mapping rows.
SELECT
    COUNT(*) AS active_mapping_count
FROM financial_metric_mappings
WHERE source_system = 'MANUAL_FILING'
  AND taxonomy = 'manual_seed_v1'
  AND is_active = TRUE;

-- ============================================================================
-- END sql/06_create_financial_metric_mappings.sql
-- ============================================================================

-- ============================================================================
-- BEGIN sql/07_create_financial_growth_view.sql
-- ============================================================================
-- AI Infrastructure Investment Research & Portfolio Analytics Database
-- New quarterly growth analysis layer in the yuze4/trading-data fork.
-- The upstream repository does not contain this view.

BEGIN;

CREATE OR REPLACE VIEW vw_financial_statement_growth AS
WITH ordered_periods AS (
    -- LAG exposes the previous filing period and the fourth prior quarter.
    -- The fourth prior row is only treated as a year-over-year comparison
    -- after the fiscal year and fiscal period are checked below.
    SELECT
        s.*,
        LAG(s.report_period_end, 1) OVER (
            PARTITION BY s.security_id
            ORDER BY s.report_period_end
        ) AS previous_period_end,
        LAG(s.revenue_usd_millions, 1) OVER (
            PARTITION BY s.security_id
            ORDER BY s.report_period_end
        ) AS previous_revenue_usd_millions,
        LAG(s.operating_income_usd_millions, 1) OVER (
            PARTITION BY s.security_id
            ORDER BY s.report_period_end
        ) AS previous_operating_income_usd_millions,
        LAG(s.free_cash_flow_usd_millions, 1) OVER (
            PARTITION BY s.security_id
            ORDER BY s.report_period_end
        ) AS previous_free_cash_flow_usd_millions,
        LAG(s.report_period_end, 4) OVER (
            PARTITION BY s.security_id
            ORDER BY s.report_period_end
        ) AS prior_year_period_end_candidate,
        LAG(s.fiscal_year, 4) OVER (
            PARTITION BY s.security_id
            ORDER BY s.report_period_end
        ) AS prior_year_fiscal_year_candidate,
        LAG(s.fiscal_period, 4) OVER (
            PARTITION BY s.security_id
            ORDER BY s.report_period_end
        ) AS prior_year_fiscal_period_candidate,
        LAG(s.revenue_usd_millions, 4) OVER (
            PARTITION BY s.security_id
            ORDER BY s.report_period_end
        ) AS prior_year_revenue_usd_millions_candidate,
        LAG(s.operating_income_usd_millions, 4) OVER (
            PARTITION BY s.security_id
            ORDER BY s.report_period_end
        ) AS prior_year_operating_income_usd_millions_candidate,
        LAG(s.free_cash_flow_usd_millions, 4) OVER (
            PARTITION BY s.security_id
            ORDER BY s.report_period_end
        ) AS prior_year_free_cash_flow_usd_millions_candidate,
        LAG(s.operating_margin_pct, 4) OVER (
            PARTITION BY s.security_id
            ORDER BY s.report_period_end
        ) AS prior_year_operating_margin_pct_candidate,
        LAG(s.free_cash_flow_margin_pct, 4) OVER (
            PARTITION BY s.security_id
            ORDER BY s.report_period_end
        ) AS prior_year_free_cash_flow_margin_pct_candidate
    FROM vw_financial_statement_summary AS s
),
aligned_periods AS (
    -- Do not call an arbitrary fourth previous row "year over year".
    -- It must have the same fiscal quarter and the immediately prior fiscal
    -- year. This prevents a missing-quarter error from becoming fake growth.
    SELECT
        o.*,
        CASE
            WHEN o.prior_year_fiscal_year_candidate = o.fiscal_year - 1
             AND o.prior_year_fiscal_period_candidate = o.fiscal_period
            THEN o.prior_year_period_end_candidate
        END AS prior_year_period_end,
        CASE
            WHEN o.prior_year_fiscal_year_candidate = o.fiscal_year - 1
             AND o.prior_year_fiscal_period_candidate = o.fiscal_period
            THEN o.prior_year_revenue_usd_millions_candidate
        END AS prior_year_revenue_usd_millions,
        CASE
            WHEN o.prior_year_fiscal_year_candidate = o.fiscal_year - 1
             AND o.prior_year_fiscal_period_candidate = o.fiscal_period
            THEN o.prior_year_operating_income_usd_millions_candidate
        END AS prior_year_operating_income_usd_millions,
        CASE
            WHEN o.prior_year_fiscal_year_candidate = o.fiscal_year - 1
             AND o.prior_year_fiscal_period_candidate = o.fiscal_period
            THEN o.prior_year_free_cash_flow_usd_millions_candidate
        END AS prior_year_free_cash_flow_usd_millions,
        CASE
            WHEN o.prior_year_fiscal_year_candidate = o.fiscal_year - 1
             AND o.prior_year_fiscal_period_candidate = o.fiscal_period
            THEN o.prior_year_operating_margin_pct_candidate
        END AS prior_year_operating_margin_pct,
        CASE
            WHEN o.prior_year_fiscal_year_candidate = o.fiscal_year - 1
             AND o.prior_year_fiscal_period_candidate = o.fiscal_period
            THEN o.prior_year_free_cash_flow_margin_pct_candidate
        END AS prior_year_free_cash_flow_margin_pct
    FROM ordered_periods AS o
),
calculated_growth AS (
    SELECT
        a.*,
        ROUND(
            100 * (
                a.revenue_usd_millions
                / NULLIF(a.previous_revenue_usd_millions, 0) - 1
            ),
            2
        ) AS revenue_sequential_growth_pct,
        ROUND(
            100 * (
                a.revenue_usd_millions
                / NULLIF(a.prior_year_revenue_usd_millions, 0) - 1
            ),
            2
        ) AS revenue_yoy_growth_pct,
        ROUND(
            100 * (
                a.operating_income_usd_millions
                / NULLIF(a.prior_year_operating_income_usd_millions, 0) - 1
            ),
            2
        ) AS operating_income_yoy_growth_pct,
        ROUND(
            100 * (
                a.free_cash_flow_usd_millions
                / NULLIF(a.prior_year_free_cash_flow_usd_millions, 0) - 1
            ),
            2
        ) AS free_cash_flow_yoy_growth_pct,
        ROUND(
            a.operating_margin_pct - a.prior_year_operating_margin_pct,
            2
        ) AS operating_margin_change_pts,
        ROUND(
            a.free_cash_flow_margin_pct
            - a.prior_year_free_cash_flow_margin_pct,
            2
        ) AS free_cash_flow_margin_change_pts
    FROM aligned_periods AS a
),
classified_growth AS (
    SELECT
        c.*,
        CASE
            WHEN c.data_quality_status <> 'COMPLETE'
                THEN 'CHECK_DATA'
            WHEN c.prior_year_period_end IS NULL
                THEN 'NEEDS_MORE_PERIODS'
            ELSE 'READY'
        END AS growth_readiness_status,
        CASE
            WHEN c.prior_year_period_end IS NULL
                THEN 'INSUFFICIENT_HISTORY'
            WHEN c.revenue_yoy_growth_pct > 0
             AND c.operating_income_yoy_growth_pct > 0
             AND c.free_cash_flow_yoy_growth_pct > 0
             AND c.operating_margin_change_pts >= 0
                THEN 'IMPROVING'
            WHEN c.revenue_yoy_growth_pct < 0
             AND c.operating_income_yoy_growth_pct < 0
                THEN 'DETERIORATING'
            ELSE 'MIXED'
        END AS fundamental_direction
    FROM calculated_growth AS c
)
SELECT *
FROM classified_growth;

COMMENT ON VIEW vw_financial_statement_growth IS
    'SQL growth analysis using LAG; research classification is not a buy or sell signal.';

COMMIT;

-- Verification: one NVIDIA row is expected per loaded filing. The current Q1
-- FY27 row can calculate sequential and year-over-year growth after the four
-- historical quarters are included.
SELECT
    ticker,
    fiscal_year,
    fiscal_period,
    revenue_sequential_growth_pct,
    revenue_yoy_growth_pct,
    operating_income_yoy_growth_pct,
    free_cash_flow_yoy_growth_pct,
    growth_readiness_status,
    fundamental_direction
FROM vw_financial_statement_growth
WHERE ticker = 'NVDA'
ORDER BY report_period_end;

-- ============================================================================
-- END sql/07_create_financial_growth_view.sql
-- ============================================================================

-- ============================================================================
-- BEGIN sql/08_create_financial_quality_view.sql
-- ============================================================================
-- AI Infrastructure Investment Research & Portfolio Analytics Database
-- New data-quality analysis layer in the yuze4/trading-data fork.
-- The upstream repository does not contain this view.

BEGIN;

CREATE OR REPLACE VIEW vw_financial_data_quality_issues AS
WITH report_periods AS (
    SELECT
        r.report_id,
        r.security_id,
        s.ticker,
        r.period_end AS report_period_end,
        r.filing_date
    FROM financial_reports AS r
    JOIN securities AS s
      ON s.security_id = r.security_id
),
required_metrics (canonical_metric) AS (
    VALUES
        ('REVENUE'),
        ('GROSS_PROFIT'),
        ('OPERATING_INCOME'),
        ('NET_INCOME'),
        ('OPERATING_CASH_FLOW'),
        ('CAPEX'),
        ('CASH_AND_EQUIVALENTS'),
        ('TOTAL_DEBT'),
        ('DILUTED_EPS')
),
missing_metrics AS (
    SELECT
        rp.ticker,
        rp.report_id,
        rp.report_period_end AS period_end,
        rm.canonical_metric
    FROM report_periods AS rp
    CROSS JOIN required_metrics AS rm
    LEFT JOIN financial_facts AS f
      ON f.report_id = rp.report_id
     AND f.period_end = rp.report_period_end
     AND f.canonical_metric = rm.canonical_metric
    WHERE f.fact_id IS NULL
),
duplicate_metrics AS (
    SELECT
        rp.ticker,
        f.report_id,
        f.period_end,
        f.canonical_metric,
        COUNT(*) AS fact_count
    FROM financial_facts AS f
    JOIN report_periods AS rp
      ON rp.report_id = f.report_id
    GROUP BY
        rp.ticker,
        f.report_id,
        f.period_end,
        f.canonical_metric
    HAVING COUNT(*) > 1
),
unmapped_facts AS (
    SELECT
        s.ticker,
        f.report_id,
        f.period_end,
        f.canonical_metric,
        f.taxonomy,
        f.concept
    FROM financial_facts AS f
    JOIN financial_reports AS r
      ON r.report_id = f.report_id
    JOIN securities AS s
      ON s.security_id = r.security_id
    LEFT JOIN financial_metric_mappings AS m
      ON m.taxonomy = f.taxonomy
     AND m.concept = f.concept
     AND m.canonical_metric = f.canonical_metric
     AND m.is_active = TRUE
    WHERE m.mapping_id IS NULL
),
unit_or_type_mismatches AS (
    SELECT
        s.ticker,
        f.report_id,
        f.period_end,
        f.canonical_metric,
        f.unit,
        f.observation_type,
        m.expected_unit,
        m.expected_observation_type
    FROM financial_facts AS f
    JOIN financial_reports AS r
      ON r.report_id = f.report_id
    JOIN securities AS s
      ON s.security_id = r.security_id
    JOIN financial_metric_mappings AS m
      ON m.taxonomy = f.taxonomy
     AND m.concept = f.concept
     AND m.canonical_metric = f.canonical_metric
     AND m.is_active = TRUE
    WHERE f.unit <> m.expected_unit
       OR f.observation_type <> m.expected_observation_type
),
period_mismatches AS (
    SELECT
        s.ticker,
        f.report_id,
        f.period_end,
        f.canonical_metric,
        r.period_end AS report_period_end
    FROM financial_facts AS f
    JOIN financial_reports AS r
      ON r.report_id = f.report_id
    JOIN securities AS s
      ON s.security_id = r.security_id
    WHERE f.period_end <> r.period_end
),
filing_date_mismatches AS (
    SELECT
        s.ticker,
        f.report_id,
        f.period_end,
        f.canonical_metric,
        f.filed_at,
        r.filing_date
    FROM financial_facts AS f
    JOIN financial_reports AS r
      ON r.report_id = f.report_id
    JOIN securities AS s
      ON s.security_id = r.security_id
    WHERE f.filed_at <> r.filing_date
)
SELECT
    'MISSING_METRIC'::TEXT AS issue_code,
    'ERROR'::TEXT AS severity,
    m.ticker,
    m.report_id,
    m.period_end,
    m.canonical_metric,
    'Required metric is missing for the report period.'::TEXT AS issue_detail
FROM missing_metrics AS m

UNION ALL

SELECT
    'DUPLICATE_METRIC'::TEXT,
    'ERROR'::TEXT,
    d.ticker,
    d.report_id,
    d.period_end,
    d.canonical_metric,
    format('Found %s rows for one canonical metric.', d.fact_count)::TEXT
FROM duplicate_metrics AS d

UNION ALL

SELECT
    'UNMAPPED_CONCEPT'::TEXT,
    'ERROR'::TEXT,
    u.ticker,
    u.report_id,
    u.period_end,
    u.canonical_metric,
    format(
        'No active mapping for taxonomy=%s and concept=%s.',
        u.taxonomy,
        u.concept
    )::TEXT
FROM unmapped_facts AS u

UNION ALL

SELECT
    'UNIT_OR_TYPE_MISMATCH'::TEXT,
    'ERROR'::TEXT,
    u.ticker,
    u.report_id,
    u.period_end,
    u.canonical_metric,
    format(
        'Expected %s/%s but found %s/%s.',
        u.expected_unit,
        u.expected_observation_type,
        u.unit,
        u.observation_type
    )::TEXT
FROM unit_or_type_mismatches AS u

UNION ALL

SELECT
    'PERIOD_REVIEW'::TEXT,
    'WARNING'::TEXT,
    p.ticker,
    p.report_id,
    p.period_end,
    p.canonical_metric,
    format(
        'Fact period end differs from report period end: %s.',
        p.report_period_end
    )::TEXT
FROM period_mismatches AS p

UNION ALL

SELECT
    'FILING_DATE_MISMATCH'::TEXT,
    'WARNING'::TEXT,
    f.ticker,
    f.report_id,
    f.period_end,
    f.canonical_metric,
    format(
        'Fact filed_at=%s differs from report filing_date=%s.',
        f.filed_at,
        f.filing_date
    )::TEXT
FROM filing_date_mismatches AS f;

COMMENT ON VIEW vw_financial_data_quality_issues IS
    'Rows requiring review before financial facts are used in research outputs.';

COMMIT;

-- Verification: the current NVIDIA pilot should have zero quality issues.
SELECT
    COUNT(*) AS quality_issue_count
FROM vw_financial_data_quality_issues;

-- ============================================================================
-- END sql/08_create_financial_quality_view.sql
-- ============================================================================

-- ============================================================================
-- BEGIN sql/09_validate_financial_module.sql
-- ============================================================================
-- AI Infrastructure Investment Research & Portfolio Analytics Database
-- One-pass validation queries for the financial-statement module.
-- Run this file after sql/01 through sql/08 and sql/10 in the same PostgreSQL session.

-- 1. Confirm the module's main objects exist.
SELECT table_name AS object_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN (
      'securities',
      'financial_reports',
      'financial_facts',
      'financial_metric_mappings'
  )
ORDER BY table_name;

SELECT table_name AS view_name
FROM information_schema.views
WHERE table_schema = 'public'
  AND table_name IN (
      'vw_financial_statement_summary',
      'vw_financial_statement_growth',
      'vw_financial_data_quality_issues'
  )
ORDER BY table_name;

-- 2. Confirm the pilot contains one issuer, five filings, and 45 facts in
-- total. The current Q1 FY27 filing should still contain nine facts.
SELECT
    (SELECT COUNT(*) FROM securities WHERE ticker = 'NVDA') AS nvda_security_count,
    (
        SELECT COUNT(*)
        FROM financial_reports AS r
        JOIN securities AS s
          ON s.security_id = r.security_id
        WHERE s.ticker = 'NVDA'
    ) AS nvda_filing_count,
    (
        SELECT COUNT(*)
        FROM financial_facts AS f
        JOIN financial_reports AS r
          ON r.report_id = f.report_id
        JOIN securities AS s
          ON s.security_id = r.security_id
        WHERE s.ticker = 'NVDA'
    ) AS nvda_total_fact_count,
    (
        SELECT COUNT(*)
        FROM financial_reports AS r
        JOIN securities AS s
          ON s.security_id = r.security_id
        WHERE s.ticker = 'NVDA'
          AND r.accession_number = '000104581026000052'
    ) AS nvda_current_report_count,
    (
        SELECT COUNT(*)
        FROM financial_facts AS f
        JOIN financial_reports AS r
          ON r.report_id = f.report_id
        JOIN securities AS s
          ON s.security_id = r.security_id
        WHERE s.ticker = 'NVDA'
          AND r.accession_number = '000104581026000052'
    ) AS nvda_current_fact_count;

-- 3. Human-readable financial summary.
SELECT
    ticker,
    fiscal_year,
    fiscal_period,
    filing_date,
    report_period_end,
    revenue_usd_millions,
    gross_margin_pct,
    operating_margin_pct,
    net_margin_pct,
    operating_cash_flow_usd_millions,
    free_cash_flow_usd_millions,
    free_cash_flow_margin_pct,
    cash_and_equivalents_usd_millions,
    total_debt_usd_millions,
    cash_to_debt_ratio,
    data_quality_status
FROM vw_financial_statement_summary
WHERE ticker = 'NVDA'
ORDER BY report_period_end;

-- 4. Window-function growth output.
-- The first four rows do not have a prior-year comparison. The current Q1 FY27
-- row should have sequential and year-over-year growth after the four historical
-- quarters are loaded.
SELECT
    ticker,
    fiscal_year,
    fiscal_period,
    previous_period_end,
    prior_year_period_end,
    revenue_sequential_growth_pct,
    revenue_yoy_growth_pct,
    operating_income_yoy_growth_pct,
    free_cash_flow_yoy_growth_pct,
    growth_readiness_status,
    fundamental_direction
FROM vw_financial_statement_growth
WHERE ticker = 'NVDA'
ORDER BY report_period_end;

-- 5. Quality gate. A zero count is expected for the current pilot.
SELECT
    COUNT(*) AS quality_issue_count
FROM vw_financial_data_quality_issues;

-- If the previous query is not zero, inspect the exact problems here.
SELECT
    issue_code,
    severity,
    ticker,
    report_id,
    period_end,
    canonical_metric,
    issue_detail
FROM vw_financial_data_quality_issues
ORDER BY
    CASE severity WHEN 'ERROR' THEN 1 ELSE 2 END,
    issue_code,
    period_end,
    canonical_metric;
-- ============================================================================
-- END sql/09_validate_financial_module.sql
-- ============================================================================
