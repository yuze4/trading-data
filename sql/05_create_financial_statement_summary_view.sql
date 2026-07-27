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
