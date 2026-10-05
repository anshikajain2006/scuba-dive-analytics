-- =====================================================================
-- 03 - repeat_customer_rate, course_to_fundive_conversion, customer_ltv
-- Runs against: data/clean/dive_ops_clean.db
--
-- All three KPIs count COMPLETED bookings only. A cancelled booking is not a
-- visit and must not make someone look like a returning customer.
-- =====================================================================

-- Q1. repeat_customer_rate = customers with >1 completed booking / all customers.
--     Denominator is every customer on file, including those who never dived -
--     they are still acquisition spend that failed to convert to a second visit.
WITH per_customer AS (
    SELECT c.customer_id,
           SUM(CASE WHEN b.status = 'Completed' THEN 1 ELSE 0 END) AS completed_bookings
    FROM customers c
    LEFT JOIN bookings b ON b.customer_id = c.customer_id
    GROUP BY c.customer_id
)
SELECT COUNT(*)                                                   AS customers,
       SUM(CASE WHEN completed_bookings > 1 THEN 1 ELSE 0 END)    AS repeat_customers,
       ROUND(1.0 * SUM(CASE WHEN completed_bookings > 1 THEN 1 ELSE 0 END)
             / COUNT(*), 4)                                       AS repeat_customer_rate
FROM per_customer;

-- Q2. Distribution of completed bookings per customer - shows how thin the
--     repeat tail is, and why RFM segmentation was rejected as the model.
WITH per_customer AS (
    SELECT c.customer_id,
           SUM(CASE WHEN b.status = 'Completed' THEN 1 ELSE 0 END) AS completed_bookings
    FROM customers c
    LEFT JOIN bookings b ON b.customer_id = c.customer_id
    GROUP BY c.customer_id
)
SELECT completed_bookings, COUNT(*) AS customers,
       ROUND(1.0 * COUNT(*) / (SELECT COUNT(*) FROM per_customer), 4) AS pct_of_customers
FROM per_customer
GROUP BY completed_bookings
ORDER BY completed_bookings;

-- Q3. course_to_fundive_conversion = customers who did a Course then LATER a
--     Fun Dive / all course customers. The date test matters: a fun dive taken
--     before the course is not a conversion.
WITH first_course AS (
    SELECT customer_id, MIN(dive_date) AS first_course_date
    FROM bookings
    WHERE status = 'Completed' AND dive_type = 'Course'
    GROUP BY customer_id
),
returned AS (
    SELECT DISTINCT fc.customer_id
    FROM first_course fc
    JOIN bookings b ON b.customer_id = fc.customer_id
    WHERE b.status = 'Completed'
      AND b.dive_type = 'Fun Dive'
      AND b.dive_date > fc.first_course_date
)
SELECT (SELECT COUNT(*) FROM first_course)                        AS course_customers,
       (SELECT COUNT(*) FROM returned)                            AS returned_for_fun_dive,
       ROUND(1.0 * (SELECT COUNT(*) FROM returned)
             / (SELECT COUNT(*) FROM first_course), 4)            AS course_to_fundive_conversion;

-- Q4. Same, split by the season the course was taken in. This is where the
--     retention collapse shows up most sharply.
WITH first_course AS (
    SELECT customer_id, MIN(dive_date) AS first_course_date, MIN(season_year) AS season_year
    FROM bookings
    WHERE status = 'Completed' AND dive_type = 'Course'
    GROUP BY customer_id
),
returned AS (
    SELECT DISTINCT fc.customer_id
    FROM first_course fc
    JOIN bookings b ON b.customer_id = fc.customer_id
    WHERE b.status = 'Completed' AND b.dive_type = 'Fun Dive'
      AND b.dive_date > fc.first_course_date
)
SELECT fc.season_year,
       COUNT(*) AS course_customers,
       SUM(CASE WHEN r.customer_id IS NOT NULL THEN 1 ELSE 0 END) AS returned_for_fun_dive,
       ROUND(1.0 * SUM(CASE WHEN r.customer_id IS NOT NULL THEN 1 ELSE 0 END)
             / COUNT(*), 4) AS course_to_fundive_conversion
FROM first_course fc
LEFT JOIN returned r ON r.customer_id = fc.customer_id
GROUP BY fc.season_year
ORDER BY fc.season_year;

-- Q5. customer_ltv. Under the brief's definitions this is equivalent to
--     revenue_per_customer: total revenue / all customers on file (docs/BRD.md
--     section 6, A-OQ3). A true LTV model would need cohort-level retention data
--     not available in this dataset. The diving-customer average is context only.
--     revenue_inr is already null on cancelled/no-show/quarantined rows.
WITH lifetime AS (
    SELECT customer_id, SUM(revenue_inr) AS lifetime_revenue
    FROM bookings
    WHERE status = 'Completed'
    GROUP BY customer_id
)
SELECT (SELECT COUNT(*) FROM customers)                  AS customers,
       ROUND((SELECT SUM(revenue_inr) FROM bookings)
             / (SELECT COUNT(*) FROM customers), 0)       AS customer_ltv,
       COUNT(*)                                           AS diving_customers,
       ROUND(AVG(lifetime_revenue), 0)                    AS avg_revenue_per_diving_customer
FROM lifetime;

-- Q6. Lifetime revenue per diving customer, by first-touch acquisition
--     channel - which channels buy customers worth keeping.
WITH lifetime AS (
    SELECT b.customer_id, c.acquisition_channel,
           SUM(b.revenue_inr) AS lifetime_revenue,
           COUNT(*)           AS completed_bookings
    FROM bookings b
    JOIN customers c ON c.customer_id = b.customer_id
    WHERE b.status = 'Completed'
    GROUP BY b.customer_id, c.acquisition_channel
)
SELECT acquisition_channel,
       COUNT(*)                                   AS diving_customers,
       ROUND(AVG(lifetime_revenue), 0)            AS revenue_per_diving_customer,
       ROUND(AVG(completed_bookings), 2)          AS avg_completed_bookings
FROM lifetime
GROUP BY acquisition_channel
ORDER BY revenue_per_diving_customer DESC;
