# Memo: Where the revenue went, and five fixes

**To:** Owner, Havelock Dive Centre
**From:** Analytics team, scuba-dive-analytics (local folder: Scuba)
**Re:** 2025-26 revenue decline. Evidence in `docs/FINDINGS.md`

---

**Situation.** Revenue fell from ₹2.23 crore to ₹1.46 crore last season, a drop of
34.5%. Bookings fell by only 16.9%. The main problem is not a lack of customers.
Last season 750 people booked a seat and never dived.

**What we found**

- **Most cancellations are not caused by weather.** 795 cancellations, worth ₹79.8
  lakh, happened for other reasons. Our risk model finds 58% of all cancellations
  inside just 30% of bookings.
- **OTA bookings are the weakest.** They now make up 29% of bookings, up from 9%.
  They pay 26% less than walk-ins (₹8,167 vs ₹11,090), cancel twice as often (28% vs
  14%), and are worth ₹9,533 per customer against ₹14,197 for a walk-in.
- **Course graduates have stopped coming back.** Graduates who returned for a fun
  dive fell from 40% to 5%. Most returners come back within 90 days, typically
  around day 49. Courses earn 42% of revenue (₹2.33 crore).
- **We can't explain a fifth of our losses.** One in five cancellations last season
  had no reason written down. ₹51 lakh of revenue has no record of where the
  customer came from.
- **Boats sail half-empty.** Only 54.5% of seats were filled last season, and 626
  seats were never sold at all. January demand is nearly double the average, while
  some other months are much quieter.

**What we recommend**

| | Action | Effort |
|---|---|---|
| **R1** | Each day, call the bookings our model marks as highest-risk, 48 hours before the dive, to confirm or reschedule. | **Low** |
| **R2** | Take a deposit on every OTA booking, or renegotiate OTA commission. Keep OTA; it is 29% of volume. | **Medium** |
| **R3** | Send every new graduate an automatic fun-dive offer 30–45 days after certifying, with one reminder before day 90. | **Low** |
| **R4** | Make "reason for cancelling" and "how did you hear about us" required fields. This is the cheapest fix, and we need it to tell whether the other four are working. | **Low** |
| **R5** | Plan trips around real demand: more boats in December–March, and merge half-full boats 48 hours ahead. | **Medium** |

Lifting seat fill from 54.5% to 75% would mean 620 more completed dives, about
**₹62.3 lakh** a season.

**Before acting, please confirm three things.** (1) Do you already take deposits?
If you do, our loss figures are too high, and R2 becomes enforcing the deposit
rather than introducing one. (2) Should "conversion rate" count bookings that later
cancelled? Today it reads 43.7% with them and 30.1% without. (3) Which months do you
consider "shoulder" season?

**Next step:** start with R4 and R3 this month, since both are low effort. Then
pilot R1 for four weeks and compare cancellation rates against last season on the
dashboard.
