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
