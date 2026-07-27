-- =====================================================================
-- 00 - RAW data-quality profile
-- Runs against: data/raw/dive_ops_raw.db  (all columns TEXT, no constraints)
-- Purpose: quantify the mess before cleaning. Every number here is a defect
--          the Phase 3 pipeline (notebooks/01_cleaning.ipynb) has to handle.
-- =====================================================================

-- Q1. Duplicate booking_id rows, and whether any are CONFLICTING rather than
--     byte-identical. Conflicts would need a survivorship rule, not a dedupe.
SELECT
    COUNT(*)                                     AS total_rows,
    COUNT(DISTINCT booking_id)                   AS distinct_booking_ids,
    COUNT(*) - COUNT(DISTINCT booking_id)        AS duplicate_rows,
    (SELECT COUNT(*) FROM (
        SELECT booking_id
        FROM (SELECT DISTINCT booking_id, customer_id, booking_date, dive_date,
                              dive_type, num_dives, price_inr, status,
                              cancellation_reason, trip_id, boat_slot
              FROM bookings)
        GROUP BY booking_id HAVING COUNT(*) > 1
    ))                                           AS conflicting_booking_ids
FROM bookings;

-- Q2. Spelling variants that have to collapse to a canonical value.
SELECT 'status'    AS column_name, COUNT(DISTINCT status)    AS distinct_values FROM bookings
UNION ALL SELECT 'dive_type',   COUNT(DISTINCT dive_type)    FROM bookings
UNION ALL SELECT 'nationality', COUNT(DISTINCT nationality)  FROM customers
UNION ALL SELECT 'cert_level',  COUNT(DISTINCT cert_level)   FROM customers;

-- Q3. The actual status spellings, grouped by what they normalise to.
SELECT TRIM(LOWER(status)) AS normalised, COUNT(DISTINCT status) AS spellings,
       COUNT(*) AS rows
FROM bookings GROUP BY 1 ORDER BY 3 DESC;

-- Q4. Mixed date formats in booking_date (three shapes are expected).
SELECT CASE
         WHEN booking_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' THEN 'ISO yyyy-mm-dd'
         WHEN booking_date GLOB '[0-9][0-9]/[0-9][0-9]/[0-9][0-9][0-9][0-9]' THEN 'dd/mm/yyyy'
         WHEN booking_date GLOB '[A-Za-z]* [0-9]* [0-9][0-9][0-9][0-9]'      THEN 'Month d yyyy'
         ELSE 'UNRECOGNISED'
       END AS date_format,
       COUNT(*) AS rows
FROM bookings GROUP BY 1 ORDER BY 2 DESC;

-- Q5. Impossible prices. CAST is safe here only because price_inr is all-numeric
--     text in raw; the pipeline verifies that before trusting it.
SELECT
    SUM(CASE WHEN CAST(price_inr AS REAL) <= 0     THEN 1 ELSE 0 END) AS non_positive,
    SUM(CASE WHEN CAST(price_inr AS REAL) > 60000  THEN 1 ELSE 0 END) AS above_ceiling,
    MIN(CAST(price_inr AS REAL))                                      AS min_price,
    MAX(CAST(price_inr AS REAL))                                      AS max_price
FROM bookings;

-- Q6. Nulls that matter. Note cancellation_reason nulls conflate two cases:
--     legitimately null (not cancelled) vs the defect (cancelled, no reason).
SELECT 'bookings.cancellation_reason (ALL nulls)' AS field,
       SUM(CASE WHEN cancellation_reason IS NULL THEN 1 ELSE 0 END) AS nulls
FROM bookings
UNION ALL
SELECT 'bookings.cancellation_reason (CANCELLED + null = the defect)',
       SUM(CASE WHEN TRIM(LOWER(status)) = 'cancelled'
                 AND cancellation_reason IS NULL THEN 1 ELSE 0 END)
FROM bookings
UNION ALL
SELECT 'customers.age', SUM(CASE WHEN age IS NULL THEN 1 ELSE 0 END) FROM customers
UNION ALL
SELECT 'customers.acquisition_channel',
       SUM(CASE WHEN acquisition_channel IS NULL THEN 1 ELSE 0 END) FROM customers;

-- Q7. Implausible ages (divers are certified from age 10).
SELECT CASE WHEN CAST(age AS REAL) < 10 THEN 'under 10'
            WHEN CAST(age AS REAL) > 90 THEN 'over 90' END AS bucket,
       COUNT(*) AS rows, GROUP_CONCAT(DISTINCT age) AS values_found
FROM customers
WHERE age IS NOT NULL AND (CAST(age AS REAL) < 10 OR CAST(age AS REAL) > 90)
GROUP BY 1;
