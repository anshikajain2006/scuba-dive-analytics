# Scuba Dive Operator Analytics — Case Study

> **Status: Phases 0, 2, 3 and 4 complete.** The technical build is done — raw data, cleaning,
> SQL, EDA, model and dashboard export all exist and reproduce. The narrative sections below
> (Problem, Recommendations) are still placeholders filled in Phases 1 and 5 — see
> [PROJECT_BRIEF.md](PROJECT_BRIEF.md) §5. This README is drafted in Phase 6.
>
> **Findings with real numbers live in [docs/FINDINGS.md](docs/FINDINGS.md).**

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
| Cleaning pipeline | [`notebooks/01_cleaning.ipynb`](notebooks/01_cleaning.ipynb) → [`data/clean/`](data/clean/) |
| EDA + all 10 KPIs | [`notebooks/02_eda_kpis.ipynb`](notebooks/02_eda_kpis.ipynb) |
| Model — cancellation risk | [`notebooks/03_model_cancellation_risk.ipynb`](notebooks/03_model_cancellation_risk.ipynb) |
| Dashboard export | [`notebooks/04_dashboard_export.ipynb`](notebooks/04_dashboard_export.ipynb) → [`dashboard/`](dashboard/) |
| SQL extraction queries | [`sql/`](sql/) — see [`sql/README.md`](sql/README.md) |

Run the notebooks in numeric order; each writes the inputs the next one reads.
Requires `pandas`, `numpy`, `matplotlib`, `scikit-learn`.

## 3. KPIs

All KPI names below are fixed by [PROJECT_BRIEF.md](PROJECT_BRIEF.md) §3 and must match exactly in the
notebook, dashboard, and BRD.

`capacity_utilization` · `booking_conversion_rate` · `cancellation_rate` · `no_show_rate` ·
`repeat_customer_rate` · `course_to_fundive_conversion` · `revenue_per_customer` · `revenue_per_dive` ·
`customer_ltv` · `seasonality_index`

## 4. Findings

**Full detail with sources: [docs/FINDINGS.md](docs/FINDINGS.md).** Headlines, on
7,171 bookings across 2.5 seasons:

| | 2024-25 | 2025-26 |
|---|---|---|
| Revenue | ₹2,22,50,950 | **₹1,45,64,050** (−34.5%) |
| `capacity_utilization` | 58.0% | **54.5%** |
| `cancellation_rate` | 18.5% | **25.7%** |
| `booking_conversion_rate` | 53.1% | **43.7%** |

1. **Revenue fell twice as fast as volume.** 750 of 2,396 booked seats (31%) were sold then lost to cancellations and no-shows.
2. **Weather predicts cancellation but doesn't explain the volume.** Rough/Closed days cancel at 54.7% but are only 14% of bookings; **58.9% of cancellations happen on diveable days**, worth ₹79,77,635.
3. **OTA grew 8.5% → 29.4% of bookings** while cancelling at 27.8% vs 13.8% walk-in, pricing 26% lower, and producing customers worth 33% less.
4. **Retention collapsed** — `course_to_fundive_conversion` 39.5% → 4.8% (27.8% → 3.7% after correcting for censoring). 79.9% of divers never return.
5. **Attribution is failing** — unexplained cancellations rose to 19.6% of the cancellation book; 9.3% of revenue has no channel.

Model: cancellation-risk logistic regression, out-of-time AUC **0.749**. The top 3 risk deciles (30% of bookings) contain **58.1% of all cancellations**.

## 5. Recommendations

<!-- Phase 5 — Anshika Jain. Every recommendation must cite a specific number from Phase 3 (brief §7). -->

_TBD — Phase 5._

## 6. Dashboard

<!-- Phase 4 — spec/export and build in Power BI/Tableau by Anshhika.
     Must render all §3 KPIs with at least a season slicer. -->

Export files and the full build spec are in [`dashboard/`](dashboard/) — see
[`DASHBOARD_SPEC.md`](dashboard/DASHBOARD_SPEC.md) for the data model, measure
definitions, page-by-page layout and build checklist. Five CSVs form a star
schema (`fact_bookings`, `fact_trips`, `fact_inquiries`, `dim_customers`,
`dim_date`) plus a pre-computed `kpi_summary`.

_Dashboard link goes here once built (Anshhika, Phase 4)._

---

## Repo layout

```
.
├── README.md              # this case study
├── PROJECT_BRIEF.md       # source of truth: scope, schema, KPI dictionary
├── data/
│   ├── generate_data.py   # synthetic raw-data generator (Phase 2)
│   ├── raw/               # untouched messy data — CSV + SQLite
│   └── clean/             # post-cleaning — CSV + SQLite (PK/FK enforced) + audit trail
├── sql/                   # extraction queries, one file per KPI group
├── notebooks/             # 01 cleaning · 02 EDA+KPIs · 03 model · 04 dashboard export
├── dashboard/             # star-schema CSVs + DASHBOARD_SPEC.md (.pbix to follow)
└── docs/                  # FINDINGS.md; BRD, As-Is/To-Be flows, user stories, RTM, memo to follow
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
