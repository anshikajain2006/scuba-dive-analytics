"""
Phase 2 - synthetic RAW dataset generator for the dive-operator case study.

Implements PROJECT_BRIEF.md section 4 exactly: five tables (inquiries, customers,
bookings, trips, weather), ~7,000 bookings across 2.5 seasons, with the deliberate
mess intact. Writes CSVs plus a SQLite database into data/raw/.

THE RAW LAYER IS NEVER CLEANED HERE. Cleaning is Phase 3 and lands in data/clean/.

Stdlib only (no pandas/numpy) and seeded - every run reproduces the same dataset.

    python data/generate_data.py


------------------------------------------------------------------------------
ASSUMPTIONS - things section 4 did not pin down. Each is a deliberate choice,
not a silent guess. Change the constant and re-run if you disagree.
------------------------------------------------------------------------------
A1. Season calendar. The brief says "2.5 seasons" but gives no dates. Used:
      2023-24 (half)  2024-01-01 .. 2024-05-31   <- the 0.5
      2024-25 (full)  2024-10-01 .. 2025-05-31
      2025-26 (full)  2025-10-01 .. 2026-05-31
    Ending the window at the close of the most recent full season means the
    "current" season is complete, so season-over-season comparisons are
    like-for-like. The half-season sits at the START (partial history) rather
    than the end, so it never gets mistaken for a decline.

A2. "Shoulder" months. Section 4 says Peak = Oct-May and Monsoon-Closed = Jun-Sep,
    which leaves Shoulder with no months at all. Split the Oct-May window:
      Peak            Dec, Jan, Feb, Mar
      Shoulder        Oct, Nov, Apr, May
      Monsoon-Closed  Jun, Jul, Aug, Sep
    This is the one place the brief is self-inconsistent. FLAGGED.

A3. Monsoon bookings. The centre is "Monsoon-Closed", but a hard zero would make
    seasonality_index undefined for Jun-Sep. A thin trickle of operations runs in
    the first half of June and second half of September (shoulder edges of the
    closure), tagged season "Monsoon-Closed". ~1% of volume.

A4. trips has no date column (section 4 fixes the columns). A trip is a boat
    departure, which is inherently dated. Trip->date is therefore carried only
    via bookings: every booking on a trip shares that trip's dive_date. Adding
    trip_date would make per-day utilization SQL much simpler - say the word.

A5. num_dives = dives included in the booking (a package). One booking occupies
    ONE seat on ONE trip, so capacity_utilization counts bookings-as-seats while
    revenue_per_dive divides by SUM(num_dives). Stated because the two KPIs use
    different denominators off the same column.

A6. booking_conversion_rate is "confirmed bookings / inquiries", but the status
    enum is Completed/Cancelled/No-show - there is no "Confirmed". Treated as:
    a booking existing == it was confirmed, so the numerator is inquiries with a
    non-null converted_booking_id. Not every booking comes from a logged inquiry
    (walk-ins), so ~78% of bookings are inquiry-linked. FLAGGED - if "confirmed"
    was meant to exclude later cancellations, Phase 3 needs a different numerator.

A7. Which fields get date mess: ONLY signup_date and booking_date, the two the
    brief marks "mixed formats". dive_date, inquiry_date and weather_date stay
    ISO - dive_date must join to weather, so corrupting it would break the
    weather/cancellation correlation the brief explicitly asks for.

A8. A booking's channel is its customer's acquisition_channel (bookings has no
    channel column). That column is ~9% null by design, so channel attribution
    is partly unrecoverable - an intentional finding, not just noise.

A9. Every raw SQLite column is TEXT with no PRIMARY KEY or FOREIGN KEY
    constraints. Declared keys would reject the duplicate booking_id rows and
    coerce the messy values on load. Constraints belong on the clean layer.

A10. Trend magnitudes (decline in bookings, utilization, repeat rate; rise in
     cancellations, OTA share) are NOT in the brief - they are planted signal so
     Phase 3 has something real to find. Only one is anchored: section 9 cites
     55% current utilization, so capacity_utilization is tuned to land there.
     All values live in SEASONS below.
"""

import csv
import os
import random
import sqlite3
from datetime import date, timedelta

# --------------------------------------------------------------------------
# Config
# --------------------------------------------------------------------------

SEED = 42
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "raw")
DB_PATH = os.path.join(OUT_DIR, "dive_ops_raw.db")

MONTH_NAMES = ["January", "February", "March", "April", "May", "June",
               "July", "August", "September", "October", "November", "December"]

# A1 - season windows. `key` is internal only; it is not written to any table.
SEASONS = [
    {
        "key": "2023-24",
        "start": date(2024, 1, 1), "end": date(2024, 5, 31),
        "trips_per_day": 1.43,      # boat departures scheduled per operating day
        "booked_util": 0.800,       # seats SOLD / boat_capacity (before cancellations)
        "p_cancel": 0.105,          # baseline, before weather + channel multipliers
        "p_noshow": 0.038,
        "p_null_reason": 0.06,      # Cancelled rows with the reason left blank
        "p_repeat": 0.30,           # chance a booking reuses an existing customer
        "p_course_to_fun": 0.11,    # of repeats, chance it's a course alum returning
        "course_share": 0.215,
        "price_factor": 1.000,      # progressive discounting across seasons
        # A8 - channel mix, OTA share climbing season over season
        "channels": {"Walk-in": .28, "Website": .22, "OTA": .10,
                     "Referral": .16, "Instagram": .12, "Hotel Partner": .12},
    },
    {
        "key": "2024-25",
        "start": date(2024, 10, 1), "end": date(2025, 5, 31),
        "trips_per_day": 1.37,
        "booked_util": 0.780,
        "p_cancel": 0.152,
        "p_noshow": 0.052,
        "p_null_reason": 0.115,
        "p_repeat": 0.235,
        "p_course_to_fun": 0.08,
        "course_share": 0.175,
        "price_factor": 0.975,
        "channels": {"Walk-in": .24, "Website": .19, "OTA": .22,
                     "Referral": .13, "Instagram": .12, "Hotel Partner": .10},
    },
    {
        "key": "2025-26",
        "start": date(2025, 10, 1), "end": date(2026, 5, 31),
        "trips_per_day": 1.06,      # fewer departures as demand falls
        "booked_util": 0.820,       # sold fuller (OTA discounting) but empties out
        "p_cancel": 0.208,
        "p_noshow": 0.069,
        "p_null_reason": 0.185,
        "p_repeat": 0.175,
        "p_course_to_fun": 0.05,
        "course_share": 0.140,
        "price_factor": 0.945,
        "channels": {"Walk-in": .19, "Website": .16, "OTA": .34,
                     "Referral": .10, "Instagram": .12, "Hotel Partner": .09},
    },
]

# A3 - monsoon trickle windows (edges of the closure).
MONSOON_WINDOWS = [
    (date(2024, 6, 1), date(2024, 6, 15)), (date(2024, 9, 16), date(2024, 9, 30)),
    (date(2025, 6, 1), date(2025, 6, 15)), (date(2025, 9, 16), date(2025, 9, 30)),
]
MONSOON_TRIP_CHANCE = 0.35

# Demand shape within a season (relative). Drives departures per day.
MONTH_DEMAND = {10: 0.75, 11: 0.95, 12: 1.25, 1: 1.35, 2: 1.30, 3: 1.15, 4: 0.90, 5: 0.60}

# A2 - month -> season label written to trips.season
PEAK_MONTHS = {12, 1, 2, 3}
SHOULDER_MONTHS = {10, 11, 4, 5}
MONSOON_MONTHS = {6, 7, 8, 9}

# weather.sea_condition distribution by season bucket
WEATHER_PROBS = {
    "Peak":           {"Calm": .62, "Moderate": .27, "Rough": .09, "Closed": .02},
    "Shoulder":       {"Calm": .44, "Moderate": .33, "Rough": .17, "Closed": .06},
    "Monsoon-Closed": {"Calm": .02, "Moderate": .08, "Rough": .25, "Closed": .65},
}
WEATHER_PERSISTENCE = 0.35   # chance today repeats yesterday's condition

# Section 4: "Rough/Closed should correlate with Weather cancellations."
# Multiplier on the baseline cancellation probability.
WEATHER_CANCEL_FACTOR = {"Calm": 0.62, "Moderate": 1.00, "Rough": 2.60, "Closed": 5.20}

# Reason mix given a cancellation, conditioned on that day's sea condition.
REASON_BY_CONDITION = {
    "Closed":   {"Weather": .96, "Customer": .03, "Medical": .01},
    "Rough":    {"Weather": .82, "Customer": .13, "Medical": .05},
    "Moderate": {"Weather": .26, "Customer": .55, "Medical": .19},
    "Calm":     {"Weather": .06, "Customer": .70, "Medical": .24},
}

# OTA books cheap and flakes more - planted revenue leak.
CHANNEL_PRICE_FACTOR = {"Walk-in": 1.00, "Website": 0.97, "OTA": 0.82,
                        "Referral": 0.95, "Instagram": 0.98, "Hotel Partner": 0.90}
CHANNEL_CANCEL_FACTOR = {"Walk-in": 0.80, "Website": 1.00, "OTA": 1.45,
                         "Referral": 0.85, "Instagram": 1.05, "Hotel Partner": 1.10}
CHANNEL_NOSHOW_FACTOR = {"Walk-in": 0.70, "Website": 1.00, "OTA": 1.60,
                         "Referral": 0.80, "Instagram": 1.10, "Hotel Partner": 1.20}

BASE_PRICE = {"Discovery Dive": 5500, "Fun Dive": 3800, "Course": 27500}  # INR

# A4 - fictional sites, fixed difficulty per site so the mapping stays consistent.
DIVE_SITES = [
    ("Coral Ridge", "Beginner"), ("Turtle Bay", "Beginner"),
    ("Seagrass Flats", "Beginner"), ("Nemo Garden", "Beginner"),
    ("Lighthouse Reef", "Intermediate"), ("Anchor Point", "Intermediate"),
    ("Pinnacle Rock", "Intermediate"), ("Sunken Barge", "Intermediate"),
    ("Blue Hollow", "Intermediate"), ("The Wall", "Advanced"),
    ("Barracuda Point", "Advanced"), ("Manta Alley", "Advanced"),
    ("Shark Bank", "Advanced"), ("Drift Corner", "Advanced"),
]

# --------------------------------------------------------------------------
# Mess vocabularies (section 4)
# --------------------------------------------------------------------------

NATIONALITY_VARIANTS = {
    "India":          ["India", "india", "IN", "Indian", "INDIA", " India "],
    "United Kingdom": ["United Kingdom", "UK", "uk", "U.K.", "British", "England"],
    "Germany":        ["Germany", "germany", "DE", "German"],
    "Russia":         ["Russia", "russia", "RU", "Russian"],
    "Israel":         ["Israel", "israel", "IL", "Israeli"],
    "France":         ["France", "france", "FR", "French"],
    "United States":  ["United States", "USA", "us", "U.S.A.", "American"],
    "Australia":      ["Australia", "australia", "AU", "Australian"],
    "Italy":          ["Italy", "italy", "IT", "Italian"],
    "South Korea":    ["South Korea", "korea", "KR", "Korean"],
    "Japan":          ["Japan", "japan", "JP", "Japanese"],
    "Netherlands":    ["Netherlands", "netherlands", "NL", "Dutch", "Holland"],
}
NATIONALITY_WEIGHTS = {
    "India": .55, "United Kingdom": .07, "Germany": .06, "Russia": .045,
    "Israel": .04, "France": .04, "United States": .04, "Australia": .03,
    "Italy": .03, "South Korea": .03, "Japan": .025, "Netherlands": .04,
}

DIVE_TYPE_VARIANTS = {
    "Discovery Dive": ["Discovery Dive", "DSD", "discovery dive", "Discovery", "DISCOVERY DIVE"],
    "Fun Dive":       ["Fun Dive", "fun dive", "FUN DIVE", "Fun dive", "fundive"],
    "Course":         ["Course", "course", "COURSE", "PADI Course"],
}
STATUS_VARIANTS = {
    "Completed": ["Completed", "completed", "COMPLETED", " Completed"],
    "Cancelled": ["Cancelled", "cancelled", "CANCELLED", " cancelled "],
    "No-show":   ["No-show", "no-show", "NO-SHOW", "No-Show"],
}

FIRST_NAMES = [
    "Aarav", "Priya", "Rohan", "Ananya", "Vikram", "Meera", "Arjun", "Kavya",
    "Siddharth", "Neha", "Rahul", "Divya", "Karan", "Sneha", "Aditya", "Pooja",
    "James", "Emma", "Lukas", "Sophie", "Daniel", "Hannah", "Marco", "Elena",
    "Yuki", "Minjun", "Olga", "Dmitri", "Noa", "Itai", "Pierre", "Camille",
    "Liam", "Chloe", "Sven", "Anouk", "Tom", "Sarah", "Ravi", "Ishaan",
]
LAST_NAMES = [
    "Sharma", "Patel", "Nair", "Iyer", "Reddy", "Menon", "Gupta", "Desai",
    "Kulkarni", "Banerjee", "Chowdhury", "Rao", "Smith", "Brown", "Muller",
    "Schmidt", "Rossi", "Dubois", "Cohen", "Levi", "Ivanov", "Petrova",
    "Tanaka", "Kim", "Park", "Wilson", "Taylor", "Jansen", "Bakker", "OConnor",
]

CERT_LEVELS = ["None", "Open Water", "Advanced", "Rescue", "Divemaster"]

# --------------------------------------------------------------------------
# Mess injectors
# --------------------------------------------------------------------------


def messy_date(d, rng):
    """Section 4: mixed formats - 2023-06-01 / 01/06/2023 / "June 1 2023"."""
    r = rng.random()
    if r < 0.60:
        return d.strftime("%Y-%m-%d")
    if r < 0.85:
        return "%02d/%02d/%d" % (d.day, d.month, d.year)
    return "%s %d %d" % (MONTH_NAMES[d.month - 1], d.day, d.year)


def messy_case(value, rng):
    """Casing / whitespace noise, used for cert_level."""
    r = rng.random()
    if r < 0.45:
        return value
    if r < 0.62:
        return value.lower()
    if r < 0.76:
        return value.upper()
    if r < 0.86:
        return value + " "
    if r < 0.94:
        return " " + value
    return value.replace(" ", "  ")


def pick(mapping, rng):
    """Weighted choice over a {value: weight} dict."""
    keys = list(mapping.keys())
    return rng.choices(keys, weights=[mapping[k] for k in keys], k=1)[0]


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------


def season_label(d):
    """A2 - trips.season."""
    if d.month in PEAK_MONTHS:
        return "Peak"
    if d.month in SHOULDER_MONTHS:
        return "Shoulder"
    return "Monsoon-Closed"


def season_for_date(d):
    """Which SEASONS entry governs this date (A1). Monsoon days roll into the
    season they precede: Jun-Sep 2024 -> 2024-25, Jun-Sep 2025 -> 2025-26."""
    if d <= date(2024, 5, 31):
        return SEASONS[0]
    if d <= date(2025, 5, 31):
        return SEASONS[1]
    return SEASONS[2]


def daterange(start, end):
    d = start
    while d <= end:
        yield d
        d += timedelta(days=1)


def operating_days():
    """Every day the shop can run a trip, in chronological order."""
    days = []
    for s in SEASONS:
        days.extend(daterange(s["start"], s["end"]))
    for start, end in MONSOON_WINDOWS:
        days.extend(daterange(start, end))
    return sorted(days)


# --------------------------------------------------------------------------
# Generators
# --------------------------------------------------------------------------


def build_weather(rng):
    """One row per date across the full span, so weather_date is a complete PK.

    Section 4 requires Rough/Closed to correlate with Weather cancellations; that
    coupling is applied later, in build_bookings, via WEATHER_CANCEL_FACTOR.
    """
    span_start, span_end = date(2024, 1, 1), date(2026, 5, 31)
    rows, prev = [], None
    for d in daterange(span_start, span_end):
        bucket = season_label(d)
        probs = dict(WEATHER_PROBS[bucket])
        # A10 - 2025-26 runs slightly rougher, so weather is a *partial* alibi.
        if d >= date(2025, 10, 1) and bucket != "Monsoon-Closed":
            probs["Calm"] = max(0.01, probs["Calm"] - 0.03)
            probs["Rough"] += 0.03
        if prev is not None and rng.random() < WEATHER_PERSISTENCE:
            cond = prev
        else:
            cond = pick(probs, rng)
        rows.append({"weather_date": d.isoformat(), "sea_condition": cond})
        prev = cond
    return rows, {r["weather_date"]: r["sea_condition"] for r in rows}


def build_trips(rng):
    """Boat departures. A4: the date is internal only - trips has no date column."""
    trips, index, n = [], {}, 0
    for d in operating_days():
        season = season_for_date(d)
        if d.month in MONSOON_MONTHS:
            n_trips = 1 if rng.random() < MONSOON_TRIP_CHANCE else 0
        else:
            mean = season["trips_per_day"] * MONTH_DEMAND[d.month]
            n_trips = int(mean) + (1 if rng.random() < (mean - int(mean)) else 0)
            if d.weekday() >= 5 and rng.random() < 0.18:
                n_trips += 1
            n_trips = max(1, n_trips)
        for _ in range(n_trips):
            n += 1
            site, difficulty = rng.choice(DIVE_SITES)
            trip = {
                "trip_id": "T%05d" % n,
                "dive_site": site,
                "difficulty": difficulty,
                "boat_capacity": rng.randint(8, 12),
                "season": season_label(d),
            }
            trips.append(trip)
            index[trip["trip_id"]] = {"date": d, "trip": trip, "season": season}
    return trips, index


def new_customer(rng, cid, first_dive_type, channel, first_booking_date):
    """cert_level is drawn consistently with what they first booked."""
    if first_dive_type == "Discovery Dive":
        cert = "None"
    elif first_dive_type == "Fun Dive":
        cert = pick({"Open Water": .55, "Advanced": .28, "Rescue": .09,
                     "Divemaster": .04, "None": .04}, rng)
    else:
        cert = pick({"None": .62, "Open Water": .30, "Advanced": .08}, rng)

    canon_nat = pick(NATIONALITY_WEIGHTS, rng)
    signup = first_booking_date - timedelta(days=rng.randint(0, 10))

    # age: mostly plausible, ~7% null, ~0.6% absurd (section 4: "like 5 or 118")
    r = rng.random()
    if r < 0.07:
        age = None
    elif r < 0.076:
        age = rng.choice([3, 4, 5, 6, 115, 118, 121])
    else:
        age = max(12, min(74, int(rng.gauss(34, 10))))

    return {
        "customer_id": cid,
        "first_name": rng.choice(FIRST_NAMES),
        "last_name": rng.choice(LAST_NAMES),
        "nationality": rng.choice(NATIONALITY_VARIANTS[canon_nat]),
        "age": "" if age is None else str(age),
        "cert_level": messy_case(cert, rng),
        # A8 - ~9% of channel attribution is simply missing
        "acquisition_channel": "" if rng.random() < 0.09 else channel,
        "signup_date": messy_date(signup, rng),
        # internal only, never written:
        "_channel": channel,
        "_cert": cert,
        "_history": [],
    }


def build_bookings(rng, trip_index, weather_by_date):
    bookings, customers = [], []
    course_alumni = []      # did a Course, no Fun Dive yet (course_to_fundive path)
    n_book = n_cust = 0

    for trip_id in sorted(trip_index.keys()):
        meta = trip_index[trip_id]
        d, trip, season = meta["date"], meta["trip"], meta["season"]
        cap = trip["boat_capacity"]
        condition = weather_by_date[d.isoformat()]

        if d.month in MONSOON_MONTHS:
            seats = rng.randint(2, 5)
        else:
            seats = int(round(cap * season["booked_util"] * rng.uniform(0.85, 1.12)))
        seats = max(1, min(cap, seats))
        slots = sorted(rng.sample(range(1, cap + 1), seats))

        for slot in slots:
            n_book += 1
            booking_id = "B%06d" % n_book

            # ---- customer: reuse or create -------------------------------
            customer = None
            forced_type = None
            if customers and rng.random() < season["p_repeat"]:
                if course_alumni and rng.random() < season["p_course_to_fun"]:
                    customer = course_alumni.pop(rng.randrange(len(course_alumni)))
                    forced_type = "Fun Dive"
                else:
                    # recency-weighted: returning divers skew recent
                    pool = customers[-800:] if rng.random() < 0.7 else customers
                    customer = rng.choice(pool)

            # ---- dive_type ------------------------------------------------
            if forced_type:
                dive_type = forced_type
            else:
                cs = season["course_share"]
                dive_type = pick({"Course": cs,
                                  "Discovery Dive": (1 - cs) * 0.42,
                                  "Fun Dive": (1 - cs) * 0.58}, rng)
                # certified divers don't book Discovery Dives
                if customer and customer["_cert"] != "None" and dive_type == "Discovery Dive":
                    dive_type = "Fun Dive"

            if customer is None:
                n_cust += 1
                channel = pick(season["channels"], rng)
                customer = new_customer(rng, "C%05d" % n_cust, dive_type, channel, d)
                customers.append(customer)
            channel = customer["_channel"]

            # ---- num_dives + price (INR) ----------------------------------
            if dive_type == "Discovery Dive":
                num_dives = 1 if rng.random() < 0.88 else 2
                base = BASE_PRICE[dive_type] * num_dives
            elif dive_type == "Fun Dive":
                num_dives = pick({1: .34, 2: .30, 3: .20, 4: .16}, rng)
                base = BASE_PRICE[dive_type] * num_dives
            else:
                num_dives = 4 if rng.random() < 0.55 else 5
                base = BASE_PRICE[dive_type]     # course is packaged, not per-dive

            price = base * CHANNEL_PRICE_FACTOR[channel] * season["price_factor"]
            price = int(round(price * rng.uniform(0.93, 1.08) / 50.0) * 50)

            # ---- status: weather-driven cancellation ----------------------
            p_c = min(0.93, season["p_cancel"] * WEATHER_CANCEL_FACTOR[condition]
                      * CHANNEL_CANCEL_FACTOR[channel])
            p_n = min(0.40, season["p_noshow"] * CHANNEL_NOSHOW_FACTOR[channel])
            if rng.random() < p_c:
                status, reason = "Cancelled", pick(REASON_BY_CONDITION[condition], rng)
                if rng.random() < season["p_null_reason"]:
                    reason = None          # section 4: the mess
            elif rng.random() < p_n:
                status, reason = "No-show", None
            else:
                status, reason = "Completed", None

            if status == "Completed":
                customer["_history"].append(dive_type)
                if dive_type == "Course":
                    course_alumni.append(customer)

            booked = d - timedelta(days=rng.randint(0, 45))

            bookings.append({
                "booking_id": booking_id,
                "customer_id": customer["customer_id"],
                "booking_date": messy_date(booked, rng),      # A7 messy
                "dive_date": d.isoformat(),                   # A7 clean (weather join)
                "dive_type": rng.choice(DIVE_TYPE_VARIANTS[dive_type]),
                "num_dives": str(num_dives),
                "price_inr": str(price),
                "status": rng.choice(STATUS_VARIANTS[status]),
                "cancellation_reason": "" if reason is None else reason,
                "trip_id": trip_id,
                "boat_slot": str(slot),
                # internal only:
                "_channel": channel,
                "_booked_date": booked,
                "_season": season["key"],
            })

    return bookings, customers


def inject_price_outliers(rng, bookings, n_negative=15, n_extreme=8):
    """Section 4: "a few negatives/outliers to catch"."""
    idx = rng.sample(range(len(bookings)), n_negative + n_extreme)
    for i in idx[:n_negative]:
        bookings[i]["price_inr"] = str(-abs(int(bookings[i]["price_inr"])))
    for i in idx[n_negative:]:
        bookings[i]["price_inr"] = str(int(int(bookings[i]["price_inr"]) * rng.uniform(40, 120)))
    return n_negative, n_extreme


def inject_duplicates(rng, bookings, n_dupes=28):
    """Section 4: "a handful of fully duplicated booking_id rows to dedupe".

    Exact whole-row copies scattered through the file (a partial re-import),
    not appended in a block - so dedupe is a real step, not a tail-trim.
    """
    for _ in range(n_dupes):
        src = rng.choice(bookings)
        bookings.insert(rng.randrange(len(bookings) + 1), dict(src))
    return n_dupes


def build_inquiries(rng, bookings):
    """A6 - ~78% of bookings trace to a logged inquiry; the rest are walk-ins.
    Unconverted inquiries are then padded in to hit the target conversion rate."""
    link_rate = 0.78
    target_conversion = {"2023-24": 0.61, "2024-25": 0.53, "2025-26": 0.44}

    inquiries, converted_by_season = [], {s["key"]: 0 for s in SEASONS}
    seen = set()
    n = 0
    for b in bookings:
        if b["booking_id"] in seen:      # duplicate rows are the same real booking
            continue
        seen.add(b["booking_id"])
        if rng.random() >= link_rate:
            continue
        n += 1
        lag = rng.randint(0, 21)
        inquiries.append({
            "inquiry_id": "Q%06d" % n,
            "inquiry_date": (b["_booked_date"] - timedelta(days=lag)).isoformat(),
            "channel": b["_channel"],
            "converted_booking_id": b["booking_id"],
        })
        converted_by_season[b["_season"]] += 1

    for s in SEASONS:
        conv = converted_by_season[s["key"]]
        n_dead = int(round(conv * (1.0 / target_conversion[s["key"]] - 1.0)))
        span = (s["end"] - s["start"]).days
        for _ in range(n_dead):
            n += 1
            inquiries.append({
                "inquiry_id": "Q%06d" % n,
                "inquiry_date": (s["start"] + timedelta(days=rng.randint(0, span))).isoformat(),
                "channel": pick(s["channels"], rng),
                "converted_booking_id": "",
            })

    inquiries.sort(key=lambda r: r["inquiry_date"])
    return inquiries


# --------------------------------------------------------------------------
# Output
# --------------------------------------------------------------------------

TABLES = {
    "inquiries": ["inquiry_id", "inquiry_date", "channel", "converted_booking_id"],
    "customers": ["customer_id", "first_name", "last_name", "nationality", "age",
                  "cert_level", "acquisition_channel", "signup_date"],
    "bookings":  ["booking_id", "customer_id", "booking_date", "dive_date", "dive_type",
                  "num_dives", "price_inr", "status", "cancellation_reason",
                  "trip_id", "boat_slot"],
    "trips":     ["trip_id", "dive_site", "difficulty", "boat_capacity", "season"],
    "weather":   ["weather_date", "sea_condition"],
}


def write_csv(name, rows):
    path = os.path.join(OUT_DIR, name + ".csv")
    cols = TABLES[name]
    with open(path, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=cols, extrasaction="ignore")
        w.writeheader()
        for r in rows:
            w.writerow({c: r.get(c, "") for c in cols})
    return path


def load_sqlite(data):
    """A9 - all TEXT, no PK/FK. Constraints would reject the intentional mess."""
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)
    con = sqlite3.connect(DB_PATH)
    cur = con.cursor()
    for name, cols in TABLES.items():
        cur.execute("CREATE TABLE %s (%s)" % (name, ", ".join("%s TEXT" % c for c in cols)))
        cur.executemany(
            "INSERT INTO %s VALUES (%s)" % (name, ",".join("?" * len(cols))),
            [tuple((r.get(c, "") or None) for c in cols) for r in data[name]],
        )
    con.commit()
    con.close()


def main():
    rng = random.Random(SEED)
    os.makedirs(OUT_DIR, exist_ok=True)

    weather, weather_by_date = build_weather(rng)
    trips, trip_index = build_trips(rng)
    bookings, customers = build_bookings(rng, trip_index, weather_by_date)
    n_neg, n_ext = inject_price_outliers(rng, bookings)
    n_dupes = inject_duplicates(rng, bookings)
    inquiries = build_inquiries(rng, bookings)

    data = {"inquiries": inquiries, "customers": customers, "bookings": bookings,
            "trips": trips, "weather": weather}

    for name in TABLES:
        write_csv(name, data[name])
    load_sqlite(data)

    # ---- run report -------------------------------------------------------
    print("RAW dataset written to %s" % OUT_DIR)
    print("SQLite: %s\n" % DB_PATH)
    for name in TABLES:
        print("  %-10s %6d rows" % (name, len(data[name])))

    uniq = len({b["booking_id"] for b in bookings})
    canon_status = []
    for b in bookings:
        s = b["status"].strip().lower()
        canon_status.append("Cancelled" if s == "cancelled"
                            else "No-show" if s == "no-show" else "Completed")
    n_cancel = canon_status.count("Cancelled")
    n_null_reason = sum(1 for b, s in zip(bookings, canon_status)
                        if s == "Cancelled" and not b["cancellation_reason"])

    print("\n  mess injected")
    print("    duplicated booking_id rows      %d (%d unique ids in %d rows)"
          % (n_dupes, uniq, len(bookings)))
    print("    negative price_inr              %d" % n_neg)
    print("    extreme-high price_inr          %d" % n_ext)
    print("    Cancelled with NULL reason      %d of %d cancellations" % (n_null_reason, n_cancel))
    print("    NULL age                        %d" % sum(1 for c in customers if not c["age"]))
    print("    NULL acquisition_channel        %d" % sum(1 for c in customers
                                                         if not c["acquisition_channel"]))
    print("    distinct nationality strings    %d" % len({c["nationality"] for c in customers}))
    print("    distinct dive_type strings      %d" % len({b["dive_type"] for b in bookings}))
    print("    distinct status strings         %d" % len({b["status"] for b in bookings}))
    print("    distinct cert_level strings     %d" % len({c["cert_level"] for c in customers}))
    print("\n  RAW IS NOT CLEAN BY DESIGN - cleaning is Phase 3 -> data/clean/")


if __name__ == "__main__":
    main()
