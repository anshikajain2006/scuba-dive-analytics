-- =====================================================================
-- 05 - seasonality_index
-- Runs against: data/clean/dive_ops_clean.db
-- KPI (brief section 3): monthly bookings indexed to the monthly mean (mean = 100).
--
-- COVERAGE WARNING: 2.5 seasons do not cover the calendar evenly. Jan-May occur
-- three times in the window, Oct-Dec only twice, Jul-Aug never (the shop is
-- shut). Indexing raw monthly totals would understate Oct-Dec by a third. The
-- index below is built on mean bookings PER OCCURRENCE of each calendar month.
--
-- DENOMINATOR: the mean is taken over all TWELVE calendar months, with the two
-- closed months (Jul, Aug) contributing 0 - so the index describes a full
-- trading year including the shutdown, and averages 100 across 12 months.
-- Averaging over only the 10 trading months would raise the baseline and
-- understate the peak (Jan would read 160 instead of 192). The month spine
-- below forces all 12 months to be present. This matches
-- notebooks/02_eda_kpis.ipynb exactly.
-- =====================================================================

-- Q1. seasonality_index by calendar month.
WITH months(dive_month) AS (
    VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12)
),
monthly AS (
    SELECT m.dive_month,
           COUNT(b.booking_id)       AS bookings_total,
           COUNT(DISTINCT b.dive_ym) AS months_observed
    FROM months m
    LEFT JOIN bookings b ON b.dive_month = m.dive_month
    GROUP BY m.dive_month
),
per_month AS (
    SELECT dive_month, bookings_total, months_observed,
           CASE WHEN months_observed = 0 THEN 0.0
                ELSE 1.0 * bookings_total / months_observed END AS mean_bookings_per_month
    FROM monthly
)
SELECT dive_month,
       bookings_total,
       months_observed,
       ROUND(mean_bookings_per_month, 1) AS mean_bookings_per_month,
       ROUND(100.0 * mean_bookings_per_month
             / (SELECT AVG(mean_bookings_per_month) FROM per_month), 1) AS seasonality_index
FROM per_month
ORDER BY dive_month;

-- Q2. Actual bookings per calendar month per season - the raw grid behind Q1.
--     Empty cells are months the shop did not trade.
SELECT dive_month,
       SUM(CASE WHEN season_year = '2023-24 (half)' THEN 1 ELSE 0 END) AS s2023_24_half,
       SUM(CASE WHEN season_year = '2024-25'        THEN 1 ELSE 0 END) AS s2024_25,
       SUM(CASE WHEN season_year = '2025-26'        THEN 1 ELSE 0 END) AS s2025_26,
       COUNT(*) AS total
FROM bookings
GROUP BY dive_month
ORDER BY dive_month;

-- Q3. Monthly trend line: bookings, revenue and utilization together.
WITH trip_seats AS (
    SELECT t.trip_id, t.boat_capacity, MIN(b.dive_ym) AS dive_ym,
           SUM(CASE WHEN b.status = 'Completed' THEN 1 ELSE 0 END) AS completed_seats
    FROM trips t JOIN bookings b ON b.trip_id = t.trip_id
    GROUP BY t.trip_id, t.boat_capacity
),
util AS (
    SELECT dive_ym, SUM(boat_capacity) AS boat_slots, SUM(completed_seats) AS completed_seats
    FROM trip_seats GROUP BY dive_ym
)
SELECT b.dive_ym,
       COUNT(*)                                     AS bookings,
       ROUND(SUM(b.revenue_inr), 0)                 AS revenue_inr,
       u.boat_slots,
       ROUND(1.0 * u.completed_seats / u.boat_slots, 4) AS capacity_utilization,
       ROUND(1.0 * SUM(CASE WHEN b.status = 'Cancelled' THEN 1 ELSE 0 END)
             / COUNT(*), 4)                         AS cancellation_rate
FROM bookings b
JOIN util u ON u.dive_ym = b.dive_ym
GROUP BY b.dive_ym, u.boat_slots, u.completed_seats
ORDER BY b.dive_ym;

-- Q4. Peak vs trough among trading months only (Jul/Aug excluded - zero trade
--     is a closure, not a seasonal low).
WITH per_month AS (
    SELECT dive_month, 1.0 * COUNT(*) / COUNT(DISTINCT dive_ym) AS mean_bookings
    FROM bookings GROUP BY dive_month
)
SELECT
    (SELECT dive_month FROM per_month ORDER BY mean_bookings DESC LIMIT 1) AS peak_month,
    (SELECT ROUND(MAX(mean_bookings), 1) FROM per_month)                   AS peak_mean_bookings,
    (SELECT dive_month FROM per_month WHERE mean_bookings > 0
      ORDER BY mean_bookings ASC LIMIT 1)                                  AS trough_month,
    (SELECT ROUND(MIN(mean_bookings), 1) FROM per_month WHERE mean_bookings > 0)
                                                                           AS trough_mean_bookings;
