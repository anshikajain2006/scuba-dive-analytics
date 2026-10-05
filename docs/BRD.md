# Business Requirements Document — Havelock Dive Centre Revenue Recovery

| | |
|---|---|
| Project | scuba-dive-analytics (local folder: Scuba) |
| Phase | 1 (BRD), completed against Phase 3 evidence |
| Evidence base | [`docs/FINDINGS.md`](FINDINGS.md). Every figure below cites its section and source query |
| KPI names | Exactly as defined in [`PROJECT_BRIEF.md`](../PROJECT_BRIEF.md) §3 |
| Currency | INR throughout |
| Dashboard build | Anshhika (Power BI, brief §5) |

> **Data note.** The dataset is synthetic. Its trends were deliberately planted by
> `data/generate_data.py` (assumption **A10**) so that Phase 3 had real signal to
> find. The requirements below are written as if for a real operator. The figures
> show the method working on the data; they are not a forecast for any real business.

---

## 1. Executive summary

**Problem statement.** A mid-size PADI dive centre in Havelock (Andaman Islands)
lost **34.5% of its revenue in one season** (₹2,22,50,950 → ₹1,45,64,050, 2024-25
→ 2025-26), and the owner could not say why. The analysis shows that most of the
loss is not falling demand. The shop sells seats, and then many of those bookings
never turn into completed dives.

**Scope.** The booking lifecycle from first inquiry to repeat purchase: how inquiries
are captured, how bookings are confirmed, how cancellations and no-shows happen,
what happens after a course graduate leaves, and how boat departures are scheduled.

**Objectives.**

1. Reduce cancellations that are not caused by weather (the addressable pool:
   **795 cancellations, ₹79,77,635**. FINDINGS §2②).
2. Re-price the OTA channel so its growth stops eroding revenue per dive (FINDINGS §2③).
3. Bring course graduates back for fun dives (FINDINGS §2④).
4. Record the reason for every cancellation and the source of every booking (FINDINGS §2⑤).
5. Raise `capacity_utilization` from **54.5%** toward the brief's **75%** target
   (brief §9; FINDINGS §2①).

## 2. Business context

The centre sells three products: **Discovery Dive** (try-dive for non-divers),
**PADI Course** (certification) and **Fun Dive** (guided dives for certified
divers). It trades from October to May. The monsoon closes the sea from June to
September. Customers arrive through six acquisition channels: Walk-in, OTA (online travel
agents), Website, Referral, Instagram and Hotel Partner.

**How the revenue leaks** (FINDINGS §2①, `sql/04 Q1`, `sql/01 Q2`):

| | 2024-25 | 2025-26 | Change |
|---|---|---|---|
| Revenue | ₹2,22,50,950 | ₹1,45,64,050 | **−34.5%** |
| Bookings taken | 2,884 | 2,396 | **−16.9%** |
| `capacity_utilization` | 58.0% | 54.5% | −3.5pp |
| `cancellation_rate` | 18.5% | 25.7% | +7.2pp |

Revenue fell about twice as fast as bookings. In 2025-26 the shop took 2,396
bookings against 3,022 seats and completed 1,646. **750 booked seats (31%) were
lost** to cancellations and no-shows. Another **626 seats were never sold**.
Losing seats it had already sold is an operational problem. That means the shop
can fix it.

## 3. Stakeholder register

| Stakeholder | Role in the process | Interest / pain today | Influence | Involvement |
|---|---|---|---|---|
| **Dive Centre Owner / Manager** | Sets prices, channels, schedule; signs off changes | Revenue down 34.5% with no diagnosis | High | Sponsor, approves BRs |
| **Front Desk Staff** | Takes inquiries and bookings, logs cancellations, handles walk-ins | No call list; cancellation and channel fields are optional | Medium | Primary user of R1, R4 |
| **Dive Instructors** | Run courses and trips; last contact with graduates | Under-filled boats; no hand-off for graduates | Medium | Key to R3, affected by R5 |
| **OTA Partners** | Third-party booking platforms (29.4% of 2025-26 bookings) | Commission revenue; may resist deposit terms | Medium | Party to R2 renegotiation |
| **Customers** (OTA, Walk-in, Graduate) | Book, cancel, return | Clear terms; timely reminders | Low individually | Affected by R1–R4 |
| **Analyst / Dashboard builder (Anshhika)** | Maintains KPIs and the dashboard | Data gaps limit what can be measured | Low | Measures success (§8) |

## 4. Current-state problems

Each recommendation addresses a problem that the data measures.

| Rec | Problem | Measured evidence | Source |
|---|---|---|---|
| **R1** | Cancellations are rising, and most of them are not caused by weather. Nothing is done before dive day to keep a booking that looks likely to cancel | `cancellation_rate` 18.5% → **25.7%**. **795 non-weather cancellations worth ₹79,77,635**. The model's top 3 risk deciles hold **58.1% of cancellations (358 of 616) in 30% of bookings** | FINDINGS §2①②, §3. `sql/06 Q1–Q3`. `03_model` |
| **R2** | OTA bookings are cheap, unreliable and growing. Customers can cancel without losing anything | OTA share **8.5% → 29.4%**. `cancellation_rate` **27.8%** vs 13.8% walk-in. `no_show_rate` **7.5%** vs 3.5%. Avg price **₹8,167** vs ₹11,090. `customer_ltv` **₹9,533** vs ₹14,197. **486 seats lost** | FINDINGS §2③. `sql/06 Q4–Q5`. `sql/04 Q3` |
| **R3** | Course graduates leave and are never followed up | `course_to_fundive_conversion` **39.5% → 16.1% → 4.8%** (90-day like-for-like **27.8% → 3.7%**). 69% of returners come back within 90 days (median 49). Course = **42.3% of revenue (₹2,32,53,650)** | FINDINGS §2④. `sql/03 Q3–Q4` |
| **R4** | The cancellation reason and the booking channel are optional fields, so losses cannot be explained | Cancellations with no reason **7.7% → 11.4% → 19.6%** (121 this season). **9.0% of customers have no channel, covering ₹50,96,000 (9.3% of revenue)** | FINDINGS §2⑤. `sql/02 Q6`. `01_cleaning` |
| **R5** | Departures run on a flat schedule, but demand is highly seasonal | `capacity_utilization` 58.0% → **54.5%**. **626 seats never sold**. `seasonality_index` Jan **192**, Jul–Aug **0**. Reaching 75% needs **620 more completed seats, worth ₹62,26,569** | FINDINGS §1, §2①. `sql/01`, `sql/05` |

## 5. Business requirements

Priority is MoSCoW. Every BR traces to a finding and user story in
[`TRACEABILITY_MATRIX.md`](TRACEABILITY_MATRIX.md).

| ID | Requirement | Rec | Priority | Evidence |
|---|---|---|---|---|
| **BR-01** | Score every upcoming booking with the cancellation-risk model. Each day, give the front desk a list of bookings in **risk deciles 1–3** whose dive is **48 hours away**, so staff can call to confirm or offer to reschedule | R1 | Must | Top 3 deciles = 58.1% of cancellations, precision 49.8% (FINDINGS §3) |
| **BR-02** | Log the outcome of every confirmation call (confirmed / rescheduled / cancelled / unreachable) so recovered seats can be counted | R1 | Must | Needed to measure R1 against the ₹79,77,635 pool |
| **BR-03** | Require a deposit on every OTA booking before the seat is confirmed. If the OTA will not collect deposits, renegotiate commission to cover the cost of lost seats | R2 | Must | OTA `cancellation_rate` 27.8%, `no_show_rate` 7.5%, 486 seats lost (FINDINGS §2③) |
| **BR-04** | Report revenue, `cancellation_rate`, `no_show_rate` and `customer_ltv` by acquisition channel every season, to support channel negotiations | R2 | Should | OTA `customer_ltv` ₹9,533 vs ₹14,197 walk-in |
| **BR-05** | Send every newly certified diver a fun-dive offer **30–45 days after certification**, plus one reminder before day 90 | R3 | Must | 69% of returns within 90 days, median 49 (FINDINGS §2④) |
| **BR-06** | The instructor records the graduate's certification date and contact consent at course completion, so the BR-05 trigger can fire | R3 | Must | Precondition for BR-05 |
| **BR-07** | `cancellation_reason` is a **mandatory** field (Weather / Customer / Medical / Other + free text). A cancellation cannot be saved without it | R4 | Must | Unknown reasons 19.6% of 2025-26 cancellations (FINDINGS §2⑤) |
| **BR-08** | `acquisition_channel` is a **mandatory** field on every booking, from a fixed list, on every booking path including OTA imports | R4 | Must | 497 customers (9.0%), ₹50,96,000 not attributable |
| **BR-09** | Reject prices ≤ 0 and prices outside a range set by the owner when they are entered | R4 (data quality) | Should | 23 impossible prices quarantined (FINDINGS, Data quality) |
| **BR-10** | Report the share of `Unknown` reasons and `Unknown` channels monthly as data-quality indicators | R4 (data quality) | Should | Makes R4's effect visible |
| **BR-11** | Set the number of departures per month using `seasonality_index` and booked load. Merge under-filled departures at least 48 hours ahead | R5 | Should | 626 unsold seats. Jan index 192 vs Apr 121 (FINDINGS §1) |
| **BR-12** | Track all ten §3 KPIs on a dashboard with a season slicer, with 2025-26 as the baseline | All | Must | Brief §8. `dashboard/DASHBOARD_SPEC.md` |

## 6. Assumptions and constraints

| # | Assumption / constraint | Status |
|---|---|---|
| A1 | The data is synthetic and its trends are planted (`generate_data.py` A10). The figures prove the method. They are not a forecast | Constraint |
| A2 | Revenue counts Completed bookings only. Cancelled and no-show bookings are valued at ₹0 | Constraint |
| A3 | 2023-24 is a half season (Jan–May 2024). Trend claims compare 2024-25 with 2025-26 only | Constraint |
| A4 | The model should be used to pick a high-risk **group** (deciles 1–3), not to quote a probability for one booking. Deciles 4–7 are not monotonic | Constraint (FINDINGS §3) |
| A5 | Lead time is **not** a cancellation driver (16.6%–19.6% across buckets). No policy here relies on it | Constraint (FINDINGS §3) |
| **OQ-1** | ⚠ **OPEN: `booking_conversion_rate` definition.** §3 says "confirmed bookings", but `status` has no `Confirmed` value. This BRD uses *inquiry produced a booking* (**51.3%** overall, 43.7% in 2025-26). Counting only bookings that did not later cancel gives **39.3%** (2025-26: 30.1%). The owner must choose one definition. | Unresolved |
| **OQ-2** | ⚠ **OPEN: deposit model.** The brief does not say whether the shop already takes deposits. If it does, every loss figure is overstated, and BR-03 becomes "enforce the deposit on OTA" rather than "introduce" one. | Unresolved |
| **OQ-3** | ⚠ **OPEN: `revenue_per_customer` vs `customer_ltv`.** As literally defined these are the same calculation. FINDINGS splits them by denominator: all 5,495 customers (₹10,000) vs the 4,353 with a valid completed booking (₹12,624). Confirm this split before quoting both. | Unresolved |
| **OQ-4** | ⚠ **OPEN: Shoulder months.** §4 leaves "Shoulder" with no months. The assumption used here is Peak = Dec–Mar, Shoulder = Oct–Nov + Apr–May. This affects only the trading-season cut used by BR-11, not any headline KPI. | Unresolved |

## 7. Out of scope

- Price-list changes and new products. R2 changes OTA *terms*, not the price list.
- Weather mitigation beyond rescheduling. Nobody can change sea conditions.
- Marketing spend and new acquisition campaigns.
- Choosing or building a booking-software vendor. These BRs are vendor-neutral.
- Staffing, payroll and boat purchase or lease decisions.
- Re-running the analysis on real operator data. This is a separate engagement, and it needs OQ-1 to OQ-4 resolved first.

## 8. Success metrics

Baseline = 2025-26 (FINDINGS §1). Only `capacity_utilization` has a target in the
brief (75%, §9). The owner should set the other targets once a season of post-change
data exists. Until then, success means the KPI moves in the direction shown.

| KPI | Baseline 2025-26 | Target / direction | Moved mainly by |
|---|---|---|---|
| `capacity_utilization` | 54.5% | **75%** (brief §9) | R1, R2, R5 |
| `booking_conversion_rate` | 43.7% (definition: OQ-1) | ▲ | R2, R4 |
| `cancellation_rate` | 25.7% | ▼ | R1, R2 |
| `no_show_rate` | 5.6% | ▼ | R1, R2 |
| `repeat_customer_rate` | 16.0% overall | ▲ | R3 |
| `course_to_fundive_conversion` | 4.8% (90-day: 3.7%) | ▲ | R3 |
| `revenue_per_customer` | ₹9,588 | ▲ | R2, R3 |
| `revenue_per_dive` | ₹4,173 | ▲ | R2 |
| `customer_ltv` | ₹12,624 overall | ▲ | R2, R3 |
| `seasonality_index` | Jan 192 · Jul–Aug 0 | Used to set the schedule (BR-11), not a target | R5 |

Data-quality indicators (BR-10): `Unknown` share of cancellations, 19.6% today, and
`Unknown` share of customers, 9.0% today. **Target 0%**, because BR-07 and BR-08
make both fields mandatory.
