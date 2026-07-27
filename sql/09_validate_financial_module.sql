-- AI Infrastructure Investment Research & Portfolio Analytics Database
-- One-pass validation queries for the financial-statement module.
-- Run this file after sql/01 through sql/08, sql/10, and sql/11 in the same
-- PostgreSQL session.

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

-- 2. Confirm the first-version technology universe contains ten active
-- securities. Only NVIDIA has financial facts in this step.
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

-- 3. Confirm the pilot contains one issuer, five filings, and 45 facts in
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

-- 4. Human-readable financial summary.
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

-- 5. Window-function growth output.
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

-- 6. Quality gate. A zero count is expected for the current pilot.
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
