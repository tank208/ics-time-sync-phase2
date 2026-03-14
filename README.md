# ICS Time Synchronization on Commodity Hardware (Phase 2)

This repository contains the Phase 2 work of an ongoing research project on
**time synchronization for industrial control / OT networks** using
commodity hardware (Raspberry Pi 4B) over a **zero-trust L2 switch**.

The focus of Phase 2 is to:

- Quantify NTP/chrony timing accuracy, stability, and tail behavior
  between cascaded Raspberry Pis over a Nile zero-trust switch.
- Study how **network load, reference quality, and thermal conditions**
  affect time synchronization relevant to IEC 61850 / IEEE C37.238-style
  applications.
- Prepare for a future **GNSS-disciplined grandmaster** built from a
  low-cost GPS/RTC HAT and Raspberry Pi.

This repo is the **forward-facing, curated view** of the project used
for sponsors, poster sessions, and artifact sharing. A separate private
lab repository holds full raw logs, DEVLOG notes, and scratch scripts.

---

## Project context

Modern power and industrial control systems rely on precise time for:

- Sequence-of-events logging and disturbance analysis.
- Phasor measurement units (PMUs) and sampled values.
- Secure, zero-trust architectures that still require synchronized clocks.

Most utility deployments use specialized PTP grandmasters and substation-
grade hardware. This project asks:

> How far can we push **NTP and PTP-style time synchronization** using
> **commodity Raspberry Pis and a lab zero-trust switch**, with careful
> measurement and realistic ICS constraints?

Relevant standards and references include IEEE C37.238 and IEEE 1588
power/utility profiles, plus classic NTP discipline and Allan deviation
literature.

---

## Hardware and software

**Hardware**

- 2× Raspberry Pi 4B (ARM64, Ubuntu Server 24.04.1).
- Nile zero-trust L2 switch (isolated lab network).
- Uputronics GPS/RTC Expansion Board for Raspberry Pi (for later holdover /
  grandmaster work; antenna planned in a future phase).

**Software**

- Ubuntu 24.04.1 LTS (ARM64), Linux kernel 6.8.x (raspi).
- `chrony` as the NTP client/server and clock discipline engine.
- `iperf3` and `ping` for network load and latency measurement.
- Python 3 with `pandas`, `numpy`, `matplotlib` for analysis.

---

## Phase 2 roadmap (high level)

Phase 2 is organized into four sub-phases:

- **Phase A – Baseline NTP on Nile**  
  - Pi1 as NTP client of Internet/public sources (stratum 3/4).  
  - Pi2 as NTP client of Pi1 (stratum 4/5).  
  - Long runs (≈40 h and ≈120+ h) to characterize offsets, Allan deviation,
    and rare tail events under normal load.

- **Phase B1 – Network / UDP Stress**  
  - Same NTP/chrony configuration as Phase A.  
  - Controlled low/medium/high background load using iperf (UDP/TCP)
    across the Nile switch.  
  - Goal: quantify how tails and cascade behavior change as the network
    is stressed.

- **Phase B2 – Single-Variable Sensitivity**  
  - Either (a) degraded NTP reference quality, or (b) controlled thermal
    changes, but not both at once.  
  - Goal: isolate how specific factors influence timing performance.

- **Phase C1 – Holdover with GPS/RTC HAT**  
  - Use the Uputronics HAT on a Pi4B to study free-running and
    NTP-trained holdover behavior (no GNSS antenna yet).  
  - Goal: measure how long the HAT-based clock stays within ±10 µs,
    ±100 µs, and ±1 ms thresholds after losing its reference.

A future Phase 3 (not in this repo yet) will add a GNSS antenna and
evaluate a Pi-based grandmaster / PTP deployment.

Details of the roadmap and methods are in
[`docs/roadmap_phase2.md`](docs/roadmap_phase2.md).

---

## Data and metrics

The project uses a consistent set of metrics for every run:

- Per-node offset statistics (vs chosen reference):  
  - Mean, RMS, max, p50, p95, p99, p99.9.  
  - Exceedance rates above 50 µs, 100 µs, 1 ms.

- Allan deviation (ADEV) vs averaging time τ to separate short-term jitter
  from long-term wander.

- Cascade metrics (Pi2 relative to Pi1):  
  - Mean/RMS/max of |Pi2–Pi1|.  
  - Event windows with cascade lag, peak offsets, and recovery times.

- Stress-specific metrics (when applicable):  
  - iperf throughput/jitter/loss per load plateau.  
  - Temperature vs offset correlations.  
  - Holdover drift and time-to-exceed error thresholds.

The definitions and formulas are documented in
[`docs/methods_metrics.md`](docs/methods_metrics.md).

---

## Repository layout

Planned layout of this public repository:

```text
├── README.md               # This file
├── LICENSE
├── docs/
│   ├── overview.md         # Project narrative and context
│   ├── roadmap_phase2.md   # Detailed plan for Phases A, B1, B2, C1
│   ├── methods_metrics.md  # Metric definitions and analysis approach
│   └── glossary.md         # Timing & ICS terminology used in the repo
├── scripts/
│   ├── collection/         # Example collection scripts (sanitized)
│   └── analysis/           # Reusable analysis tools (e.g. offset/ADEV/cascade)
├── results/
│   ├── examples/           # Selected plots & tables from key runs
│   └── README.md           # Description of included example artifacts
└── (no raw data committed here)
```

## Contact

This project is conducted as part of an undergraduate research effort in  cybersecurity and OT/ICS. For questions or collaboration, please contact  the maintainer via GitHub issues or email (listed on the profile).