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
        LAG(s.period_end, 1) OVER (
            PARTITION BY s.security_id
            ORDER BY s.period_end
        ) AS previous_period_end,
        LAG(s.revenue_usd_millions, 1) OVER (
            PARTITION BY s.security_id
            ORDER BY s.period_end
        ) AS previous_revenue_usd_millions,
        LAG(s.operating_income_usd_millions, 1) OVER (
            PARTITION BY s.security_id
            ORDER BY s.period_end
        ) AS previous_operating_income_usd_millions,
        LAG(s.free_cash_flow_usd_millions, 1) OVER (
            PARTITION BY s.security_id
            ORDER BY s.period_end
        ) AS previous_free_cash_flow_usd_millions,
        LAG(s.period_end, 4) OVER (
            PARTITION BY s.security_id
            ORDER BY s.period_end
        ) AS prior_year_period_end_candidate,
        LAG(s.fiscal_year, 4) OVER (
            PARTITION BY s.security_id
            ORDER BY s.period_end
        ) AS prior_year_fiscal_year_candidate,
        LAG(s.fiscal_period, 4) OVER (
            PARTITION BY s.security_id
            ORDER BY s.period_end
        ) AS prior_year_fiscal_period_candidate,
        LAG(s.revenue_usd_millions, 4) OVER (
            PARTITION BY s.security_id
            ORDER BY s.period_end
        ) AS prior_year_revenue_usd_millions_candidate,
        LAG(s.operating_income_usd_millions, 4) OVER (
            PARTITION BY s.security_id
            ORDER BY s.period_end
        ) AS prior_year_operating_income_usd_millions_candidate,
        LAG(s.free_cash_flow_usd_millions, 4) OVER (
            PARTITION BY s.security_id
            ORDER BY s.period_end
        ) AS prior_year_free_cash_flow_usd_millions_candidate,
        LAG(s.operating_margin_pct, 4) OVER (
            PARTITION BY s.security_id
            ORDER BY s.period_end
        ) AS prior_year_operating_margin_pct_candidate,
        LAG(s.free_cash_flow_margin_pct, 4) OVER (
            PARTITION BY s.security_id
            ORDER BY s.period_end
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

-- Verification: one NVIDIA pilot row is expected, with no prior-year growth
-- yet because only one filing has been loaded.
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
ORDER BY period_end;
