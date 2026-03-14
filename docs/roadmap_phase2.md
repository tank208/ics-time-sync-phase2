# Phase 2 Roadmap – ICS Time Synchronization on Nile

This document describes the Phase 2 plan for evaluating NTP-based time
synchronization between Raspberry Pi 4B devices over a Nile zero-trust
switch, and for preparing holdover characterization with a GPS/RTC HAT.

Phase 3 (not covered here) will extend this work to a GNSS-locked
grandmaster and PTP deployments.

---

## 1. Common Metrics and Methods

All Phase 2 runs use a consistent analysis toolkit:

- **Offset statistics** (per node vs reference):
  - Mean, RMS, maximum |offset| [µs].
  - Percentiles: p50, p95, p99, p99.9 [µs].
  - Exceedance rates above 50 µs, 100 µs, and 1 ms.

- **Allan deviation (ADEV)**:
  - ADEV vs averaging time τ (e.g., 10 s up to a fraction of the run length),
    to distinguish short-term jitter from long-term wander.

- **Cascade metrics (Pi2 relative to Pi1)**:
  - Mean, RMS, max of |Pi2–Pi1| [µs].
  - Event windows where offsets exceed 100 µs on either node, with:
    - Window start/end times.
    - Cascade lag: time from Pi1 first crossing 100 µs to Pi2 first crossing.
    - Peak offsets for Pi1 and Pi2 within the window.
    - Recovery time: time from window end until both nodes remain within
      ±20 µs.

- **Stress-specific metrics** (when applicable):
  - Network load: iperf throughput, jitter, and loss for each plateau.
  - Temperature: time series of device temperature, offset vs temperature
    correlations.
  - Holdover: drift rates and time until offsets exceed ±10 µs, ±100 µs,
    ±1 ms after loss of reference.

Definitions and calculation details are in
[`methods_metrics.md`](methods_metrics.md).

---

## 2. Phase A – Baseline NTP on Nile

**Objective**

Establish the nominal performance of NTP/chrony between two cascaded Raspberry
Pis over the Nile switch, under normal network load and stable configuration.

**Topology**

- Pi1:
  - NTP client of selected Internet/public NTP servers.
  - Acts as local NTP server for downstream nodes.
- Pi2:
  - NTP client of Pi1 only (a stratum below Pi1).
- Both Pis connected to a Nile zero-trust Layer 2 switch on a dedicated VLAN.

**Runs**

- **Run1 – 40-hour baseline**  
  - Initial characterization of offsets, ADEV, and rare spike behavior.

- **Run2 – 120+ hour baseline**  
  - Longer run with identical configuration to:
    - Validate Run1 results.
    - Improve statistical confidence for tails and large-τ ADEV.

**Deliverables**

- Per-node offset statistics and ADEV curves for both runs.
- Cascade metrics and event-window analysis for Run1 and Run2.
- Short report section demonstrating:
  - RMS offsets well below 100 µs.
  - Rare excursions and their likely causes (e.g., upstream NTP disturbances).
  - Consistency between Run1 and Run2.

This establishes a **baseline NTP-on-Nile performance envelope** to compare
against later stress tests and holdover experiments.

---

## 3. Phase B1 – Network / UDP Stress (Run3)

**Objective**

Determine how NTP performance degrades as the Nile network is stressed with
increasing background load, while keeping the NTP/chrony configuration fixed.

**Design**

- Topology and chrony configuration identical to Phase A.
- Introduce controlled background traffic (Pi-to-Pi or Pi-to-host) using
  iperf (UDP and/or TCP) across the Nile switch.
- At least three load plateaus, for example:
  - Low: ~10–20 Mbit/s.
  - Medium: ~100–200 Mbit/s.
  - High: ~400–500 Mbit/s (near measured link capacity).

Load may be applied as separate runs per plateau or as clearly segmented
time windows within a single multi-day run.

**Measurements**

- Same timing metrics as Phase A.
- Per-plateau iperf logs (throughput, jitter, loss).
- Optional: Nile switch port counters (utilization, drops, errors).

**Deliverables**

- Tables and plots comparing offset statistics, tails, and cascade metrics
  across load levels vs the Phase A baseline.
- Discussion of how network load affects timing, in the language of
  ICS/utility timing requirements (e.g., sensitivity of 100 µs and 1 ms
  error budgets).

---

## 4. Phase B2 – Single-Variable Sensitivity (Run4)

**Objective**

Isolate the impact of either **reference quality** or **thermal environment**
on timing performance, using the same analysis methods as Phases A and B1.

Two mutually exclusive options for Run4:

### Option B2-R – Reference Quality

- Introduce a deliberately degraded NTP source (e.g., higher jitter, unstable
  offset) while still using chrony’s selection and weighting.
- Observe how:
  - Per-node offset statistics and tails change.
  - chrony chooses between good and bad servers.
  - Cascade behavior responds when the bad server influences Pi1.

### Option B2-T – Thermal Environment

- Change thermal conditions in a controlled way (e.g., partial enclosure to
  raise device temperature by 10–15 °C).
- Analyze:
  - Offset vs temperature correlations.
  - Changes in ADEV at longer τ.
  - Any change in rare-spike behavior.

**Deliverables**

- Same core timing metrics as earlier phases.
- Small set of reference/thermal-specific plots.
- “Sensitivity to Reference Quality / Thermal Environment” section that
  informs future hardware and configuration choices.

---

## 5. Phase C1 – Holdover with GPS/RTC HAT (No GNSS Antenna Yet)

**Objective**

Characterize how a low-cost GPS/RTC HAT improves oscillator quality and
holdover behavior compared to a bare Raspberry Pi crystal, in preparation
for a future GNSS-locked grandmaster.

**Hardware**

- Uputronics GPS/RTC Expansion Board installed on one Pi4B (“HAT-Pi”).
- Initially no GNSS antenna; focus is on oscillator and RTC behavior.

**Campaigns**

1. **Free-running comparison**

   - HAT-Pi: local clock driven by HAT oscillator, no NTP servers.
   - Reference Pi: bare Pi crystal, also free-running (or observed against
     a stable NTP-disciplined node).
   - Duration: 24–72 hours.
   - Goal: measure intrinsic drift and ADEV of each oscillator.

2. **NTP-trained holdover**

   - Phase 1: HAT-Pi disciplined by NTP/chrony for a specified training
     period (e.g., 4, 12, 24 hours).
   - Phase 2: external NTP sources disabled; HAT-Pi runs in holdover using
     its trained oscillator.
   - Offsets logged against a still-disciplined reference Pi.

**Metrics**

- Drift rate during free-run and holdover [µs/hour].
- Time to exceed ±10 µs, ±100 µs, and ±1 ms error thresholds.
- ADEV comparison for bare Pi vs HAT in free-run and holdover regimes.

**Deliverables**

- “Holdover Performance of Commodity GPS/RTC HAT on Raspberry Pi” report
  section.
- Data supporting design decisions for a future Pi-based grandmaster (Phase 3).

---

## 6. Beyond Phase 2 – Outlook

Phase 2 builds:

- A rigorous baseline for NTP on Nile with cascaded Pis.
- An understanding of how network load, reference quality, temperature,
  and oscillator quality affect timing.
- A quantitative picture of what can be achieved with commodity hardware.

Phase 3 will extend this work by:

- Adding a GNSS antenna to the GPS/RTC HAT on HAT-Pi.
- Implementing a GNSS-locked Pi-based grandmaster.
- Evaluating NTP and PTP performance against the Phase 2 baseline under
  similar stress scenarios.

Those steps will be documented in a separate Phase 3 roadmap.
