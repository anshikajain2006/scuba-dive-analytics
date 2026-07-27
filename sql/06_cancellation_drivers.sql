-- =====================================================================
-- 06 - Cancellation drivers: weather and channel
-- Runs against: data/clean/dive_ops_clean.db
--
-- The question behind these queries is not "does weather cause cancellations"
-- (it obviously does) but "how much of the cancellation book is weather, and
-- how much is addressable". Q2 is the one that matters commercially.
-- =====================================================================

-- Q1. cancellation_rate by sea_condition. Rough/Closed days cancel at several
--     times the Calm rate - the correlation is real and strong.
SELECT w.sea_condition,
       COUNT(*)                                    AS bookings,
       SUM(CASE WHEN b.status = 'Cancelled' THEN 1 ELSE 0 END) AS cancellations,
       ROUND(1.0 * SUM(CASE WHEN b.status = 'Cancelled' THEN 1 ELSE 0 END)
             / COUNT(*), 4)                        AS cancellation_rate,
       SUM(CASE WHEN b.cancellation_reason = 'Weather' THEN 1 ELSE 0 END) AS reason_weather,
       SUM(CASE WHEN b.cancellation_reason = 'Unknown' THEN 1 ELSE 0 END) AS reason_unknown
FROM bookings b
JOIN weather w ON w.weather_date = b.dive_date
GROUP BY w.sea_condition
ORDER BY cancellation_rate DESC;

-- Q2. THE KEY SPLIT. Bad weather is highly predictive per-booking but only
--     applies to a small slice of the calendar. Most cancellations by VOLUME
--     happen on perfectly diveable days - that is the addressable loss.
SELECT CASE WHEN w.sea_condition IN ('Rough', 'Closed') THEN 'Rough/Closed'
            ELSE 'Calm/Moderate' END               AS conditions,
       COUNT(*)                                    AS bookings,
       ROUND(1.0 * COUNT(*) / (SELECT COUNT(*) FROM bookings), 4) AS share_of_bookings,
       SUM(CASE WHEN b.status = 'Cancelled' THEN 1 ELSE 0 END) AS cancellations,
       ROUND(1.0 * SUM(CASE WHEN b.status = 'Cancelled' THEN 1 ELSE 0 END)
             / (SELECT COUNT(*) FROM bookings WHERE status = 'Cancelled'), 4)
           AS share_of_cancellations,
       ROUND(1.0 * SUM(CASE WHEN b.status = 'Cancelled' THEN 1 ELSE 0 END)
             / COUNT(*), 4)                        AS cancellation_rate
FROM bookings b
JOIN weather w ON w.weather_date = b.dive_date
GROUP BY conditions;

-- Q3. Cancellations NOT attributable to weather - the recoverable pool, priced.
WITH seat_value AS (
    SELECT AVG(revenue_inr) AS mean_seat_revenue FROM bookings WHERE status = 'Completed'
)
SELECT COUNT(*)                                              AS non_weather_cancellations,
       ROUND(1.0 * COUNT(*) / (SELECT COUNT(*) FROM bookings
                               WHERE status = 'Cancelled'), 4) AS share_of_cancellations,
       ROUND(COUNT(*) * (SELECT mean_seat_revenue FROM seat_value), 0)
                                                             AS value_at_stake_inr
FROM bookings
WHERE status = 'Cancelled' AND cancellation_reason <> 'Weather';

-- Q4. cancellation_rate and no_show_rate by channel, with average price.
--     Cheap channels that cancel hardest are the worst of both worlds.
SELECT c.acquisition_channel,
       COUNT(*)                                    AS bookings,
       ROUND(AVG(b.price_inr), 0)                  AS avg_price_inr,
       ROUND(1.0 * SUM(CASE WHEN b.status = 'Cancelled' THEN 1 ELSE 0 END)
             / COUNT(*), 4)                        AS cancellation_rate,
       ROUND(1.0 * SUM(CASE WHEN b.status = 'No-show' THEN 1 ELSE 0 END)
             / COUNT(*), 4)                        AS no_show_rate,
       SUM(CASE WHEN b.status IN ('Cancelled', 'No-show') THEN 1 ELSE 0 END) AS lost_seats
FROM bookings b
JOIN customers c ON c.customer_id = b.customer_id
GROUP BY c.acquisition_channel
ORDER BY cancellation_rate DESC;

-- Q5. Channel mix shift: how the share of each channel moved across seasons.
SELECT c.acquisition_channel,
       ROUND(1.0 * SUM(CASE WHEN b.season_year = '2023-24 (half)' THEN 1 ELSE 0 END)
             / (SELECT COUNT(*) FROM bookings WHERE season_year = '2023-24 (half)'), 4)
           AS share_2023_24,
       ROUND(1.0 * SUM(CASE WHEN b.season_year = '2024-25' THEN 1 ELSE 0 END)
             / (SELECT COUNT(*) FROM bookings WHERE season_year = '2024-25'), 4)
           AS share_2024_25,
       ROUND(1.0 * SUM(CASE WHEN b.season_year = '2025-26' THEN 1 ELSE 0 END)
             / (SELECT COUNT(*) FROM bookings WHERE season_year = '2025-26'), 4)
           AS share_2025_26
FROM bookings b
JOIN customers c ON c.customer_id = b.customer_id
GROUP BY c.acquisition_channel
ORDER BY share_2025_26 DESC;

-- Q6. Lead time vs cancellation - do bookings made far ahead cancel more?
SELECT CASE WHEN lead_time_days <= 3  THEN '0-3 days'
            WHEN lead_time_days <= 10 THEN '4-10 days'
            WHEN lead_time_days <= 21 THEN '11-21 days'
            WHEN lead_time_days <= 35 THEN '22-35 days'
            ELSE '36+ days' END                    AS lead_time_bucket,
       COUNT(*)                                    AS bookings,
       ROUND(1.0 * SUM(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END)
             / COUNT(*), 4)                        AS cancellation_rate,
       ROUND(1.0 * SUM(CASE WHEN status = 'No-show' THEN 1 ELSE 0 END)
             / COUNT(*), 4)                        AS no_show_rate
FROM bookings
GROUP BY lead_time_bucket
ORDER BY MIN(lead_time_days);
