# Findings — Phase 3

Every number below was computed from `data/clean/` by the notebooks in
`notebooks/`, and independently reproduced by the queries in `sql/`. KPI names
are exactly as defined in **PROJECT_BRIEF.md §3**. Currency is INR (§7).

**This file is the evidence base for the Phase 5 recommendations.** Brief §7
requires every recommendation to cite a specific number produced here — so each
figure carries its source. Nothing below is estimated, rounded up, or asserted
without a query behind it.

| | |
|---|---|
| Dataset | 7,171 bookings, 5,495 customers, 922 trips, 10,845 inquiries |
| Period | 2024-01-01 → 2026-05-31 (2.5 seasons) |
| Total revenue | **₹5,49,50,350** (Completed bookings only) |
| Reproduce | `notebooks/01_cleaning` → `02_eda_kpis` → `03_model` → `04_dashboard_export` |

### Two things to keep in mind when reading these numbers

1. **2023-24 is a half season** (Jan–May 2024 only). *Rates* are comparable
   across all three seasons; *volumes* are not. Every trend claim below is made
   on the two full seasons, 2024-25 vs 2025-26.
2. **Revenue counts Completed bookings only.** Cancelled and no-show bookings
   earn nothing (assumed: no deposit policy exists today — see Decisions, A-OQ2). The 23 bookings with
   impossible prices are excluded from revenue but still counted in every volume
   and rate KPI — see [Data quality](#data-quality-what-was-fixed-and-what-cannot-be).

---

## 1. The ten KPIs

`source: notebooks/02_eda_kpis.ipynb · sql/01–05`

| KPI | Overall | 2023-24 (half) | 2024-25 | 2025-26 | Direction |
|---|---|---|---|---|---|
| `capacity_utilization` | **59.5%** | 68.3% | 58.0% | **54.5%** | ▼ falling |
| `booking_conversion_rate`² | **39.3%** | 52.9% | 40.6% | **30.1%** | ▼ falling |
| `cancellation_rate` | **18.6%** | 9.7% | 18.5% | **25.7%** | ▲ rising (bad) |
| `no_show_rate` | **4.8%** | 3.5% | 5.0% | **5.6%** | ▲ rising (bad) |
| `repeat_customer_rate` | **16.0%** | 27.4%¹ | 13.5%¹ | 8.0%¹ | ▼ falling |
| `course_to_fundive_conversion` | **21.5%** | 39.5% | 16.1% | **4.8%** | ▼ collapsing |
| `revenue_per_customer` | **₹10,000** | ₹15,330 | ₹11,601 | **₹9,588** | ▼ falling |
| `revenue_per_dive` | **₹4,450** | ₹4,683 | ₹4,463 | **₹4,173** | ▼ falling |
| `customer_ltv`³ | **₹10,000** | — | — | — | — |
| `seasonality_index` | see below | | | | |

¹ Per-season figures for `repeat_customer_rate` are the *within-season* variant
(customers diving more than once inside that season). The headline 16.0% is the
brief's definition: 877 of 5,495 customers have more than one completed booking,
across the whole period.

² **Definition:** `booking_conversion_rate` = inquiries that became a
**completed** dive ÷ all inquiries. The business cares about inquiries that turn
into dives, not inquiries that turned into any booking. *Alternate definition
(all bookings), which counts a later-cancelled booking as a conversion:* 51.3%
overall · 61.2% · 53.1% · 43.7%.

³ Under the brief's definitions `revenue_per_customer` and `customer_ltv` are
equivalent calculations (total revenue ÷ all 5,495 customers), so both report
₹10,000. A true LTV model would require cohort-level retention data not
available in this dataset.

**`seasonality_index`** (mean = 100, across all twelve calendar months):

| Jan | Feb | Mar | Apr | May | Jun | Jul | Aug | Sep | Oct | Nov | Dec |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **192** | 171 | 163 | 121 | 109 | 9 | 0 | 0 | 9 | 116 | 130 | **179** |

January runs at nearly twice the annual average; July and August are a total
shutdown. Calendar coverage is uneven (Jan–May occur three times in the window,
Oct–Dec twice), so the index uses *mean bookings per occurrence* of each month,
not raw totals.

**Channel comparisons use lifetime revenue per *diving* customer** (customers
with at least one completed dive, `sql/03 Q6`), not `customer_ltv`. Across all
4,366 diving customers that average is ₹12,624. It is context for comparing
channels, not a §3 KPI.

---

## 2. The five biggest insights

### ① Revenue fell 34.5% in one season, and it is a *retention and fulfilment* problem, not a demand problem

`source: 02_eda_kpis.ipynb · sql/04 Q1, sql/01 Q2`

| | 2024-25 | 2025-26 | Change |
|---|---|---|---|
| Revenue | ₹2,22,50,950 | ₹1,45,64,050 | **−₹76,86,900 (−34.5%)** |
| Bookings taken | 2,884 | 2,396 | −16.9% |
| `capacity_utilization` | 58.0% | 54.5% | −3.5pp |
| `cancellation_rate` | 18.5% | 25.7% | +7.2pp |

Revenue fell twice as fast as booking volume. The shop is not simply selling
fewer seats — it is selling seats and then losing them. In 2025-26 it took 2,396
bookings against 3,022 available slots but only completed 1,646 of them: **750
booked seats (31%) evaporated** into cancellations and no-shows, and a further
626 were never sold at all.

Closing 2025-26 utilization to the 75% target named in brief §9 requires **620
more completed seats**, worth **₹62,26,569** at the mean completed-booking value
of ₹10,035.

### ② Weather is the strongest predictor of cancellation but explains a minority of the volume

`source: sql/06 Q1–Q3 · 03_model_cancellation_risk.ipynb`

This distinction decides where the effort goes, and it is easy to get backwards.

| | Rough/Closed days | Calm/Moderate days |
|---|---|---|
| Share of bookings | 14.0% | 86.0% |
| `cancellation_rate` | **54.7%** | 12.7% |
| Share of all cancellations | 41.1% | **58.9%** |

Both statements are true at once: bad weather makes any individual booking
**four times** more likely to cancel, *and* the majority of cancellations happen
on perfectly diveable days — simply because most days are diveable. Weather is
the largest single logged reason (40.4% of cancellations) but not the largest
block of loss.

**795 cancellations (59.6%) are not attributed to weather — worth ₹79,77,635.**
That is the addressable pool. A weather-only model reaches AUC 0.725 against the
full model's 0.749, confirming weather dominates the *ranking*; the commercial
opportunity is in the volume it does not cover.

### ③ The OTA channel is both the growth engine and the leak

`source: sql/06 Q4–Q5 · sql/04 Q3`

OTA share of bookings: **8.5% → 17.8% → 29.4%** across the three seasons. It is
now the second-largest channel, and it is the worst-performing one on every
dimension:

| Channel | Bookings | Avg price | `cancellation_rate` | `no_show_rate` | Seats lost | Lifetime revenue / diving customer |
|---|---|---|---|---|---|---|
| **OTA** | 1,377 | **₹8,167** | **27.8%** | **7.5%** | **486** | **₹9,533** |
| Walk-in | 1,541 | ₹11,090 | 13.8% | 3.5% | 266 | ₹14,197 |
| Referral | 891 | ₹10,046 | 13.9% | 4.5% | 164 | ₹13,060 |

OTA books at a **26% lower price** than walk-in, cancels at **twice** the rate,
no-shows at more than twice, converts inquiries into completed dives worst of
any channel (`booking_conversion_rate` 30.9% vs 43.6% for Referral, `sql/02 Q3`),
and produces customers worth **₹9,533 lifetime against ₹14,197 for a walk-in —
33% less**. It is the only channel whose lifetime revenue per diving customer
falls below ₹12,000; the other six sit in a tight ₹12,173–₹14,197 band.

The shop has replaced its highest-value channel mix with its lowest-value one —
which is why `revenue_per_dive` fell from ₹4,683 to ₹4,173 even though the price
list did not change.

### ④ Retention has collapsed, and the collapse survives a censoring correction

`source: 02_eda_kpis.ipynb · sql/03 Q3–Q4`

`course_to_fundive_conversion` by the season the course was taken: **39.5% →
16.1% → 4.8%**.

This number is right-censored — a customer who certified in April 2026 has had
weeks to return, while the 2023-24 cohort has had two years — so it was re-tested
on a **fixed 90-day window**, restricted to customers observable for at least 90
days (69% of all returners come back inside 90 days; median 49 days):

| Cohort | Unrestricted | 90-day like-for-like |
|---|---|---|
| 2023-24 (half) | 39.5% | **27.8%** |
| 2024-25 | 16.1% | **10.2%** |
| 2025-26 | 4.8% | **3.7%** |

The decline holds — roughly a **7.5× drop** either way. This is a real retention
failure, not a measurement artefact.

Supporting evidence: `repeat_customer_rate` is 16.0%; 3,489 of 4,366 diving
customers (79.9%) never come back for a second dive; and **1,129 customers
(20.6% of the file) never completed a dive at all**. Course share of bookings
fell 20.2% → 17.8% → 13.5% while Course remains the largest revenue line at
**42.3% of revenue (₹2,32,53,650)** — the shop is shrinking its most valuable
product and failing to convert the graduates it does produce.

### ⑤ The shop is losing the ability to explain its own losses

`source: sql/02 Q6 · sql/04 Q3 · 01_cleaning.ipynb`

Cancellations logged with **no reason at all**, as a share of cancellations:
**7.7% → 11.4% → 19.6%**. As a share of all bookings, unexplained cancellations
went 0.74% → 2.12% → **5.05%**.

In the current season, 121 cancelled bookings have no recorded cause. On top of
that, **9.0% of customers have no `acquisition_channel` captured, covering
₹50,96,000 — 9.3% of all revenue** that cannot be attributed to any channel.

This is a process defect, not a data defect: nearly a fifth of the current
season's lost seats cannot be investigated, and a tenth of revenue cannot be
credited to whatever produced it. Any channel-level decision is being made on
91% of the picture, and the missing 9% is not random — it is concentrated in
whatever booking path skips the field.

---

## 3. The model

`source: notebooks/03_model_cancellation_risk.ipynb · data/clean/model_summary.csv`

**Cancellation-risk prediction** was chosen over RFM segmentation. RFM needs a
usable Frequency dimension, and 79.9% of diving customers have exactly one
completed booking — Frequency would be a near-constant 1, producing segments
driven by a single spend variable. Cancellation is also the larger and more
controllable leak.

Logistic regression, **out-of-time** validation (train 2023-24 + 2024-25, test
2025-26). A random split would leak same-trip and same-weather-day information
between train and test and flatter the result.

| Metric | Value |
|---|---|
| ROC AUC, out-of-time test | **0.749** (train 0.739 — no overfitting) |
| ROC AUC, weather-only benchmark | 0.725 |
| Brier score | 0.158 (vs 0.202 base-rate baseline) |
| Train / test base rate | 15.0% → 25.7% |

**The operationally useful result:** ranking the current season by predicted
risk, the **top 3 deciles — 719 bookings, 30% of the season — contain 358 of 616
cancellations (58.1%)**, at 3.21× the base rate in decile 1 (82.5% of decile-1
bookings cancelled). At that threshold precision is 49.8%: one in two flagged
bookings genuinely cancels.

That is a workable target list for confirmation calls or deposits — 58% of the
loss is reachable by touching under a third of the book.

Strongest risk factors (odds ratios): `sea_condition = Closed` **24.7×**,
`Rough` **5.4×**, `OTA` **1.58×**; protective: `Walk-in` **0.51×**, `Referral`
**0.52×**.

**Honest limitations.** The model ranks well at the extremes but is noisy in the
middle — deciles 4–7 are not cleanly monotonic (decile 5 actually cancels more
than decile 4), so it should be used to select a high-risk *group*, not to quote
a probability for an individual booking. Non-weather features add only +0.023
AUC over weather alone; their value is in identifying *which* good-weather
bookings are fragile, not in beating the weather signal. **Lead time carries
almost no signal** (cancellation ranges only 16.6%–19.6% across lead-time
buckets) — a plausible-sounding driver that the data does not support, and worth
stating so Phase 5 does not build a policy on it.

---

## Data quality: what was fixed, and what cannot be

`source: notebooks/01_cleaning.ipynb · data/clean/cleaning_audit.csv · sql/00`

7,199 raw rows → **7,171 clean rows**. Only the 28 duplicates were removed; no
row was dropped for any other reason.

| Defect | Volume | Treatment |
|---|---|---|
| Fully duplicated `booking_id` rows | 28 | Dropped. All verified byte-identical — zero conflicting ids, so dedupe is lossless |
| Mixed date formats | 3 formats, 7,171 rows | Parsed explicitly; `01/03/2024` read day-first |
| `status` spellings | 12 → 3 | Normalised |
| `dive_type` spellings | 14 → 3 | Normalised (`DSD`, `PADI Course` → canonical) |
| `nationality` strings | 54 → 12 | Explicit map (`IN`/`Indian`/`india`, `England`→UK, `Holland`→Netherlands) |
| `cert_level` strings | 26 → 5 | Normalised |
| Impossible prices | 23 (15 negative, 8 extreme) | **Quarantined, row kept.** Price nulled, booking still counts for volume KPIs |
| Impossible ages | 35 (ages 3–6 and 115–121) | Nulled, not clipped — clipping would invent a plausible age |
| Missing `age` | 432 (7.9%) | Left missing; used descriptively only |
| Cancelled with no reason | 196 | → explicit `Unknown` category, **not imputed** |
| Missing `acquisition_channel` | 497 (9.0%) | → explicit `Unknown`, not dropped |

Referential integrity is clean: zero orphans on every join, and no trip is booked
beyond its `boat_capacity`.

**What cannot be recovered.** The 196 unexplained cancellations and the 497
missing channels are *permanently* lost information — imputing them would
manufacture the exact quantities insight ⑤ is about. They are carried as
`Unknown` so their size stays visible in every cut.

---

## Decisions on the Phase 3 open questions

All four are resolved and recorded in [`BRD.md`](BRD.md) §6.

1. **A-OQ1 · `booking_conversion_rate` = inquiries that became a completed
   dive** — **39.3%** overall, 30.1% in 2025-26 (`sql/02 Q1`). The alternate
   definition (all bookings, 51.3%) is kept in `sql/02 Q2` for reference only.
2. **A-OQ2 · No deposit policy exists in the current state.** Cancelled and
   no-show bookings are valued at ₹0, and R2 impact figures assume 0% recovery
   on cancelled bookings.
3. **A-OQ3 · `revenue_per_customer` = `customer_ltv` = ₹10,000.** Under the
   brief's definitions these are equivalent calculations. A true LTV model would
   require cohort-level retention data not available in this dataset.
4. **A-OQ4 · Trading seasons:** Peak = Dec–Mar · Shoulder = Apr–Jun + Sep–Nov · Monsoon-Closed (off-peak) = Jul–Aug.
   Assigned from the dive month in the reporting layer only. On this cut,
   `capacity_utilization` is 63.7% in Peak and 53.1% in Shoulder; no trips sail
   in Jul–Aug. No headline KPI changes.
