# To-Be Process Flow — Booking Lifecycle After R1–R5

Project: scuba-dive-analytics (local folder: Scuba). Phase 5.

This is the same lifecycle as [`AS_IS_FLOW.md`](AS_IS_FLOW.md), redesigned with all
five recommendations in place. Green nodes are new controls. Each one is tagged with
its recommendation (**R1–R5**) and business requirement (**BR-xx**, see
[`BRD.md`](BRD.md)).

```mermaid
flowchart TD
    %% ---------- INQUIRY ----------
    subgraph INQ["1 · Inquiry"]
        A1(["Customer inquires<br/>Walk-in · OTA · Website · Referral · Instagram · Hotel Partner"])
        A2["Front desk answers and quotes"]
        A3{"Customer books?"}
        A4["Inquiry closed"]
    end

    %% ---------- BOOKING ----------
    subgraph BKG["2 · Booking"]
        R4a["R4 · BR-08<br/>acquisition_channel REQUIRED<br/>fixed list, no blank"]
        R4p["R4 · BR-09<br/>price validated at entry"]
        B1{"Booking path"}
        B2["Direct booking"]
        B3["OTA booking imported"]
        R2a{"R2 · BR-03<br/>Deposit received?"}
        R2b["Seat held pending deposit<br/>released if unpaid"]
        B4["Seat confirmed on trip"]
    end

    %% ---------- SCHEDULING ----------
    subgraph SCH["Scheduling, runs weekly"]
        R5a["R5 · BR-11<br/>Plan departures from seasonality_index<br/>and booked load per slot"]
        R5b{"Departure under-filled<br/>48h out?"}
        R5c["Consolidate onto a nearby departure<br/>customer notified"]
    end

    %% ---------- PRE-TRIP ----------
    subgraph PRE["3 · Pre-trip"]
        R1a["R1 · BR-01<br/>Model scores booking daily"]
        R1b{"Risk decile 1–3?"}
        R1c["R1 · Confirmation call 48h out<br/>confirm, or offer reschedule"]
        R1d["R1 · BR-02<br/>Log call outcome"]
        C2{"Customer cancels?"}
        R4b["R4 · BR-07<br/>cancellation_reason REQUIRED<br/>Weather · Customer · Medical · Other"]
        C4["Seat released early<br/>back on sale"]
    end

    %% ---------- TRIP ----------
    subgraph TRP["4 · Trip day"]
        D1{"Customer shows up?"}
        D2["No-show<br/>OTA deposit retained"]
        D3["Dive completed<br/>revenue recognised"]
    end

    %% ---------- POST-TRIP ----------
    subgraph PST["5 · Post-trip"]
        E1{"Product?"}
        R3a["R3 · BR-06<br/>Instructor logs cert date + consent"]
        R3b["R3 · BR-05<br/>Day 30–45: automated fun-dive offer"]
        R3c{"Booked by day 90?"}
        R3d["One reminder before day 90"]
        E3["Fun Dive / Discovery customer leaves<br/>channel known for attribution"]
        E5(["Graduate returns as Fun Diver"])
    end

    %% ---------- MEASUREMENT ----------
    M1[["BR-10 · BR-12<br/>Dashboard: ten KPIs by season,<br/>Unknown-share data-quality tiles"]]

    A1 --> A2 --> A3
    A3 -- No --> A4
    A3 -- Yes --> R4a --> R4p --> B1
    B1 -- Direct --> B2 --> B4
    B1 -- OTA --> B3 --> R2a
    R2a -- Yes --> B4
    R2a -- No --> R2b
    B4 --> R1a --> R1b
    R5a --> R5b
    R5b -- Yes --> R5c --> R1b
    R1b -- Yes --> R1c --> R1d --> C2
    R1b -- No --> C2
    C2 -- Yes --> R4b --> C4
    C2 -- No --> D1
    D1 -- No --> D2
    D1 -- Yes --> D3 --> E1
    E1 -- Course --> R3a --> R3b --> R3c
    R3c -- Yes --> E5
    R3c -- No --> R3d --> E5
    E1 -- "Fun Dive / Discovery" --> E3
    D3 -.-> M1
    R1d -.-> M1
    R4b -.-> M1

    classDef new fill:#e3f4e8,stroke:#1e8449,color:#145a32,stroke-width:2px
    classDef measure fill:#e8eef9,stroke:#2e5c9a,color:#1b3a63
    class R1a,R1b,R1c,R1d,R2a,R2b,R3a,R3b,R3c,R3d,R4a,R4b,R4p,R5a,R5b,R5c new
    class M1 measure
```

## What changed, and which As-Is failure each change closes

| Rec | New control | Closes | Evidence it is aimed at | Trigger / rule |
|---|---|---|---|---|
| **R1** | Daily risk scoring and a confirmation call for deciles 1–3 | F2 | Top 3 deciles = **58.1% of cancellations in 30% of bookings**, precision 49.8% (FINDINGS §3) | Dive date minus 48 h. Decile 1–3 only. The model picks the group; it does not give a probability per booking |
| **R2** | Deposit gate on the OTA path | F3 | OTA `cancellation_rate` 27.8%, `no_show_rate` 7.5%, 486 seats lost (FINDINGS §2③) | Seat is not confirmed until the deposit lands. Deposit size is set by the owner (see OQ-2) |
| **R3** | Automated graduate re-engagement | F4 | 69% of returns happen within 90 days, median **49 days** (FINDINGS §2④) | Offer at day 30–45, one reminder before day 90 |
| **R4** | Mandatory `acquisition_channel` and `cancellation_reason`, plus price validation | F5 | 19.6% of cancellations have no reason. ₹50,96,000 has no channel (FINDINGS §2⑤) | A record cannot be saved with these fields blank |
| **R5** | Departures planned against demand. Under-filled boats consolidated | F1 | `capacity_utilization` 54.5%. 626 seats never sold. Jan index 192 vs Jul–Aug 0 (FINDINGS §1, §2①) | Weekly review. Consolidate at 48 h |

> **Open items carried from [`BRD.md`](BRD.md) §6.** If the shop already takes
> deposits (**OQ-2**), the R2 gate means *enforcing the deposit on OTA* rather than
> introducing one. The Peak/Shoulder split R5 plans against (**OQ-4**) is an
> assumption until the owner confirms it.
