# User Stories and Acceptance Criteria

Project: scuba-dive-analytics (local folder: Scuba). Phase 5.

Each story traces to a business requirement in [`BRD.md`](BRD.md) and a
recommendation R1–R5. The full chain is in
[`TRACEABILITY_MATRIX.md`](TRACEABILITY_MATRIX.md). Figures come from
[`FINDINGS.md`](FINDINGS.md). Currency is INR.

---

### US-01 · Daily high-risk call list (R1 · BR-01)

**As a** Front Desk Staff member, **I want** a daily list of bookings in risk
deciles 1–3 whose dive is 48 hours away, **so that** I can call those customers
first and keep seats that would otherwise cancel.

*Why:* the top 3 deciles hold 58.1% of cancellations (358 of 616) in 30% of bookings.

**Acceptance criteria**
1. The list is ready by 09:00 each day. It contains every booking in deciles 1–3 with a dive date 48 hours (±12 h) ahead, and no others.
2. Each row shows customer name, phone, dive date, product, `acquisition_channel` and forecast `sea_condition`. **No probability score is shown** (the model selects a group; see FINDINGS §3).
3. A booking that is cancelled or already confirmed does not appear.

### US-02 · Recording and measuring call outcomes (R1 · BR-02)

**As a** Dive Centre Manager, **I want** every confirmation call outcome recorded
and summarised each week, **so that** I can see how many seats the calls saved
out of the ₹79,77,635 non-weather pool.

**Acceptance criteria**
1. Each call is logged with one outcome: Confirmed, Rescheduled, Cancelled, or Unreachable.
2. The weekly summary shows calls made, seats kept, and `cancellation_rate` for called vs uncalled bookings in deciles 1–3.
3. A Rescheduled booking keeps its original `booking_id`. It is not counted as a new booking or as a cancellation.

### US-03 · Deposit on OTA bookings (R2 · BR-03)

**As an** OTA Customer, **I want** to see the deposit amount and refund terms before
I confirm, **so that** I know what I commit to and my seat is guaranteed once I pay.

*Why:* OTA cancels at 27.8% (walk-in 13.8%) and no-shows at 7.5% (walk-in 3.5%).

**Acceptance criteria**
1. The deposit amount and refund rules are shown on the OTA listing and in the booking confirmation.
2. An OTA booking stays "Held" until the deposit is received. Unpaid holds are released at a cut-off the owner sets.
3. A no-show forfeits the deposit. A Weather cancellation made by the centre refunds it in full or moves it to a new date.

### US-04 · Channel economics for OTA renegotiation (R2 · BR-04)

**As a** Dive Centre Manager, **I want** revenue, `cancellation_rate`,
`no_show_rate` and lifetime revenue per diving customer side by side for each acquisition channel, **so
that** I can renegotiate OTA terms using our own numbers.

**Acceptance criteria**
1. The view shows all six channels plus `Unknown`, filterable by `season_year`.
2. With no filters, the OTA row reproduces FINDINGS §2③: 1,377 bookings, ₹8,167 average price, 27.8% cancellation, ₹9,533 lifetime revenue per diving customer.
3. The view can be exported to PDF or CSV to share with the OTA partner.

### US-05 · Fun-dive offer for new graduates (R3 · BR-05)

**As a** Graduate Diver, **I want** a fun-dive offer while my certification is still
fresh, **so that** I keep diving instead of letting my new skills fade.

*Why:* 69% of returning graduates come back within 90 days (median 49 days).
`course_to_fundive_conversion` fell from 39.5% to 4.8%.

**Acceptance criteria**
1. The offer is sent automatically between day 30 and day 45 after the certification date, only to graduates who consented to contact.
2. If the graduate has not booked a Fun Dive by day 75, one reminder is sent before day 90. No further messages are sent after that.
3. A booking made from the offer is tagged so `course_to_fundive_conversion` can be measured for each campaign.

### US-06 · Graduate hand-off at certification (R3 · BR-06)

**As a** Dive Instructor, **I want** to record a graduate's certification date and
contact consent when I sign off their course, **so that** the re-engagement offer
reaches every new diver.

**Acceptance criteria**
1. A Course booking cannot be marked Completed without a certification date.
2. Contact consent (yes / no) is required, and a "no" blocks all automated messages.
3. The instructor can add an optional note (for example "interested in Advanced") that appears in the offer.

### US-07 · Mandatory cancellation reason (R4 · BR-07)

**As a** Front Desk Staff member, **I want** the system to require a cancellation
reason before it saves a cancellation, **so that** no lost seat goes unexplained.

*Why:* 19.6% of 2025-26 cancellations (121 bookings) have no recorded reason.

**Acceptance criteria**
1. A cancellation cannot be saved unless the reason is one of Weather, Customer, Medical or Other.
2. Choosing "Other" requires at least 10 characters of free text.
3. The monthly share of cancellations with reason `Unknown` is 0% for records created after go-live.

### US-08 · Capturing how walk-ins found us (R4 · BR-08)

**As a** Walk-in Customer, **I want** to be asked once, quickly, how I heard about
the centre, **so that** the shop knows which channels work, without slowing my
booking down.

*Why:* 9.0% of customers, covering ₹50,96,000 (9.3% of revenue), have no channel recorded.

**Acceptance criteria**
1. `acquisition_channel` is a required single-choice field (the six channels) on every booking path, including OTA imports, which default to OTA.
2. Answering takes one tap or click, and no free text is required.
3. A returning customer's existing channel is pre-filled and is not asked again.

### US-09 · Demand-aligned departure schedule (R5 · BR-11)

**As a** Dive Centre Manager, **I want** each week's departures proposed from the
`seasonality_index` and the current booked load, **so that** I stop sailing
half-empty boats in slow months and have enough seats in January.

*Why:* `capacity_utilization` is 54.5%, 626 seats went unsold in 2025-26, and the
January index is 192 against April's 121.

**Acceptance criteria**
1. Each week the system proposes how many departures to run per day, using the month's `seasonality_index` and the seats booked.
2. Any departure below a fill threshold set by the owner, 48 hours out, is flagged for consolidation.
3. `capacity_utilization` is reported weekly against the 75% target line (brief §9).

### US-10 · Consolidated trip roster (R5 · BR-11)

**As a** Dive Instructor, **I want** confirmed rosters 48 hours before each
departure, consolidations included, **so that** I can plan dive sites, kit and
buddy pairs for the divers who will actually come.

**Acceptance criteria**
1. The roster is final 48 hours before departure and shows each diver's `cert_level` and product.
2. Customers moved by a consolidation are notified at the same time and appear on the new trip's roster.
3. A consolidated trip never exceeds `boat_capacity`.

### US-11 · Walk-in booking stays simple (R2 · BR-03)

**As a** Walk-in Customer, **I want** to book without paying a deposit, **so that**
I can book on the spot, as I do today.

*Why:* walk-ins cancel at 13.8% and no-show at 3.5%, and their lifetime revenue
per diving customer is the highest of any channel at ₹14,197. A deposit is not needed for them.

**Acceptance criteria**
1. The deposit gate applies only to bookings whose channel is OTA.
2. Walk-in booking takes no more steps than before, apart from the one channel question (US-08).

### US-12 · Price checked at entry (R4 · BR-09)

**As a** Front Desk Staff member, **I want** the system to reject a price that is
zero, negative or outside the owner's range, **so that** a typing mistake never
turns into a revenue figure.

*Why:* cleaning had to quarantine 23 impossible prices (15 negative, 8 extreme).
The revenue from those bookings is now permanently unknown.

**Acceptance criteria**
1. A price of ₹0 or less cannot be saved.
2. A price outside the range the owner sets for each product needs the manager to approve it before it saves.

### US-13 · KPI and data-quality dashboard (R4 · BR-10, BR-12)

**As a** Dive Centre Manager, **I want** one dashboard showing the ten KPIs by
season next to the share of `Unknown` channels and reasons, **so that** I can see
whether R1–R5 are working and whether I can trust the data behind them.

**Acceptance criteria**
1. All ten KPIs from PROJECT_BRIEF.md §3 appear with their exact names, with a `season_year` slicer on every page.
2. With no filters, `capacity_utilization` reads 59.5% and total revenue reads ₹5,49,50,350 (DASHBOARD_SPEC §7).
3. Two tiles show `Unknown` as a share of cancellations (baseline 19.6% for 2025-26) and of customers (baseline 9.0%).
