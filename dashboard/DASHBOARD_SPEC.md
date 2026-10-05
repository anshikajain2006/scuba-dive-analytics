# Dashboard specification

**Phase 4.** Anshika Jain produced this spec, the export files and the dashboard
itself: [`index.html`](index.html), a self-contained HTML page.

KPI names are fixed by **PROJECT_BRIEF.md §3** and must appear on the canvas
exactly as written — `capacity_utilization`, not "Capacity Utilisation %".
Currency is INR throughout (§7).

---

## 1. Data model

Load the five CSVs in this folder. They form a star schema; do **not** flatten
them into one table.

```
              dim_date (882)                 dim_customers (5,495)
                   │ date                          │ customer_id
                   │                               │
      ┌────────────┼───────────────┬───────────────┘
      │            │               │
fact_trips    fact_bookings   fact_inquiries
   (922)         (7,171)         (10,845)
      └── trip_id ──┘
```

| Table | Grain | Rows | Key columns |
|---|---|---|---|
| `fact_bookings.csv` | 1 booking | 7,171 | `booking_id`, → `customer_id`, `trip_id`, `dive_date` |
| `fact_trips.csv` | 1 boat departure | 922 | `trip_id`, → `dive_date` |
| `fact_inquiries.csv` | 1 inquiry | 10,845 | `inquiry_id`, → `converted_booking_id` |
| `dim_customers.csv` | 1 customer | 5,495 | `customer_id` |
| `dim_date.csv` | 1 calendar day | 882 | `date` |
| `kpi_summary.csv` | 1 KPI × scope | — | card source |
| `utilization_heatmap.csv` | season × month | 25 | pre-shaped matrix |

Relationships — all single-direction, many-to-one:

* `fact_bookings.customer_id` → `dim_customers.customer_id`
* `fact_bookings.trip_id` → `fact_trips.trip_id`
* `fact_bookings.dive_date` → `dim_date.date`
* `fact_trips.dive_date` → `dim_date.date`
* `fact_inquiries.inquiry_date` → `dim_date.date`

Mark `dim_date` as the date table, keyed on `date`.

### ⚠ The one modelling mistake that will break this dashboard

`capacity_utilization` divides by `SUM(boat_capacity)` at **trip** grain.
`boat_capacity` is present on `fact_bookings` for convenience, but **summing it
there multiplies each boat's capacity by the number of seats sold on it** and the
KPI reads far too low. Always take the denominator from `fact_trips`:

```
capacity_utilization = SUM(fact_trips.completed_seats) / SUM(fact_trips.boat_capacity)
```

Sanity check after building: with no filters this must read **59.5%**. If it
reads roughly 10% the denominator is coming from the wrong table.

---

## 2. Measures

Pre-computed 0/1 flags (`is_completed`, `is_cancelled`, `is_no_show`) exist so
rate measures are plain averages and cannot be mis-specified.

| Measure | Definition | No-filter value |
|---|---|---|
| `capacity_utilization` | `SUM(fact_trips.completed_seats) / SUM(fact_trips.boat_capacity)` | 59.5% |
| `booking_conversion_rate` | `SUM(fact_inquiries.is_converted) / COUNT(fact_inquiries)` | 51.3% |
| `cancellation_rate` | `SUM(fact_bookings.is_cancelled) / COUNT(fact_bookings)` | 18.6% |
| `no_show_rate` | `SUM(fact_bookings.is_no_show) / COUNT(fact_bookings)` | 4.8% |
| `repeat_customer_rate` | `SUM(dim_customers.is_repeat_customer) / COUNT(dim_customers)` | 16.0% |
| `course_to_fundive_conversion` | `SUM(dim_customers.course_then_fundive) / SUM(dim_customers.took_course)` | 21.5% |
| `revenue_per_customer` | `SUM(fact_bookings.revenue_inr) / COUNT(dim_customers)` | ₹10,000 |
| `revenue_per_dive` | `SUM(fact_bookings.revenue_inr) / SUM(fact_bookings.completed_dives)` | ₹4,450 |
| `customer_ltv` | `AVG(dim_customers.lifetime_revenue_inr)`, blanks excluded | ₹12,624 |
| `seasonality_index` | see §4 | Jan = 192 |

`revenue_inr` is already blank on cancelled, no-show and price-quarantined rows,
so `SUM(revenue_inr)` is the correct revenue measure everywhere. **Never
substitute `SUM(price_inr)`** — that books money the shop never took.

---

## 3. Page 1 — Executive summary

**KPI card row** (10 cards, two rows of five). Each shows the current value, and
a season-over-season delta versus 2024-25 as the comparison:

```
┌───────────────────┬───────────────────┬───────────────────┬───────────────────┬───────────────────┐
│ capacity_         │ cancellation_rate │ no_show_rate      │ booking_          │ revenue_per_dive  │
│ utilization       │                   │                   │ conversion_rate   │                   │
│   54.5%   ▼ 3.5pp │   25.7%   ▲ 7.2pp │    5.6%   ▲ 0.6pp │   43.7%   ▼ 9.4pp │  ₹4,173   ▼ 6.5%  │
├───────────────────┼───────────────────┼───────────────────┼───────────────────┼───────────────────┤
│ repeat_customer_  │ course_to_fundive │ revenue_per_      │ customer_ltv      │ Total revenue     │
│ rate              │ _conversion       │ customer          │                   │                   │
│   16.0%           │    4.8%   ▼11.3pp │  ₹9,588   ▼17.4%  │ ₹12,624           │ ₹1.46 Cr ▼ 34.5%  │
└───────────────────┴───────────────────┴───────────────────┴───────────────────┴───────────────────┘
```

Deltas shown are 2025-26 vs 2024-25. Colour direction: for
`cancellation_rate` / `no_show_rate`, up is **bad** (red); for everything else up
is good.

**Season slicer** (required by brief §8). Two slicers, both from `dim_date`:

* `season_year` — `2023-24 (half)` · `2024-25` · `2025-26`
* `season` — `Peak` · `Shoulder` · `Monsoon-Closed`

Default `season_year` to `2024-25` + `2025-26` (the two full seasons).
**Put a caption under the slicer: "2023-24 is a half season (Jan–May 2024 only)
— rates are comparable, volumes are not."** Without it someone will read the
half season as a collapse in demand.

**Trend line** — dual axis by `dim_date.year_month`: bookings (columns) and
`capacity_utilization` (line, with a 75% target reference line).

---

## 4. Page 2 — Seasonality and utilization

**`seasonality_index` bar chart.** X = calendar month, Y = index, reference line
at 100.

Index over **all twelve** calendar months, with the two closed months (Jul, Aug)
contributing 0, so it averages 100 across a full trading year. Calendar coverage
is uneven — Jan–May occur three times in the window, Oct–Dec twice — so the
index is built on *mean bookings per occurrence*, not raw totals. Use the
pre-computed values rather than recalculating in the dashboard:

| Month | Jan | Feb | Mar | Apr | May | Jun | Jul | Aug | Sep | Oct | Nov | Dec |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `seasonality_index` | 192 | 171 | 163 | 121 | 109 | 9 | 0 | 0 | 9 | 116 | 130 | 179 |

**Utilization heatmap.** Matrix visual from `utilization_heatmap.csv`:
rows = `season_year`, columns = `month_name`, values = `capacity_utilization`,
conditional formatting red→green over 30%–85%, blank for months not traded.

Expected shape — the whole grid is dimming season over season:

| | Jan | Feb | Mar | Apr | May | Oct | Nov | Dec |
|---|---|---|---|---|---|---|---|---|
| 2023-24 (half) | 70.7 | 69.2 | 68.3 | 67.0 | 63.3 | — | — | — |
| 2024-25 | 61.9 | 63.6 | 61.7 | 55.1 | 53.1 | 55.3 | 59.0 | 59.0 |
| 2025-26 | 61.2 | 58.3 | 61.6 | 49.5 | 50.6 | 55.1 | 52.2 | 61.1 |

**Empty-seat waterfall.** From `fact_trips`: `boat_capacity` → `never_sold_seats`
→ `cancelled_seats` → `no_show_seats` → `completed_seats`. This separates *never
sold* from *sold then lost*, which are different problems with different fixes.

---

## 5. Page 3 — Cancellation breakdown

**Stacked column, `cancellation_rate` by `cancellation_reason` across
`season_year`.** Denominator is all bookings so the segments sum to the headline
rate. Order and colour: Weather (blue-grey), Customer (amber), Medical (green),
**Unknown (red — it is a data-capture failure, not a cause)**.

| | Weather | Customer | Medical | Unknown | total |
|---|---|---|---|---|---|
| 2023-24 (half) | 3.91% | 3.23% | 1.80% | 0.74% | 9.7% |
| 2024-25 | 7.98% | 6.52% | 1.91% | 2.12% | 18.5% |
| 2025-26 | 9.77% | 8.06% | 2.84% | 5.05% | 25.7% |

**Weather split — the headline visual on this page.** Two cards side by side:

```
   Rough/Closed days              Calm/Moderate days
   14.0% of bookings              86.0% of bookings
   41.1% of cancellations         58.9% of cancellations
   cancellation_rate 54.7%        cancellation_rate 12.7%
```

The point this must land: bad weather cancels a booking four times more often,
but most cancellations *by volume* happen on perfectly diveable days. Label the
right-hand card **"addressable"**.

**Cancellation risk table.** `fact_bookings` filtered to
`risk_decile` ≤ 3, columns: `dive_date`, `dive_type`, `acquisition_channel`,
`sea_condition`, `cancellation_risk`. Scores exist for 2025-26 only (the model's
out-of-time test window) — caption that, or it reads as missing data.

---

## 6. Page 4 — Revenue by product and channel

**Revenue by product** — donut on `dive_type`:
Course ₹2.33 Cr (42.3%) · Fun Dive ₹2.24 Cr (40.8%) · Discovery Dive ₹0.93 Cr (16.9%).

**Revenue by channel** — bar on `dim_customers.acquisition_channel`, sorted
descending, with `cancellation_rate` on a secondary axis.

Include the **`Unknown` channel bucket** (₹50.96 L, 9.3% of revenue). It is the
9.0% of customers whose channel was never captured. Do not hide or redistribute
it — the size of the unattributable block is itself a finding. Caption it
*"channel not captured at booking"*.

**Channel mix shift** — 100% stacked column, `acquisition_channel` share by
`season_year`. The OTA band growing 8.5% → 17.8% → 29.4% is the single most
important thing on this page.

**Price vs cancellation scatter** — X = `avg_price_inr`, Y = `cancellation_rate`,
bubble = bookings, one point per channel. OTA sits bottom-right-inverted: lowest
price *and* highest cancellation. That quadrant is the argument for the deposit
policy.

---

## 7. Build checklist

- [ ] All ten §3 KPI names appear exactly as written in the brief
- [ ] `capacity_utilization` with no filters reads **59.5%** (not ~10%)
- [ ] `season_year` slicer present on every page (brief §8 minimum)
- [ ] Half-season caption present under the season slicer
- [ ] Total revenue reads **₹5,49,50,350**
- [ ] `Unknown` appears as a visible category in both channel and reason visuals
- [ ] Risk scores captioned as 2025-26 only
- [ ] Currency formatted as INR (₹), lakh/crore grouping for large values

Regenerate every export with `notebooks/04_dashboard_export.ipynb`.
