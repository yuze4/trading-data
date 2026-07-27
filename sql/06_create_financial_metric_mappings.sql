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
