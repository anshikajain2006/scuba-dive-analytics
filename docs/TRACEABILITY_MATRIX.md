# Requirements Traceability Matrix

Project: scuba-dive-analytics (local folder: Scuba). Phase 5.

Each row traces one chain from evidence to delivery: **finding** in
[`FINDINGS.md`](FINDINGS.md) → **business requirement** in [`BRD.md`](BRD.md) §5 →
**user story** in [`USER_STORIES.md`](USER_STORIES.md) → **recommendation**. The
"Process" column points to the node in [`TO_BE_FLOW.md`](TO_BE_FLOW.md) that
implements it, and the "Closes" column to the failure point in
[`AS_IS_FLOW.md`](AS_IS_FLOW.md).

## Forward trace

| # | Finding (FINDINGS.md) | Key figure | Source | BR | User story | Rec | Closes | Success KPI |
|---|---|---|---|---|---|---|---|---|
| 1 | §2② Non-weather cancellations are the addressable pool. §3 the model concentrates them | 795 cancellations, ₹79,77,635. Top 3 deciles = 58.1% of cancellations in 30% of bookings | `sql/06 Q1–Q3`, `03_model` | BR-01 | US-01 | **R1** | F2 | `cancellation_rate` 25.7% ▼ |
| 2 | §3 R1 has to be measured to be managed | Precision 49.8% at deciles 1–3 | `03_model` | BR-02 | US-02 | **R1** | F2 | `cancellation_rate`, `no_show_rate` ▼ |
| 3 | §2③ OTA cancels and no-shows most | `cancellation_rate` 27.8%, `no_show_rate` 7.5%, 486 seats lost | `sql/06 Q4–Q5` | BR-03 | US-03, US-11 | **R2** | F3 | `cancellation_rate`, `no_show_rate` ▼ |
| 4 | §2③ OTA customers are worth least | Lifetime revenue per diving customer ₹9,533 vs ₹14,197 walk-in. Avg price ₹8,167 vs ₹11,090. Share 8.5% → 29.4% | `sql/03 Q6`, `sql/04 Q3` | BR-04 | US-04 | **R2** | F3 | `revenue_per_dive` ₹4,173 ▲, `customer_ltv` ▲ |
| 5 | §2④ Graduates stop returning, mostly within 90 days | `course_to_fundive_conversion` 39.5% → 4.8% (90-day 27.8% → 3.7%). 69% return within 90 days, median 49 | `sql/03 Q3–Q4` | BR-05 | US-05 | **R3** | F4 | `course_to_fundive_conversion` ▲, `repeat_customer_rate` ▲ |
| 6 | §2④ Course is the largest revenue line | 42.3% of revenue, ₹2,32,53,650 | `sql/04` | BR-06 | US-06 | **R3** | F4 | `customer_ltv` ▲ |
| 7 | §2⑤ Cancellations logged without a reason | 7.7% → 11.4% → 19.6% of cancellations. 121 in 2025-26 | `sql/02 Q6` | BR-07 | US-07 | **R4** | F5 | `Unknown` reason share → 0% |
| 8 | §2⑤ Customers with no channel | 497 customers (9.0%), ₹50,96,000 (9.3% of revenue) | `01_cleaning`, `sql/04 Q3` | BR-08 | US-08 | **R4** | F5 | `Unknown` channel share → 0% |
| 9 | Data quality: impossible prices | 23 quarantined (15 negative, 8 extreme) | `01_cleaning` C6, `sql/00` | BR-09 | US-12 | **R4** | F5 | Quarantined prices → 0 |
| 10 | §2⑤ Losses cannot be investigated | Unexplained cancellations 5.05% of all 2025-26 bookings | `sql/02 Q6` | BR-10 | US-13 | **R4** | F5 | `Unknown` share tiles |
| 11 | §2① Seats never sold and seats sold then lost | 2025-26: 626 never sold, 750 lost. `capacity_utilization` 54.5% | `sql/01 Q2` | BR-11 | US-09 | **R5** | F1 | `capacity_utilization` → 75% |
| 12 | §1 Demand is highly seasonal | `seasonality_index` Jan 192, Dec 179, Jul–Aug 0 | `sql/05` | BR-11 | US-10 | **R5** | F1 | `capacity_utilization` ▲ |
| 13 | §1 All ten KPIs need a baseline to track against | 2025-26 values, FINDINGS §1 | `sql/01–05` | BR-12 | US-13 | **R1–R5** | — | All ten §3 KPIs |

## Coverage check

| Rec | BRs | User stories | Rows |
|---|---|---|---|
| R1 | BR-01, BR-02 | US-01, US-02 | 1–2 |
| R2 | BR-03, BR-04 | US-03, US-04, US-11 | 3–4 |
| R3 | BR-05, BR-06 | US-05, US-06 | 5–6 |
| R4 | BR-07, BR-08, BR-09, BR-10 | US-07, US-08, US-12, US-13 | 7–10 |
| R5 | BR-11 | US-09, US-10 | 11–12 |
| All | BR-12 | US-13 | 13 |

Every BR-01 to BR-12 has at least one user story. Every user story US-01 to US-13
traces back to at least one finding. No requirement lacks a measured figure behind it.
