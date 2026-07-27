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
