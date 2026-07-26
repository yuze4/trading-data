-- AI Infrastructure Investment Research & Portfolio Analytics Database
-- New SQL layer in the yuze4/trading-data fork.
-- The upstream repository does not contain these tables.

BEGIN;

-- One row identifies a stock or ETF used by the research database.
CREATE TABLE IF NOT EXISTS securities (
    security_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ticker VARCHAR(12) NOT NULL,
    security_name TEXT NOT NULL,
    asset_type VARCHAR(10) NOT NULL,
    exchange VARCHAR(20),
    cik VARCHAR(10),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_securities_ticker UNIQUE (ticker),
    CONSTRAINT uq_securities_cik UNIQUE (cik),
    CONSTRAINT chk_securities_asset_type
        CHECK (asset_type IN ('STOCK', 'ETF')),
    CONSTRAINT chk_securities_cik
        CHECK (cik IS NULL OR cik ~ '^[0-9]{10}$')
);

-- One row represents one SEC financial-statement filing event.
CREATE TABLE IF NOT EXISTS financial_reports (
    report_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    security_id BIGINT NOT NULL,
    accession_number VARCHAR(25) NOT NULL,
    form_type VARCHAR(10) NOT NULL,
    filing_date DATE NOT NULL,
    period_end DATE NOT NULL,
    fiscal_year INTEGER NOT NULL,
    fiscal_period VARCHAR(4) NOT NULL,
    source_url TEXT NOT NULL,
    is_amended BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_financial_reports_security
        FOREIGN KEY (security_id)
        REFERENCES securities (security_id),
    CONSTRAINT uq_financial_reports_accession
        UNIQUE (accession_number),
    CONSTRAINT chk_financial_reports_form_type
        CHECK (form_type IN ('10-K', '10-Q')),
    CONSTRAINT chk_financial_reports_fiscal_period
        CHECK (fiscal_period IN ('FY', 'Q1', 'Q2', 'Q3', 'Q4')),
    CONSTRAINT chk_financial_reports_fiscal_year
        CHECK (fiscal_year BETWEEN 1900 AND 2100),
    CONSTRAINT chk_financial_reports_dates
        CHECK (filing_date >= period_end),
    CONSTRAINT chk_financial_reports_source_url
        CHECK (source_url LIKE 'https://%')
);

-- These indexes support the main research lookup patterns:
-- "show one company's filings by reporting period" and
-- "show one company's filings by the date known to the market".
CREATE INDEX IF NOT EXISTS idx_financial_reports_security_period
    ON financial_reports (security_id, period_end DESC);

CREATE INDEX IF NOT EXISTS idx_financial_reports_security_filing_date
    ON financial_reports (security_id, filing_date DESC);

COMMIT;
