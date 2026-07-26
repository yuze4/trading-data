# Financial Statement Pilot: NVIDIA Q1 FY2027

Status: pilot mapping only. This document records one manually verified filing example. It is not produced by the project pipeline yet.

## Source filing

- Company: NVIDIA Corporation
- Ticker: NVDA
- Filing type: Form 10-Q
- Filing date: 2026-05-20
- Fiscal period end: 2026-04-26
- Statement currency and scale: USD millions, except per-share data
- Official filing: https://www.sec.gov/Archives/edgar/data/1045810/000104581026000052/nvda-20260426.htm
- SEC filing directory and XBRL files: https://www.sec.gov/Archives/edgar/data/1045810/000104581026000052/

The filing presents three-month results for April 26, 2026 and the comparable three-month period ended April 27, 2025.

## Manually mapped raw facts

| Canonical metric | Q1 FY2027 | Comparable Q1 FY2026 | Source statement |
|---|---:|---:|---|
| Revenue | 81,615 | 44,062 | Income statement |
| Gross profit | 61,157 | 26,668 | Income statement |
| Operating income | 53,536 | 21,638 | Income statement |
| Net income | 58,321 | 18,775 | Income statement |
| Diluted EPS | 2.39 | 0.76 | Income statement |
| Operating cash flow | 50,344 | 27,414 | Cash-flow statement |
| Capital expenditures | 1,757 | 1,227 | Cash-flow statement |
| Cash and cash equivalents at period end | 13,237 | 15,234 | Balance sheet / cash-flow statement |
| Short-term debt | 1,000 | Not shown in this comparison table | Balance sheet |
| Long-term debt | 7,470 | Not shown in this comparison table | Balance sheet |

All amounts are USD millions unless otherwise stated.

## Derived values

Using normalized positive CapEx:

- Revenue YoY growth: approximately 85.2%;
- Gross margin: approximately 74.9%;
- Operating margin: approximately 65.6%;
- Net margin: approximately 71.5%;
- Operating cash-flow margin: approximately 61.7%;
- Free cash flow: 50,344 - 1,757 = 48,587;
- Free-cash-flow margin: approximately 59.5%;
- Cash / reported debt: approximately 1.56x, using 13,237 / (1,000 + 7,470);
- Operating-income YoY growth: approximately 147.4%;
- Net-income YoY growth: approximately 210.6%;
- Operating-cash-flow YoY growth: approximately 83.6%.

These calculations are manual validation examples. They are not yet database query results.

## Important interpretation caution

Net income increased faster than operating income in this quarter partly because the income statement includes substantial other income. A production research view should therefore display operating income and net income separately rather than treating net-income growth alone as evidence of core operating improvement.

The filing also reports segment-level revenue and operating income for Compute & Networking and Graphics. Segment analysis is a planned extension, not part of the first base metric table.

## SQL implementation implied by this example

The production pipeline will need to:

1. store one filing event in financial_reports;
2. store each raw fact in financial_facts;
3. preserve filing_date separately from period_end;
4. normalize the CapEx sign convention;
5. use LAG for comparable-period growth;
6. calculate margins with NULLIF to avoid division-by-zero;
7. retain source URLs and accession numbers;
8. run quality checks before publishing a research view.

## Status boundary

This pilot confirms that the proposed metric definitions can be mapped manually to a real filing. It does not confirm that SEC XBRL ingestion, concept mapping, quarterly normalization, or database calculations work automatically. Those remain unimplemented and unverified.
