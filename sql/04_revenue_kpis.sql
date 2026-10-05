-- =====================================================================
-- 04 - revenue_per_customer, revenue_per_dive, revenue by product and channel
-- Runs against: data/clean/dive_ops_clean.db
-- Currency is INR throughout (brief section 7).
--
-- revenue_inr is null unless the booking Completed AND its price survived the
-- quarantine (C6). SUM(revenue_inr) is therefore the correct revenue measure;
-- SUM(price_inr) would book money the shop never took.
-- =====================================================================

-- Q1. revenue_per_customer and revenue_per_dive, overall then by season.
--     revenue_per_customer uses ALL customers on file (acquisition-efficiency
--     view). customer_ltv in 03_ is the same calculation (A-OQ3, docs/BRD.md).
SELECT 'ALL' AS season_year,
       ROUND(SUM(revenue_inr), 0) AS total_revenue_inr,
       (SELECT COUNT(*) FROM customers) AS customers,
       SUM(CASE WHEN status = 'Completed' THEN num_dives ELSE 0 END) AS completed_dives,
       ROUND(SUM(revenue_inr) / (SELECT COUNT(*) FROM customers), 0) AS revenue_per_customer,
       ROUND(SUM(revenue_inr)
             / SUM(CASE WHEN status = 'Completed' THEN num_dives ELSE 0 END), 0)
           AS revenue_per_dive
FROM bookings
UNION ALL
SELECT b.season_year,
       ROUND(SUM(b.revenue_inr), 0),
       COUNT(DISTINCT CASE WHEN b.status = 'Completed' THEN b.customer_id END),
       SUM(CASE WHEN b.status = 'Completed' THEN b.num_dives ELSE 0 END),
       ROUND(SUM(b.revenue_inr)
             / COUNT(DISTINCT CASE WHEN b.status = 'Completed' THEN b.customer_id END), 0),
       ROUND(SUM(b.revenue_inr)
             / SUM(CASE WHEN b.status = 'Completed' THEN b.num_dives ELSE 0 END), 0)
FROM bookings b
GROUP BY b.season_year
ORDER BY season_year;

-- Q2. Revenue by product (dive_type) - the dashboard's revenue-by-product visual.
SELECT dive_type,
       COUNT(*)                                    AS bookings,
       SUM(CASE WHEN status = 'Completed' THEN 1 ELSE 0 END) AS completed,
       ROUND(SUM(revenue_inr), 0)                  AS revenue_inr,
       ROUND(1.0 * SUM(revenue_inr)
             / (SELECT SUM(revenue_inr) FROM bookings), 4) AS revenue_share,
       ROUND(AVG(price_inr), 0)                    AS avg_price_inr,
       ROUND(1.0 * SUM(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END)
             / COUNT(*), 4)                        AS cancellation_rate
FROM bookings
GROUP BY dive_type
ORDER BY revenue_inr DESC;

-- Q3. Revenue by channel. 'Unknown' is the 9% of customers whose channel was
--     never captured - it is a real bucket, not a rounding error.
SELECT c.acquisition_channel,
       COUNT(*)                                    AS bookings,
       ROUND(SUM(b.revenue_inr), 0)                AS revenue_inr,
       ROUND(1.0 * SUM(b.revenue_inr)
             / (SELECT SUM(revenue_inr) FROM bookings), 4) AS revenue_share,
       ROUND(AVG(b.price_inr), 0)                  AS avg_price_inr,
       ROUND(1.0 * SUM(CASE WHEN b.status = 'Cancelled' THEN 1 ELSE 0 END)
             / COUNT(*), 4)                        AS cancellation_rate,
       ROUND(1.0 * SUM(CASE WHEN b.status = 'No-show' THEN 1 ELSE 0 END)
             / COUNT(*), 4)                        AS no_show_rate
FROM bookings b
JOIN customers c ON c.customer_id = b.customer_id
GROUP BY c.acquisition_channel
ORDER BY revenue_inr DESC;

-- Q4. Product x season - is the high-value Course product shrinking?
SELECT season_year, dive_type,
       COUNT(*) AS bookings,
       ROUND(1.0 * COUNT(*) / (SELECT COUNT(*) FROM bookings b2
                               WHERE b2.season_year = b.season_year), 4) AS share_of_bookings,
       ROUND(SUM(revenue_inr), 0) AS revenue_inr
FROM bookings b
GROUP BY season_year, dive_type
ORDER BY season_year, revenue_inr DESC;

-- Q5. Channel mix shift by season - where the volume moved to.
SELECT b.season_year, c.acquisition_channel,
       COUNT(*) AS bookings,
       ROUND(1.0 * COUNT(*) / (SELECT COUNT(*) FROM bookings b2
                               WHERE b2.season_year = b.season_year), 4) AS share_of_bookings,
       ROUND(AVG(b.price_inr), 0) AS avg_price_inr
FROM bookings b
JOIN customers c ON c.customer_id = b.customer_id
GROUP BY b.season_year, c.acquisition_channel
ORDER BY b.season_year, bookings DESC;

-- Q6. Value of lost seats: cancellations and no-shows priced at the mean
--     revenue of a completed booking.
WITH seat_value AS (
    SELECT AVG(revenue_inr) AS mean_seat_revenue
    FROM bookings WHERE status = 'Completed'
)
SELECT b.season_year,
       SUM(CASE WHEN b.status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled,
       SUM(CASE WHEN b.status = 'No-show'   THEN 1 ELSE 0 END) AS no_shows,
       ROUND((SELECT mean_seat_revenue FROM seat_value), 0)    AS mean_seat_revenue_inr,
       ROUND(SUM(CASE WHEN b.status IN ('Cancelled', 'No-show') THEN 1 ELSE 0 END)
             * (SELECT mean_seat_revenue FROM seat_value), 0)  AS lost_seat_value_inr
FROM bookings b
GROUP BY b.season_year
ORDER BY b.season_year;
