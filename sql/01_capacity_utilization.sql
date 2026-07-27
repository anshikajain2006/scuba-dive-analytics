-- =====================================================================
-- 01 - capacity_utilization
-- Runs against: data/clean/dive_ops_clean.db
-- KPI (brief section 3): Completed seats booked / total boat slots available,
--                        per trip/season.
--
-- GRAIN WARNING: boat_capacity lives on trips. Joining trips to bookings and
-- summing boat_capacity multiplies each boat's capacity by the seats sold on
-- it. Always collapse to trip grain first (the trip_seats CTE below).
-- =====================================================================

-- Q1. Overall.
WITH trip_seats AS (
    SELECT t.trip_id, t.boat_capacity, t.season,
           MIN(b.season_year) AS season_year,
           MIN(b.dive_ym)     AS dive_ym,
           SUM(CASE WHEN b.status = 'Completed' THEN 1 ELSE 0 END) AS completed_seats,
           COUNT(*)                                                AS seats_sold
    FROM trips t
    JOIN bookings b ON b.trip_id = t.trip_id
    GROUP BY t.trip_id, t.boat_capacity, t.season
)
SELECT SUM(completed_seats)                        AS completed_seats,
       SUM(boat_capacity)                          AS boat_slots,
       ROUND(1.0 * SUM(completed_seats) / SUM(boat_capacity), 4) AS capacity_utilization
FROM trip_seats;

-- Q2. By chronological season. 2023-24 is a HALF season (Jan-May 2024 only):
--     rates are comparable, volumes are not.
WITH trip_seats AS (
    SELECT t.trip_id, t.boat_capacity, MIN(b.season_year) AS season_year,
           SUM(CASE WHEN b.status = 'Completed' THEN 1 ELSE 0 END) AS completed_seats
    FROM trips t JOIN bookings b ON b.trip_id = t.trip_id
    GROUP BY t.trip_id, t.boat_capacity
)
SELECT season_year,
       COUNT(*)                                    AS trips,
       SUM(boat_capacity)                          AS boat_slots,
       SUM(completed_seats)                        AS completed_seats,
       SUM(boat_capacity) - SUM(completed_seats)   AS empty_seats,
       ROUND(1.0 * SUM(completed_seats) / SUM(boat_capacity), 4) AS capacity_utilization
FROM trip_seats
GROUP BY season_year
ORDER BY season_year;

-- Q3. By trading season (Peak / Shoulder / Monsoon-Closed).
WITH trip_seats AS (
    SELECT t.trip_id, t.boat_capacity, t.season,
           SUM(CASE WHEN b.status = 'Completed' THEN 1 ELSE 0 END) AS completed_seats
    FROM trips t JOIN bookings b ON b.trip_id = t.trip_id
    GROUP BY t.trip_id, t.boat_capacity, t.season
)
SELECT season,
       COUNT(*) AS trips,
       SUM(boat_capacity) AS boat_slots,
       ROUND(1.0 * SUM(completed_seats) / SUM(boat_capacity), 4) AS capacity_utilization
FROM trip_seats
GROUP BY season
ORDER BY capacity_utilization DESC;

-- Q4. Season x month matrix -> the dashboard utilization heatmap.
WITH trip_seats AS (
    SELECT t.trip_id, t.boat_capacity,
           MIN(b.season_year) AS season_year,
           MIN(b.dive_month)  AS dive_month,
           SUM(CASE WHEN b.status = 'Completed' THEN 1 ELSE 0 END) AS completed_seats
    FROM trips t JOIN bookings b ON b.trip_id = t.trip_id
    GROUP BY t.trip_id, t.boat_capacity
)
SELECT season_year, dive_month,
       SUM(boat_capacity)   AS boat_slots,
       SUM(completed_seats) AS completed_seats,
       ROUND(1.0 * SUM(completed_seats) / SUM(boat_capacity), 4) AS capacity_utilization
FROM trip_seats
GROUP BY season_year, dive_month
ORDER BY season_year, dive_month;

-- Q5. Worst-utilised trips in the current season - the operational hit list.
WITH trip_seats AS (
    SELECT t.trip_id, t.dive_site, t.boat_capacity,
           MIN(b.season_year) AS season_year, MIN(b.dive_date) AS dive_date,
           SUM(CASE WHEN b.status = 'Completed' THEN 1 ELSE 0 END) AS completed_seats
    FROM trips t JOIN bookings b ON b.trip_id = t.trip_id
    GROUP BY t.trip_id, t.dive_site, t.boat_capacity
)
SELECT trip_id, dive_date, dive_site, boat_capacity, completed_seats,
       boat_capacity - completed_seats AS empty_seats,
       ROUND(1.0 * completed_seats / boat_capacity, 3) AS capacity_utilization
FROM trip_seats
WHERE season_year = '2025-26'
ORDER BY capacity_utilization ASC, empty_seats DESC
LIMIT 15;
