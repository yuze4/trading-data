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
