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
