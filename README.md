# Where a dive operator's revenue went

**A diagnostic case study — SQL · Python · predictive model · Power BI**

A mid-size PADI dive centre in Havelock (Andaman Islands) watched revenue fall by
a third in a single season and did not know why. This repo diagnoses the cause on
**7,171 bookings across 2.5 seasons**, quantifies the leak in rupees, and hands
back a prioritised fix.

The short version: **the operator is not failing to sell seats. It is selling
seats and then losing them.**

| | |
|---|---|
| **Data** | 7,171 bookings · 5,495 customers · 922 trips · 10,845 inquiries |
| **Period** | 2024-01-01 → 2026-05-31 (2.5 seasons) |
| **Revenue analysed** | ₹5,49,50,350 |
| **Headline leak** | ₹79,77,635 in cancellations that weather does not explain |
| **Model** | Cancellation-risk logistic regression, out-of-time AUC **0.749** |
| **Evidence base** | [`docs/FINDINGS.md`](docs/FINDINGS.md) — every number, with its source |

---

## 1. Problem

Bookings and revenue have declined across the last ~2.5 seasons. The owner has no
diagnosis — only the symptom. Three explanations were plausible going in, and they
imply completely different responses:

- **Demand has fallen** — fewer people want to dive here. Response: marketing spend.
- **The weather has turned** — more rough days, more cancellations. Response: nothing much; you cannot fix the sea.
- **Something operational is broken** — the shop takes bookings it fails to convert into completed dives. Response: fix the process.

The engagement had to establish which, quantify it, and prescribe a fix that cites
its own evidence. The business question throughout: **where is revenue leaking, and
what do we change?**

Full scope, schema and KPI dictionary: [`PROJECT_BRIEF.md`](PROJECT_BRIEF.md).

## 2. Approach

Five deliberately messy source tables → a trusted analytical layer → KPIs → a model
→ a dashboard. Each stage is reproducible and each artifact is in this repo.

| Stage | What happens | Artifact |
|---|---|---|
| **Generate** | Synthetic raw data with realistic defects: mixed date formats, 54 nationality spellings, duplicate rows, impossible prices | [`data/generate_data.py`](data/generate_data.py) → [`data/raw/`](data/raw/) |
| **Clean** | 12 documented decisions (C1–C12). 7,199 → 7,171 rows; only the 28 duplicates dropped | [`notebooks/01_cleaning.ipynb`](notebooks/01_cleaning.ipynb) → [`data/clean/`](data/clean/) |
| **Extract** | 7 SQL files, 40 statements, one per KPI group — all verified against the notebooks | [`sql/`](sql/) |
| **Analyse** | All ten brief §3 KPIs, overall and by season, plus driver analysis | [`notebooks/02_eda_kpis.ipynb`](notebooks/02_eda_kpis.ipynb) |
| **Model** | Cancellation risk, out-of-time validation | [`notebooks/03_model_cancellation_risk.ipynb`](notebooks/03_model_cancellation_risk.ipynb) |
| **Publish** | Star-schema export + build spec | [`notebooks/04_dashboard_export.ipynb`](notebooks/04_dashboard_export.ipynb) → [`dashboard/`](dashboard/) |

**The raw layer is never edited.** `data/raw/` keeps every defect; cleaning writes a
separate `data/clean/` with primary and foreign keys enforced (zero violations). The
cleaning audit trail is in `data/clean/cleaning_audit.csv`.

Three cleaning choices shaped everything downstream:

- **23 impossible prices were quarantined, not deleted.** A booking with a corrupt price is still a real seat on a real boat — it must count for utilization and cancellation rates. Only its revenue is discarded.
- **196 cancellations with no logged reason became an explicit `Unknown`, not an imputed guess.** How much of the cancellation book is unexplained turned out to be a finding in its own right.
- **497 missing acquisition channels stayed visible as `Unknown`.** Dropping them would have quietly flattered every channel's numbers.

Run order: notebooks 01 → 04, each writing what the next reads. Requires `pandas`,
`numpy`, `matplotlib`, `scikit-learn`.

## 3. Findings

### Revenue fell 34.5% while bookings fell only 16.9% — the operator sells seats and then loses them

`docs/FINDINGS.md §2①`

| | 2024-25 | 2025-26 | Change |
|---|---|---|---|
| Revenue | ₹2,22,50,950 | ₹1,45,64,050 | **−₹76,86,900 (−34.5%)** |
| Bookings taken | 2,884 | 2,396 | −16.9% |
| `capacity_utilization` | 58.0% | **54.5%** | −3.5pp |
| `cancellation_rate` | 18.5% | **25.7%** | +7.2pp |

Revenue fell **twice as fast as volume**. That gap is the whole diagnosis: demand
softened somewhat, but the collapse came from fulfilment. In 2025-26 the shop took
2,396 bookings against 3,022 available slots and completed only 1,646 of them —
**750 booked seats (31%) evaporated** into cancellations and no-shows, with a
further 626 never sold at all.

This rules out the demand story and the weather story as sufficient explanations.
The problem is operational, and therefore fixable.

### Weather predicts *which* booking cancels — it does not explain *most* cancellations

`docs/FINDINGS.md §2②`

This one is easy to get backwards, and getting it backwards sends the effort to the
wrong place.

| | Rough/Closed days | Calm/Moderate days |
|---|---|---|
| Share of bookings | 14.0% | 86.0% |
| `cancellation_rate` | **54.7%** | 12.7% |
| Share of all cancellations | 41.1% | **58.9%** |

Both facts hold simultaneously. Bad weather makes any individual booking **four
times** more likely to cancel — but bad-weather days are only 14% of the calendar,
so **the majority of cancellations happen on perfectly diveable days**.

**795 cancellations (59.6%) are not attributable to weather — worth ₹79,77,635.**
That is the addressable pool, and it is where the recommendations point. A
weather-only model scores AUC 0.725 against the full model's 0.749: weather
dominates the *ranking*, but the commercial opportunity sits in the volume it
does not cover.

### The OTA channel became the growth engine and the leak at the same time

`docs/FINDINGS.md §2③`

OTA share of bookings: **8.5% → 17.8% → 29.4%**. It is now the second-largest
channel and the worst-performing one on every dimension measured.

| Channel | Bookings | Avg price | `cancellation_rate` | `no_show_rate` | Seats lost | `customer_ltv` |
|---|---|---|---|---|---|---|
| **OTA** | 1,377 | **₹8,167** | **27.8%** | **7.5%** | **486** | **₹9,533** |
| Walk-in | 1,541 | ₹11,090 | 13.8% | 3.5% | 266 | ₹14,197 |
| Referral | 891 | ₹10,046 | 13.9% | 4.5% | 164 | ₹13,060 |

OTA books **26% cheaper** than walk-in, cancels at **twice** the rate, no-shows at
more than twice, converts inquiries worst of any channel (47.9% vs 54.4% for Hotel
Partner), and produces customers worth **33% less over their lifetime**. It is the
only channel below ₹12,000 LTV; the other six cluster in a tight ₹12,173–₹14,197
band.

The shop has swapped its highest-value channel mix for its lowest-value one. That
is why `revenue_per_dive` fell from ₹4,683 to ₹4,173 **without a single price
change**.

### Course graduates stopped coming back

`docs/FINDINGS.md §2④`

`course_to_fundive_conversion`, by the season the course was taken: **39.5% → 16.1%
→ 4.8%**.<sup>†</sup>

<sup>†</sup> *This figure is right-censored — an April 2026 graduate has had weeks
to return while the 2023-24 cohort has had two years, so some decline is guaranteed
by the measurement window alone. Re-tested on a fixed 90-day window restricted to
customers observable at least that long, it reads **27.8% → 10.2% → 3.7%**. The
~7.5× collapse holds either way, so this is a real retention failure rather than an
artefact.*

This matters disproportionately because **Course is the largest revenue line at
42.3% of revenue (₹2,32,53,650)** — and its share of bookings is itself shrinking,
20.2% → 17.8% → 13.5%. The shop is contracting its most valuable product *and*
failing to convert the graduates it still produces.

Supporting evidence: `repeat_customer_rate` is 16.0%; 3,489 of 4,366 diving
customers (**79.9%**) never return for a second dive; and **1,129 customers (20.6%
of the file) never completed a dive at all**.

### The shop is losing the ability to explain its own losses

`docs/FINDINGS.md §2⑤`

Cancellations logged with **no reason at all**, as a share of cancellations:
**7.7% → 11.4% → 19.6%**. In the current season, 121 cancelled bookings have no
recorded cause.

Alongside that, **9.0% of customers have no acquisition channel captured, covering
₹50,96,000 — 9.3% of all revenue** that cannot be credited to anything.

This is a process defect, not a data defect. Nearly a fifth of this season's lost
seats cannot be investigated, and every channel-level decision above is being made
on 91% of the picture. It is also the cheapest thing on this list to fix.

### The model

`docs/FINDINGS.md §3`

**Cancellation-risk prediction**, chosen over RFM segmentation because 79.9% of
diving customers have exactly one completed booking — RFM's Frequency dimension
would have been a near-constant 1. Logistic regression with **out-of-time**
validation (train ≤ May 2025, test 2025-26), because a random split would leak
same-trip and same-weather-day information and flatter the result.

| Metric | Value |
|---|---|
| ROC AUC, out-of-time test | **0.749** (train 0.739 — no overfitting) |
| ROC AUC, weather-only benchmark | 0.725 |
| Brier score | 0.158 (base-rate baseline 0.202) |

**The usable result: the top 3 risk deciles — 719 bookings, 30% of the season —
contain 358 of 616 cancellations (58.1%)**, with decile 1 cancelling at 82.5%
(3.21× base rate) and precision of 49.8% at that threshold. More than half the
loss is reachable by touching under a third of the book.

Strongest factors, as odds ratios: `sea_condition = Closed` **24.7×**, `Rough`
**5.4×**, `OTA` **1.58×**; protective: `Walk-in` **0.51×**, `Referral` **0.52×**.

**Stated limits.** The model ranks well at the extremes but is noisy in the middle
(deciles 4–7 are not cleanly monotonic), so it should select a high-risk *group*,
never quote a probability for one booking. Non-weather features add only +0.023 AUC
over weather alone. And **lead time carries almost no signal** (16.6%–19.6% across
buckets) — a plausible-sounding driver the data does not support, recorded here so
no one builds a policy on it.

## 4. Recommendations

> **Provenance.** These are derived directly from the findings above and each cites
> its number, per brief §7. The formal Phase 5 deliverables — recommendation memo,
> To-Be process flow, user stories, RTM — are Phase 5 deliverables and are **not yet in
> this repo**. Reconcile against them when they land.

Ordered by value recoverable against effort to implement.

### R1 — Confirmation-call policy on the top 3 risk deciles

**Evidence:** the model's top 3 deciles hold **58.1% of all cancellations (358 of
616) in 30% of bookings**, precision 49.8%.
**Action:** run a confirmation contact 48 hours out for bookings in deciles 1–3.
**Ceiling:** the addressable non-weather pool is **795 cancellations worth
₹79,77,635**. Even a modest recovery rate is the largest single prize here, and it
requires no pricing or product change.

### R2 — Attach a deposit to OTA bookings, or renegotiate the channel

**Evidence:** OTA cancels at **27.8% vs 13.8% walk-in**, no-shows at 7.5% vs 3.5%,
lost **486 seats**, books 26% cheaper (₹8,167 vs ₹11,090), and yields **₹9,533 LTV
against ₹14,197**. Its share tripled, 8.5% → 29.4%.
**Action:** require a deposit on OTA specifically, or renegotiate commission to
reflect the true fulfilment cost. Redirect acquisition effort to Referral and
Walk-in (13.9% / 13.8% cancellation, ₹13,060 / ₹14,197 LTV).
**Caveat:** OTA is now 29.4% of volume. Suppress it without replacing the volume
and utilization falls further — this is a *re-pricing* move, not a shutdown.

### R3 — Automated re-engagement of course graduates inside 90 days

**Evidence:** `course_to_fundive_conversion` fell **39.5% → 4.8%** (censoring-
corrected: **27.8% → 3.7%**). **69% of everyone who ever returned did so within 90
days, median 49 days.** Course is **42.3% of revenue (₹2,32,53,650)**.
**Action:** trigger a fun-dive offer at ~day 30–45 post-certification, inside the
window where returns actually happen. The 90-day evidence sets the timing precisely.

### R4 — Make `cancellation_reason` and `acquisition_channel` mandatory at capture

**Evidence:** unexplained cancellations rose **7.7% → 19.6%** of the cancellation
book (121 bookings this season); **₹50,96,000 (9.3% of revenue)** has no channel
attached.
**Action:** required fields at booking and cancellation. Cheapest item on this
list, and it is a precondition for measuring whether R1–R3 worked.

### R5 — Right-size the sailing schedule to actual demand

**Evidence:** `capacity_utilization` is **54.5%** in 2025-26 and falling from 58.0%.
**626 seats were never sold at all**, on top of the 750 sold-then-lost.
**Action:** consolidate under-filled departures. `seasonality_index` shows extreme
concentration — January runs at 192 against a mean of 100, July and August are a
total shutdown — so capacity should flex with it rather than sit flat.
**Scale:** lifting 2025-26 to the 75% utilization target named in brief §9 requires
**620 more completed seats, worth ₹62,26,569** at the mean completed-booking value
of ₹10,035. *(75% is the brief's stated target, not a forecast from this analysis.)*

### What these numbers assume

Four caveats carried forward from [`docs/FINDINGS.md`](docs/FINDINGS.md), all of
which change the figures above if resolved differently:

1. **`booking_conversion_rate` numerator** — read as *inquiry produced a booking*
   (**51.3%**). Net of later cancellation it is **39.3%**, and 2025-26 falls to
   30.1%. Phase 5 must pick one.
2. **No deposit model is specified in the brief**, so cancelled bookings are valued
   at zero revenue. If the shop already takes deposits, every loss figure is an
   overstatement.
3. **`revenue_per_customer` and `customer_ltv`** are the same calculation as
   literally defined in §3; the denominators used here are documented in FINDINGS.
4. **"Shoulder" months are an assumption** — §4 leaves them undefined. Affects the
   trading-season cut only, not any headline KPI.

## 5. Dashboard

Build spec and export files: [`dashboard/DASHBOARD_SPEC.md`](dashboard/DASHBOARD_SPEC.md).

Five CSVs form a star schema — `fact_bookings`, `fact_trips`, `fact_inquiries`,
`dim_customers`, `dim_date` — plus a pre-computed `kpi_summary` for the cards.
Four pages: executive summary, seasonality and utilization, cancellation breakdown,
revenue by product and channel. Season slicer on every page.

**One modelling trap is called out in the spec:** `capacity_utilization` divides by
capacity at *trip* grain. Sum `boat_capacity` off the booking rows instead and each
boat's capacity gets multiplied by the seats sold on it — the KPI reads roughly 10%
instead of 59.5%. Capacity lives in `fact_trips` for exactly this reason.

_Built in Power BI by Anshhika (Phase 4) — link to follow._

---

## Repo layout

```
.
├── README.md              # this case study
├── PROJECT_BRIEF.md       # source of truth: scope, schema, KPI dictionary
├── data/
│   ├── generate_data.py   # synthetic raw-data generator
│   ├── raw/               # untouched messy data — CSV + SQLite
│   └── clean/             # post-cleaning — CSV + SQLite (PK/FK) + audit trail
├── sql/                   # extraction queries, one file per KPI group
├── notebooks/             # 01 cleaning · 02 EDA+KPIs · 03 model · 04 export
├── dashboard/             # star-schema CSVs + DASHBOARD_SPEC.md
└── docs/                  # FINDINGS.md (+ BRD, flows, user stories, RTM to follow)
```

## The ten KPIs

Names exactly as fixed by [`PROJECT_BRIEF.md`](PROJECT_BRIEF.md) §3. Full table
with per-season splits in [`docs/FINDINGS.md`](docs/FINDINGS.md) §1.

| KPI | Overall | 2024-25 | 2025-26 |
|---|---|---|---|
| `capacity_utilization` | 59.5% | 58.0% | **54.5%** |
| `booking_conversion_rate` | 51.3% | 53.1% | **43.7%** |
| `cancellation_rate` | 18.6% | 18.5% | **25.7%** |
| `no_show_rate` | 4.8% | 5.0% | **5.6%** |
| `repeat_customer_rate` | 16.0% | — | — |
| `course_to_fundive_conversion` | 21.5% | 16.1% | **4.8%** |
| `revenue_per_customer` | ₹10,000 | ₹11,601 | **₹9,588** |
| `revenue_per_dive` | ₹4,450 | ₹4,463 | **₹4,173** |
| `customer_ltv` | ₹12,624 | — | — |
| `seasonality_index` | Jan 192 · Dec 179 · Jul–Aug 0 | | |

Currency is INR throughout. 2023-24 is a **half** season (Jan–May 2024): rates are
comparable across all three, volumes are not, so every trend claim above is made on
the two full seasons.

## Reproducing

```bash
python data/generate_data.py          # deterministic — seed 42, stdlib only
jupyter lab notebooks/                # run 01 → 04 in order
```

---

### Summary framings

**Data analyst** — Built an end-to-end dive-operator analytics pipeline (SQL,
Python, Power BI) on ~7.2K bookings; isolated ₹79.8 L of cancellation loss that
weather does not explain and a ₹62.3 L capacity gap against 54.5% utilization, and
shipped a cancellation-risk model (out-of-time AUC 0.749) that concentrates 58% of
cancellations into 30% of bookings.

**Business analyst** — Diagnosed a 34.5% single-season revenue decline end-to-end,
separating a 16.9% volume fall from a fulfilment failure that lost 31% of booked
seats; recommended a risk-targeted confirmation workflow, an OTA deposit policy and
a 90-day course-graduate re-engagement loop, each tied to a computed figure.
