# As-Is Process Flow — Booking Lifecycle

Project: scuba-dive-analytics (local folder: Scuba). Phase 1.

This page shows how a customer moves through the dive centre today, from first
inquiry to the end of the trip. The red nodes mark the failure points behind the
findings in [`FINDINGS.md`](FINDINGS.md) §2. They are labelled **F1–F5**, matching
insights ①–⑤.

```mermaid
flowchart TD
    %% ---------- INQUIRY ----------
    subgraph INQ["1 · Inquiry"]
        A1(["Customer inquires<br/>Walk-in · OTA · Website · Referral · Instagram · Hotel Partner"])
        A2["Front desk answers questions<br/>and quotes the price"]
        A3{"Customer books?"}
        A4["Inquiry lost<br/>no follow-up"]
    end

    %% ---------- BOOKING ----------
    subgraph BKG["2 · Booking"]
        B1{"Booking path"}
        B2["Direct booking<br/>entered by front desk"]
        B3["OTA booking<br/>imported from partner platform"]
        B4["Seat assigned on trip<br/>no deposit taken"]
        F5a[/"⚠ F5 · acquisition_channel optional<br/>9.0% of customers, ₹50,96,000 unattributed"/]
        F3a[/"⚠ F3 · OTA path: no deposit, free cancellation<br/>avg price ₹8,167 vs ₹11,090 walk-in"/]
    end

    %% ---------- PRE-TRIP ----------
    subgraph PRE["3 · Pre-trip"]
        C1["Booking sits untouched<br/>until dive day"]
        F2a[/"⚠ F2 · no risk check or confirmation call<br/>795 non-weather cancellations, ₹79,77,635"/]
        C2{"Customer cancels?"}
        C3["Front desk marks Cancelled"]
        F5b[/"⚠ F5 · cancellation_reason optional<br/>19.6% of 2025-26 cancellations have no reason"/]
        C4["Seat released<br/>usually too late to resell"]
    end

    %% ---------- TRIP ----------
    subgraph TRP["4 · Trip day"]
        D0["Departures run on a fixed schedule<br/>regardless of load"]
        F1a[/"⚠ F1 · capacity_utilization 54.5%<br/>626 seats never sold + 750 sold-then-lost"/]
        D1{"Customer shows up?"}
        D2["No-show<br/>seat sails empty, ₹0 revenue"]
        D3["Dive completed<br/>revenue recognised"]
    end

    %% ---------- POST-TRIP ----------
    subgraph PST["5 · Post-trip"]
        E1{"Product?"}
        E2["Course graduate certified<br/>instructor says goodbye"]
        F4a[/"⚠ F4 · no graduate re-engagement<br/>course_to_fundive_conversion 39.5% → 4.8%"/]
        E3["Fun Dive / Discovery customer leaves"]
        E4(["Customer relationship ends<br/>79.9% of divers never return"])
    end

    A1 --> A2 --> A3
    A3 -- No --> A4
    A3 -- Yes --> B1
    B1 -- Direct --> B2 --> B4
    B1 -- OTA --> B3 --> B4
    B2 -.-> F5a
    B3 -.-> F3a
    B4 --> C1
    C1 -.-> F2a
    C1 --> C2
    C2 -- Yes --> C3 --> C4
    C3 -.-> F5b
    C2 -- No --> D0
    D0 -.-> F1a
    D0 --> D1
    D1 -- No --> D2
    D1 -- Yes --> D3 --> E1
    E1 -- Course --> E2
    E2 -.-> F4a
    E2 --> E4
    E1 -- "Fun Dive / Discovery" --> E3 --> E4

    classDef fail fill:#fde2e1,stroke:#c0392b,color:#7b1f17,stroke-width:2px
    classDef lost fill:#f2f2f2,stroke:#888,color:#444
    class F1a,F2a,F3a,F4a,F5a,F5b fail
    class A4,C4,D2,E4 lost
```

## Failure points

| Label | Where it happens | What goes wrong | Measured impact | FINDINGS ref |
|---|---|---|---|---|
| **F1** | Trip day: scheduling | Departures run at fixed times however many seats are booked. Booked seats are lost, and other seats are never sold | `capacity_utilization` 58.0% → **54.5%**. 2025-26: **750 seats sold then lost, 626 never sold** | §2① · `sql/01 Q2` |
| **F2** | Pre-trip | Nobody contacts bookings that are likely to cancel. Most cancellations happen on diveable days | **795 non-weather cancellations (59.6%), ₹79,77,635**. On calm or moderate days 12.7% of bookings cancel, and these days account for 58.9% of all cancellations | §2② · `sql/06 Q1–Q3` |
| **F3** | Booking: OTA path | OTA bookings carry no deposit, so cancelling costs the customer nothing | OTA `cancellation_rate` **27.8%**, `no_show_rate` **7.5%**, **486 seats lost**, `customer_ltv` ₹9,533 | §2③ · `sql/06 Q4–Q5` |
| **F4** | Post-trip: course | Graduates are not contacted after certification | `course_to_fundive_conversion` **39.5% → 16.1% → 4.8%**. 90-day check: 27.8% → 3.7% | §2④ · `sql/03 Q3–Q4` |
| **F5** | Booking and cancellation capture | `acquisition_channel` and `cancellation_reason` can be left blank | No-reason cancellations **7.7% → 19.6%**. **₹50,96,000 (9.3%)** of revenue has no channel | §2⑤ · `sql/02 Q6` |

The matching redesign is in [`TO_BE_FLOW.md`](TO_BE_FLOW.md).
