-- AI Infrastructure Investment Research & Portfolio Analytics Database
-- First-version technology research universe in the yuze4/trading-data fork.
--
-- This is a research-universe seed, not a claim that these are the ten largest
-- technology companies by market capitalization. The list is designed for the
-- project's AI-infrastructure question:
--   * infrastructure suppliers: NVDA, AMD, AVGO, MU, ANET
--   * cloud and AI-capex buyers: MSFT, AMZN, GOOGL, META, ORCL
--
-- Ticker and CIK identity values were checked against the SEC company ticker
-- reference. This file only registers securities; it does not pretend that
-- financial filings or facts for the nine non-NVIDIA companies already exist.

BEGIN;

INSERT INTO securities (
    ticker,
    security_name,
    asset_type,
    exchange,
    cik
)
VALUES
    ('NVDA', 'NVIDIA Corporation', 'STOCK', 'NASDAQ', '0001045810'),
    ('AMD', 'Advanced Micro Devices, Inc.', 'STOCK', 'NASDAQ', '0000002488'),
    ('AVGO', 'Broadcom Inc.', 'STOCK', 'NASDAQ', '0001730168'),
    ('MU', 'Micron Technology, Inc.', 'STOCK', 'NASDAQ', '0000723125'),
    ('ANET', 'Arista Networks, Inc.', 'STOCK', 'NYSE', '0001596532'),
    ('MSFT', 'Microsoft Corporation', 'STOCK', 'NASDAQ', '0000789019'),
    ('AMZN', 'Amazon.com, Inc.', 'STOCK', 'NASDAQ', '0001018724'),
    ('GOOGL', 'Alphabet Inc.', 'STOCK', 'NASDAQ', '0001652044'),
    ('META', 'Meta Platforms, Inc.', 'STOCK', 'NASDAQ', '0001326801'),
    ('ORCL', 'Oracle Corporation', 'STOCK', 'NYSE', '0001341439')
ON CONFLICT (ticker) DO UPDATE
SET security_name = EXCLUDED.security_name,
    asset_type = EXCLUDED.asset_type,
    exchange = EXCLUDED.exchange,
    cik = EXCLUDED.cik,
    is_active = TRUE;

COMMIT;

-- Verification 1: the first-version research universe should contain ten
-- active securities, including the existing NVIDIA pilot issuer.
SELECT
    ticker,
    security_name,
    asset_type,
    exchange,
    cik,
    is_active
FROM securities
WHERE ticker IN (
    'NVDA',
    'AMD',
    'AVGO',
    'MU',
    'ANET',
    'MSFT',
    'AMZN',
    'GOOGL',
    'META',
    'ORCL'
)
ORDER BY ticker;

-- Verification 2: expected result is 10.
SELECT
    COUNT(*) AS technology_universe_count,
    COUNT(*) FILTER (WHERE is_active = TRUE) AS active_technology_count
FROM securities
WHERE ticker IN (
    'NVDA',
    'AMD',
    'AVGO',
    'MU',
    'ANET',
    'MSFT',
    'AMZN',
    'GOOGL',
    'META',
    'ORCL'
);
