-- =====================================================================
-- 02 - booking_conversion_rate, cancellation_rate, no_show_rate
-- Runs against: data/clean/dive_ops_clean.db
--
-- booking_conversion_rate is defined in the brief as "Confirmed bookings /
-- inquiries", but bookings.status has no 'Confirmed' value (only Completed /
-- Cancelled / No-show). Resolved (docs/BRD.md section 6, A-OQ1): an inquiry
-- converts only if it produced a booking that COMPLETED. Q2 gives the alternate
-- definition (any booking, including ones later cancelled) for reference.
--
-- SQLite has no ROLLUP, so overall rows are UNION ALL'd in explicitly.
-- =====================================================================

-- Q1. booking_conversion_rate (inquiry -> COMPLETED booking), overall then by season.
WITH iq AS (
    SELECT i.season_year,
           CASE WHEN b.status = 'Completed' THEN 1 ELSE 0 END AS converted_completed
    FROM inquiries i
    LEFT JOIN bookings b ON b.booking_id = i.converted_booking_id
)
SELECT 'ALL' AS season_year,
       COUNT(*) AS inquiries,
       SUM(converted_completed) AS converted,
       ROUND(1.0 * SUM(converted_completed) / COUNT(*), 4) AS booking_conversion_rate
FROM iq
UNION ALL
SELECT season_year, COUNT(*), SUM(converted_completed),
       ROUND(1.0 * SUM(converted_completed) / COUNT(*), 4)
FROM iq
GROUP BY season_year
ORDER BY season_year;

-- Q2. Alternate definition (all bookings): the inquiry produced ANY booking,
--     including ones later cancelled or no-showed. Reference only.
SELECT i.season_year,
       COUNT(*) AS inquiries,
       ROUND(1.0 * SUM(CASE WHEN b.status = 'Completed'
                            THEN 1 ELSE 0 END) / COUNT(*), 4) AS booking_conversion_rate,
       ROUND(1.0 * SUM(CASE WHEN i.converted_booking_id IS NOT NULL
                            THEN 1 ELSE 0 END) / COUNT(*), 4) AS conversion_rate_all_bookings
FROM inquiries i
LEFT JOIN bookings b ON b.booking_id = i.converted_booking_id
GROUP BY i.season_year
ORDER BY i.season_year;

-- Q3. booking_conversion_rate by channel - which sources send tyre-kickers.
SELECT i.channel,
       COUNT(*) AS inquiries,
       SUM(CASE WHEN b.status = 'Completed' THEN 1 ELSE 0 END) AS converted,
       ROUND(1.0 * SUM(CASE WHEN b.status = 'Completed' THEN 1 ELSE 0 END)
             / COUNT(*), 4) AS booking_conversion_rate
FROM inquiries i
LEFT JOIN bookings b ON b.booking_id = i.converted_booking_id
GROUP BY i.channel
ORDER BY booking_conversion_rate ASC;

-- Q4. cancellation_rate and no_show_rate, overall then by season.
SELECT 'ALL' AS season_year,
       COUNT(*) AS bookings,
       SUM(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled,
       SUM(CASE WHEN status = 'No-show'   THEN 1 ELSE 0 END) AS no_shows,
       ROUND(1.0 * SUM(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END) / COUNT(*), 4)
           AS cancellation_rate,
       ROUND(1.0 * SUM(CASE WHEN status = 'No-show' THEN 1 ELSE 0 END) / COUNT(*), 4)
           AS no_show_rate
FROM bookings
UNION ALL
SELECT season_year, COUNT(*),
       SUM(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END),
       SUM(CASE WHEN status = 'No-show'   THEN 1 ELSE 0 END),
       ROUND(1.0 * SUM(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END) / COUNT(*), 4),
       ROUND(1.0 * SUM(CASE WHEN status = 'No-show'   THEN 1 ELSE 0 END) / COUNT(*), 4)
FROM bookings
GROUP BY season_year
ORDER BY season_year;

-- Q5. cancellation_rate split by cancellation_reason (brief section 3 asks for
--     this split). Denominator is ALL bookings, so the components sum to the
--     headline cancellation_rate. 'Unknown' = cancelled with no reason logged;
--     it is a data-capture failure, not a cause.
SELECT season_year,
       cancellation_reason,
       COUNT(*) AS cancellations,
       ROUND(1.0 * COUNT(*) / (SELECT COUNT(*) FROM bookings b2
                               WHERE b2.season_year = b.season_year), 4)
           AS pct_of_all_bookings,
       ROUND(1.0 * COUNT(*) / (SELECT COUNT(*) FROM bookings b3
                               WHERE b3.season_year = b.season_year
                                 AND b3.status = 'Cancelled'), 4)
           AS pct_of_cancellations
FROM bookings b
WHERE status = 'Cancelled'
GROUP BY season_year, cancellation_reason
ORDER BY season_year, cancellations DESC;

-- Q6. The unexplained share of the cancellation book, by season. Rising values
--     mean the shop is losing the ability to say WHY it loses seats.
SELECT season_year,
       SUM(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END) AS cancellations,
       SUM(CASE WHEN cancellation_reason = 'Unknown' THEN 1 ELSE 0 END) AS unknown_reason,
       ROUND(1.0 * SUM(CASE WHEN cancellation_reason = 'Unknown' THEN 1 ELSE 0 END)
             / SUM(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END), 4)
           AS pct_unexplained
FROM bookings
GROUP BY season_year
ORDER BY season_year;
