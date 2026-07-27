# SQL extraction queries

Phase 3 extraction layer. KPI names match **PROJECT_BRIEF.md section 3** exactly.

| File | Runs against | Produces |
|---|---|---|
| `00_data_quality_raw.sql` | `data/raw/dive_ops_raw.db` | Profiles the mess the cleaning pipeline had to fix |
| `01_capacity_utilization.sql` | `data/clean/dive_ops_clean.db` | `capacity_utilization` overall, by season, by month, by trip |
| `02_conversion_cancellation_noshow.sql` | clean | `booking_conversion_rate`, `cancellation_rate` (split by reason), `no_show_rate` |
| `03_retention_repeat_course.sql` | clean | `repeat_customer_rate`, `course_to_fundive_conversion`, `customer_ltv` |
| `04_revenue_kpis.sql` | clean | `revenue_per_customer`, `revenue_per_dive`, revenue by product and channel |
| `05_seasonality_index.sql` | clean | `seasonality_index` (mean = 100) |
| `06_cancellation_drivers.sql` | clean | Weather and channel drivers behind the cancellation rate |

## Running them

```bash
sqlite3 data/clean/dive_ops_clean.db < sql/01_capacity_utilization.sql
sqlite3 data/raw/dive_ops_raw.db     < sql/00_data_quality_raw.sql
```

Or from Python:

```python
import sqlite3, pandas as pd
con = sqlite3.connect("data/clean/dive_ops_clean.db")
pd.read_sql(open("sql/01_capacity_utilization.sql").read().split(";")[0], con)
```

## Two things that will bite you

**Capacity is at trip grain.** `capacity_utilization` divides by `SUM(boat_capacity)`
over *trips*. Joining `trips` to `bookings` and summing `boat_capacity` multiplies
each boat's capacity by the seats sold on it. Every query here aggregates to trip
grain first — see the `trip_seats` CTE in `01`.

**Revenue is Completed-only.** `revenue_inr` is already null for cancelled,
no-show and price-quarantined rows, so `SUM(revenue_inr)` is correct as written.
Do not substitute `SUM(price_inr)` — that would count revenue the shop never
earned.
