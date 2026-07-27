# Scuba Dive Operator Analytics — Case Study

> **Status: skeleton.** Phase 0 (scaffold) and Phase 2 (raw dataset) are complete. Sections below are
> placeholders to be filled by the owning phase — see [PROJECT_BRIEF.md](PROJECT_BRIEF.md) §5.
> Drafted in Phase 6.

A mid-size PADI dive center in Havelock (Andaman Islands, India) has seen bookings and revenue decline
over the last ~2.5 seasons. This repo diagnoses the causes, quantifies the financial impact, and
delivers a prioritized fix plus a redesigned booking/retention process.

---

## 1. Problem

<!-- Phase 1 — Anshika Jain. Problem statement + stakeholder map. Frame around the business decision:
     where is revenue leaking and what do we change. See docs/BRD.md. -->

_TBD — Phase 1._

## 2. Approach

<!-- Phase 2–3 — Anshika Jain. Data generation → SQL extraction → cleaning/EDA → one model
     (cancellation-risk OR RFM segmentation). -->

| Step | Artifact |
|---|---|
| Synthetic dataset (raw, messy) | [`data/generate_data.py`](data/generate_data.py) → [`data/raw/`](data/raw/) |
| Cleaning + EDA | `notebooks/` _(Phase 3)_ |
| SQL extraction queries | `sql/` _(Phase 3)_ |
| Model | `notebooks/` _(Phase 3)_ |

_TBD — Phase 3._

## 3. KPIs

All KPI names below are fixed by [PROJECT_BRIEF.md](PROJECT_BRIEF.md) §3 and must match exactly in the
notebook, dashboard, and BRD.

`capacity_utilization` · `booking_conversion_rate` · `cancellation_rate` · `no_show_rate` ·
`repeat_customer_rate` · `course_to_fundive_conversion` · `revenue_per_customer` · `revenue_per_dive` ·
`customer_ltv` · `seasonality_index`

## 4. Findings

<!-- Phase 3 — Anshika Jain. Quantified, each with the number that supports it. -->

_TBD — Phase 3._

## 5. Recommendations

<!-- Phase 5 — Anshika Jain. Every recommendation must cite a specific number from Phase 3 (brief §7). -->

_TBD — Phase 5._

## 6. Dashboard

<!-- Phase 4 — spec/export and build in Power BI/Tableau by Anshhika.
     Must render all §3 KPIs with at least a season slicer. -->

_TBD — Phase 4. Dashboard link goes here._

---

## Repo layout

```
.
├── README.md              # this case study
├── PROJECT_BRIEF.md       # source of truth: scope, schema, KPI dictionary
├── data/
│   ├── generate_data.py   # synthetic raw-data generator (Phase 2)
│   ├── raw/               # untouched messy data — CSV + SQLite
│   └── clean/             # post-cleaning (Phase 3)
├── sql/                   # extraction queries
├── notebooks/             # cleaning + EDA + model
├── dashboard/             # .pbix / Tableau link + screenshots + spec
└── docs/                  # BRD, As-Is & To-Be flows, user stories, RTM, recommendation memo
```

## Reproducing the raw dataset

Requires Python 3.9+ only — no third-party packages.

```bash
python data/generate_data.py
```

Deterministic: a fixed seed means every run reproduces the same dataset byte-for-byte. Writes five CSVs
plus `dive_ops_raw.db` into `data/raw/`, overwriting any previous output.

**The raw layer stays messy by design** (brief §4) — mixed date formats, inconsistent nationality and
casing strings, nulls, negative price outliers, duplicate `booking_id` rows. Cleaning happens in Phase 3
and lands in `data/clean/`. Never edit `data/raw/` by hand.

Currency is INR throughout.
