# PROJECT BRIEF — Dive Operator Analytics Case Study

> Single source of truth. Do not invent KPI names, column names, or numbers that aren't defined here. If something is ambiguous, stop and flag it rather than guessing.

---

## 1. Goal

Build an end-to-end analytics case study for a struggling scuba dive operator that reads as a **data analyst** project (SQL, Python, dashboard, quantified findings) AND a **business analyst** project (BRD, As-Is/To-Be process flows, user stories, recommendation memo). One repo, two framings.

## 2. Scenario

A mid-size PADI dive center in Havelock (Andaman Islands, India) has seen bookings and revenue decline over the last ~2.5 seasons. The owner doesn't know why. The engagement: diagnose the causes, quantify the financial impact, and deliver a prioritized fix plus a redesigned booking/retention process.

Frame every deliverable around the **business decision** ("where is revenue leaking and what do we change"), never around trivia ("which dive site is best").

## 3. KPI dictionary (use these exact names everywhere)

| KPI | Definition |
|---|---|
| `capacity_utilization` | Completed seats booked ÷ total boat slots available, per trip/season |
| `booking_conversion_rate` | Confirmed bookings ÷ inquiries |
| `cancellation_rate` | Cancelled bookings ÷ total bookings (also split by `cancellation_reason`) |
| `no_show_rate` | No-shows ÷ total bookings |
| `repeat_customer_rate` | Customers with >1 completed booking ÷ total customers |
| `course_to_fundive_conversion` | Customers who did a Course then later a Fun Dive ÷ course customers |
| `revenue_per_customer` | Total revenue ÷ distinct customers |
| `revenue_per_dive` | Total revenue ÷ total completed dives |
| `customer_ltv` | Mean total revenue per customer over their lifetime |
| `seasonality_index` | Monthly bookings indexed to the monthly mean (mean = 100) |

## 4. Data schema (synthetic, deliberately messy)

~6,000–8,000 bookings across 2.5 seasons. Keep the RAW file untouched; write a separate CLEAN file. The mess below is intentional — it exists so the cleaning is visible.

**inquiries** — inquiry_id (PK), inquiry_date, channel, converted_booking_id (nullable FK)

**customers** — customer_id (PK), first_name, last_name, nationality *(messy: "India"/"india"/"IN"/"Indian" + other countries)*, age *(some nulls + outliers like 5 or 118)*, cert_level *("None"/"Open Water"/"Advanced"/"Rescue"/"Divemaster", messy casing)*, acquisition_channel *(some nulls)*, signup_date *(mixed formats: 2023-06-01, 01/06/2023, "June 1 2023")*

**bookings** — booking_id (PK), customer_id (FK), booking_date *(mixed formats)*, dive_date, dive_type *("Discovery Dive"/"Fun Dive"/"Course", plus synonyms like "DSD" to normalize)*, num_dives, price_inr *(a few negatives/outliers to catch)*, status *("Completed"/"Cancelled"/"No-show", messy casing)*, cancellation_reason *("Weather"/"Customer"/"Medical"/NULL — some Cancelled rows have NULL reason = the mess)*, trip_id (FK), boat_slot. **Include a handful of fully duplicated booking_id rows to dedupe.**

**trips** — trip_id (PK), dive_site *(fictional/generic names)*, difficulty *("Beginner"/"Intermediate"/"Advanced")*, boat_capacity *(8–12)*, season *("Peak" Oct–May / "Shoulder" / "Monsoon-Closed" ≈ Jun–Sep)*

**weather** — weather_date (PK), sea_condition *("Calm"/"Moderate"/"Rough"/"Closed")*. Rough/Closed should correlate with Weather cancellations.

## 5. Phases, deliverables, and ownership

| Phase | Deliverable | Owner |
|---|---|---|
| 0 | Repo scaffold, folder structure, README skeleton, git init | Anshika Jain |
| 1 | Problem statement, BRD, stakeholder map, KPI definitions, **As-Is process flow** | Anshika Jain |
| 2 | Messy synthetic dataset (raw), loaded into SQLite/Postgres | Anshika Jain |
| 3 | SQL extraction queries; cleaning + EDA notebook; ONE model (cancellation-risk **or** RFM segmentation) | Anshika Jain |
| 4 | Dashboard data export + dashboard spec (KPI cards, seasonality slicer, utilization heatmap, cancellation breakdown, revenue by product/channel) | Spec/export; **Anshhika** builds in Power BI/Tableau |
| 5 | **To-Be process flow**, user stories + acceptance criteria, requirements traceability matrix, one-page recommendation memo (each rec tied to a number from Phase 3) | Anshika Jain |
| 6 | README case study stitching it all together | Anshika Jain |

Phases 1 and 2 run in parallel. Phase 5 depends on Phase 3 findings.

## 6. Repo structure

```
scuba-dive-analytics/
├── README.md              # case study: problem → approach → findings → recommendations → dashboard link
├── PROJECT_BRIEF.md       # this file
├── data/
│   ├── raw/               # untouched messy data
│   └── clean/             # post-cleaning
├── sql/                   # extraction queries
├── notebooks/             # cleaning + EDA + model
├── dashboard/             # .pbix / Tableau link + screenshots + spec
└── docs/                  # BRD, As-Is & To-Be flows, user stories, RTM, recommendation memo
```

## 7. Consistency rules (non-negotiable)

- KPI names in the notebook, dashboard, and BRD must match section 3 **exactly**.
- Every recommendation in Phase 5 must cite a specific number produced in Phase 3. No unsupported claims.
- Currency is INR throughout.
- Process flows delivered as Mermaid in `/docs` so they render on GitHub.

## 8. Definition of done

- Raw + clean data both present; cleaning steps documented in the notebook.
- Dashboard renders all KPIs from section 3 with at least a season slicer.
- `/docs` contains BRD, As-Is flow, To-Be flow, ≥5 user stories with acceptance criteria, RTM, and a one-page memo.
- README tells the full story top-to-bottom and links the dashboard.

## 9. CV framing (target output)

**Data Analyst:** "Built an end-to-end dive-operator analytics pipeline (SQL, Python, Power BI) on ~7K bookings; identified capacity and retention leaks projected to recover ₹X/season."

**Business Analyst:** "Diagnosed a revenue decline end-to-end — authored BRD, As-Is/To-Be process flows, and user stories; recommended a rebooking + re-engagement workflow projected to lift utilization from 55% to 75%."
