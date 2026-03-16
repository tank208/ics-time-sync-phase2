# Methods and Metrics – Phase 2

This document defines the metrics used in the Phase 2 experiments and
documents how they are computed from the collected logs. It is intended
to be precise enough that another researcher can reproduce the numbers
from the raw data.

Phase 2 focuses on three main classes of behavior:

- Per‑node clock error relative to a chosen reference.
- Cascaded behavior of Pi2 relative to Pi1.
- Sensitivity to network load, reference quality, and thermal or
  oscillator effects.

All formulas below assume that timestamps are aligned to a common
reference and that time offsets are expressed in seconds unless stated
otherwise.

---

## 1. Per‑node offset metrics

For each node (Pi1, Pi2) and each run, we form a time series of offset
measurements:

- Let $t_i$ be the wall‑clock time of sample $i$.
- Let $x_i$ be the measured clock offset of the node relative to its
  reference at time $t_i$, in seconds.
  - For Phase 2, $x_i$ is derived from chrony’s tracking / sources
    statistics, parsed into a regularly sampled series.

Given the $N$ valid samples in a run:

### 1.1 Mean offset

$$\bar{x} = \frac{1}{N} \sum_{i=1}^{N} x_i$$

This is the average signed time error of the node over the run.

### 1.2 RMS offset

$$x_{\mathrm{RMS}} = \sqrt{\frac{1}{N} \sum_{i=1}^{N} x_i^2}$$

RMS offset is used as the primary scalar “goodness” metric, and is
compared to representative power‑system requirements (e.g., 100 µs class
targets for synchrophasor/IEC 61850‑style applications).

### 1.3 Maximum offset

$$x_{\max} = \max_{1 \le i \le N} |x_i|$$

This captures the worst absolute deviation during the run.

### 1.4 Percentiles (p50, p95, p99, p99.9)

Let $|x|_{(k)}$ denote the $k^\text{th}$ order statistic of the
sorted absolute offsets $|x_i|$.

For a desired percentile $p \in (0,1)$, we compute

$$k = \lceil p \cdot N \rceil, \quad \text{percentile}_p = |x|_{(k)}$$

and report p50, p95, p99, and p99.9.

These capture the “tail behavior” of the time error distribution.

---

## 2. Exceedance rates

To quantify how often offsets exceed specific thresholds of interest,
we define a set of thresholds $T = \{ 50~\mu\text{s}, 100~\mu\text{s},$
$1~\text{ms}\}$.

For a given threshold $\theta \in T$, the exceedance rate is

$$r(\theta) = \frac{1}{N} \sum_{i=1}^{N} \mathbf{1} \left( |x_i| > \theta \right)$$

where $\mathbf{1}(\cdot)$ is the indicator function.

In the Run 1 analysis, exceedance counts and rates are reported for each
node along with the corresponding sample count $N$.

---

## 3. Allan deviation (ADEV)

Allan deviation is used to characterize the frequency stability of the
node’s clock as a function of averaging time $\tau$. It is computed
from a sequence of fractional frequency values derived from the offset
series, following the standard Allan variance definition.

### 3.1 Construction of fractional frequency series

Let $x(t)$ be the time‑error process (offset in seconds). For a
regular sampling interval $\tau_0$:

- The fractional frequency $y_k$ over the interval
  $[k \tau_0, (k+1)\tau_0]$ is approximated by

  $$y_k = \frac{x((k+1)\tau_0) - x(k\tau_0)}{\tau_0}$$

This yields a discrete series $\{ y_k \}$ representing normalized
frequency error.

### 3.2 Allan variance and Allan deviation

For a chosen averaging time $\tau = m \tau_0$ (where $m$ is a
positive integer) and a series $y_k$, the (non‑overlapping) Allan
variance is

$$\sigma_y^2(\tau) = \frac{1}{2(M - 1)} \sum_{j=1}^{M-1}
\left( \bar{y}_{j+1} - \bar{y}_j \right)^2$$

where:

- $\bar{y}_j$ is the average of $y_k$ over the $j^\text{th}$  block of length $m$,
- $M$ is the number of such blocks in the run.

The Allan deviation is

$$\sigma_y(\tau) = \sqrt{\sigma_y^2(\tau)}$$

In practice, Phase 2 computes ADEV across a logarithmic set of
averaging times $\tau$ (e.g., 10 s to 40,960 s) and stores the
results in CSV files such as:

- `results/examples/pi1_run1_adev.csv`
- `results/examples/pi2_run1_adev.csv`

Plots use log–log axes with $\tau$ on the horizontal axis and ADEV
on the vertical axis, often with a horizontal reference line at 100 µs
to visually compare against utility‑grade targets.

---

## 4. Cascade metrics (Pi2 relative to Pi1)

To understand how time errors propagate through the stratum chain, we
define a differential time‑error process between Pi2 and Pi1.

Let:

- $x^{(1)}_i$ be the offset of Pi1 vs its reference at time $t_i$.
- $x^{(2)}_i$ be the offset of Pi2 vs its reference at time $t_i$.
- Both series are aligned or interpolated so that they share the same
  sampling instants $t_i$.

The cascade error is

$$d_i = x^{(2)}_i - x^{(1)}_i$$

We then compute the same scalar metrics on $d_i$ as on the
per‑node offsets:

- Mean cascade error: $\bar{d} = \frac{1}{N} \sum d_i$.
- RMS cascade error:

  $$d_{\mathrm{RMS}} = \sqrt{\frac{1}{N} \sum d_i^2}$$

- Maximum cascade magnitude:

  $$d_{\max} = \max_i |d_i|$$

- Percentiles p50, p95, p99, p99.9 of $|d_i|$.

These values describe how “tightly” Pi2 follows Pi1 across time.

---

## 5. Event windows and cascade lag

Beyond scalar statistics, Phase 2 identifies time windows where the
offsets exceed a threshold for multiple consecutive samples. These
windows are treated as “events” (e.g., upstream NTP disturbances).

### 5.1 Event window definition

Given a threshold $\theta$ (typically 100 µs):

1. Find all indices $i$ where $|x_i| > \theta$.
2. Group consecutive indices (within a fixed gap tolerance) into
   windows $W_k$.
3. For each window $W_k$:
   - Start time: $t_{\min}(W_k)$
   - End time: $t_{\max}(W_k)$
   - Peak offset: $\max_{i \in W_k} |x_i|$
   - Duration: $t_{\max}(W_k) - t_{\min}(W_k)$

The spike analysis for Run 1 is based on this type of event windowing.

### 5.2 Cascade lag measurement

To quantify how disturbances propagate from Pi1 to Pi2:

1. Identify a primary event window on Pi1 (e.g., a sustained cluster of
   exceedances).
2. Identify the corresponding event window on Pi2.
3. Define the cascade lag as the difference between the first exceedance
   times:

$$\Delta t_{\text{lag}} = t_{\text{first,Pi2}} - t_{\text{first,Pi1}}$$

Phase 2 reports this lag alongside qualitative interpretations (e.g.,
“Stratum 3 → Stratum 4 propagation confirmed”).

---

## 6. Stress‑specific metrics

For phases that introduce additional stressors (network load, degraded
reference, thermal changes, holdover), the following additional metrics
are computed.

### 6.1 Network load (iperf / latency)

Using `iperf3` and `ping` across the Nile switch:

- Throughput per load plateau (e.g., low/medium/high Mbps).
- Packet loss and jitter (UDP).
- Round‑trip time statistics from `ping` (mean, RMS, max, percentiles).

These are correlated in time with offset and cascade metrics to see
whether increased load coincides with changes in time‑error behavior.

### 6.2 Temperature vs offset

From per‑node temperature logs:

- Let $T_i$ be the temperature sample near time $t_i$.
- Compute correlation metrics between $x_i$ and $T_i$:
  - Simple Pearson correlation coefficient.
  - Conditional statistics (e.g., offsets when $T < T_\mathrm{median}$`
    vs $T \ge T_\mathrm{median}$).

The goal is to rule in or rule out thermal causation for observed
spikes or drifts.

### 6.3 Holdover drift metrics

For holdover experiments (reference removed):

- Define $t_0$ as the moment when the node enters holdover.
- Define time‑since‑holdover $\Delta t = t - t_0$.
- Track:

  - Time‑error growth $|x(t)|$ vs $\Delta t$.
  - Time to exceed thresholds: first $\Delta t$ such that
    $|x(t)| > 10~\mu\text{s}$`, `$100~\mu\text{s}$`, `$1~\text{ms}$.

These metrics quantify practical holdover performance of the GPS/RTC
HAT and any NTP‑trained configurations.

---

## 7. Implementation notes

- All computations are performed using Python 3 with `numpy` and
  `pandas`. Analysis scripts live under `scripts/analysis/`.
- Plots are generated with `matplotlib` and saved into
  `results/examples/` or per‑run subdirectories.
- Each run’s analysis script logs the exact parameters used (e.g.,
  thresholds, τ grid, event windowing rules) to support reproducibility.

Future updates to this document will add concrete parameter values and
example code snippets as additional runs (Phase A extended, B1/B2
stress, C1 holdover) are analyzed.
