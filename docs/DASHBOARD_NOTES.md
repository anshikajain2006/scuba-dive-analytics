# Dashboard Handoff Note

Project: scuba-dive-analytics (local folder: Scuba). Phase 5 handoff for the
Phase 4 build.

## Status

> **Update:** an HTML dashboard now replaces the Power BI deliverable. See the note at the end of this file.

**The Power BI dashboard has not been built yet.** The export files and the full
build spec are ready. The build is owned by **Anshhika** (PROJECT_BRIEF.md §5).
The complete specification, covering the data model, DAX measures, visuals and
build checklist, is in [`dashboard/DASHBOARD_SPEC.md`](../dashboard/DASHBOARD_SPEC.md).
This note is a summary of it and does not replace it.

## Pages

| Page | Purpose | Key visuals |
|---|---|---|
| **1 · Executive summary** | Show where 2025-26 stands against 2024-25 on all ten KPIs | 10 KPI cards with season-on-season deltas. Season slicers. Bookings vs `capacity_utilization` trend with a 75% target line |
| **2 · Seasonality and utilization** | Show when demand happens, and how many seats go unsold or are lost | `seasonality_index` bars. Season × month utilization heatmap. Empty-seat waterfall (never sold vs sold then lost) |
| **3 · Cancellation breakdown** | Show that most cancellations are not weather and can be addressed | `cancellation_rate` by reason (Unknown in red). Rough/Closed vs Calm/Moderate split cards. Risk-decile 1–3 table (2025-26 only) |
| **4 · Revenue by product and channel** | Show the change in channel mix and the case for the OTA deposit | Revenue by product donut. Revenue by channel including `Unknown`. Channel-mix 100% column. Price vs cancellation scatter |

## Files ready for import (`dashboard/`)

| File | Grain | Rows |
|---|---|---|
| `fact_bookings.csv` | 1 booking | 7,171 |
| `fact_trips.csv` | 1 boat departure | 922 |
| `fact_inquiries.csv` | 1 inquiry | 10,845 |
| `dim_customers.csv` | 1 customer | 5,495 |
| `dim_date.csv` | 1 calendar day | 882 |
| `kpi_summary.csv` | 1 KPI × scope | card source |
| `utilization_heatmap.csv` | season × month | 25 |

Regenerate all of them with `notebooks/04_dashboard_export.ipynb`.

## Sanity check

With no filters applied, **`capacity_utilization` must read 59.5%** (5,493 completed
seats ÷ 9,230 boat slots). If it reads about 10%, the denominator is being summed
from `fact_bookings` instead of `fact_trips`. See DASHBOARD_SPEC §1. Total revenue
must read **₹5,49,50,350**.

## Expected measure values

The values below come from `kpi_summary.csv` and match [`FINDINGS.md`](FINDINGS.md) §1.

| KPI | Overall (no filter) | 2024-25 | 2025-26 |
|---|---|---|---|
| `capacity_utilization` | 59.5% | 58.0% | 54.5% |
| `booking_conversion_rate` | 51.3% ⚠ | 53.1% | 43.7% |
| `cancellation_rate` | 18.6% | 18.5% | 25.7% |
| `no_show_rate` | 4.8% | 5.0% | 5.6% |
| `repeat_customer_rate` | 16.0% | 13.5%¹ | 8.0%¹ |
| `course_to_fundive_conversion` | 21.5% | 16.1% | 4.8% |
| `revenue_per_customer` | ₹10,000 ⚠ | ₹11,601 | ₹9,588 |
| `revenue_per_dive` | ₹4,450 | ₹4,463 | ₹4,173 |
| `customer_ltv` | ₹12,624 ⚠ | — | — |
| `seasonality_index` | Jan 192 · Feb 171 · Mar 163 · Apr 121 · May 109 · Jun 9 · Jul 0 · Aug 0 · Sep 9 · Oct 116 · Nov 130 · Dec 179 | | |
| Total revenue | ₹5,49,50,350 | ₹2,22,50,950 | ₹1,45,64,050 |

¹ Within-season variant (FINDINGS §1, footnote 1).

⚠ **Open definitions ([`BRD.md`](BRD.md) §6), to resolve before the cards are final:**
- **OQ-1.** `booking_conversion_rate` is shown as *inquiry produced a booking*. The
  "net of cancellations" alternative (39.3% overall) is in `kpi_summary.csv` as
  `booking_conversion_rate_net`.
- **OQ-3.** `revenue_per_customer` and `customer_ltv` use different denominators
  (5,495 vs 4,353 customers). Caption both cards with their denominator.
- **OQ-4.** The `season` slicer's Peak/Shoulder split is an assumption.

## README placeholder to update

[`README.md`](../README.md) §5 ends with:

> _Built in Power BI by Anshhika (Phase 4) — link to follow._

When the `.pbix` is built, replace "link to follow" with the published report URL
(or the path to the `.pbix` in `dashboard/`), add 1–2 screenshots to `dashboard/`,
and tick the checklist in DASHBOARD_SPEC §7.

HTML dashboard built at dashboard/index.html. Self-contained, no Power BI required. Opens locally in any browser.
