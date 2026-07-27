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
