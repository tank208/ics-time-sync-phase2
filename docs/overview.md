# Overview

## Motivation

Industrial control systems (ICS) and operational technology (OT) increasingly
depend on precise time synchronization. Accurate time underpins:

- Sequence-of-events logging and disturbance analysis.
- Phasor measurement units (PMUs) and sampled values in power systems.
- Cybersecurity controls and forensics in zero-trust architectures.

In many deployments, precise time is provided by dedicated IEEE 1588 / PTP
grandmasters and substation-grade hardware. However, educational labs and
smaller facilities often rely on **commodity equipment** and **NTP-based
solutions**, with little data on what performance is realistically achievable.

This project investigates how far we can push **NTP and PTP-style time
synchronization** using **Raspberry Pi 4B devices** connected through a
**Nile zero-trust Layer 2 switch**, using rigorous measurement techniques
inspired by IEEE C37.238, IEEE 1588 profiles, and classic NTP literature.

## Goals

Phase 2 of the project focuses on:

- Establishing a **baseline** for NTP/chrony performance between cascaded
  Raspberry Pis over an ICS-style, zero-trust network.
- Characterizing not just mean accuracy, but **tail behavior** (rare spikes),
  **Allan deviation** (stability), and **stratum cascade dynamics**.
- Studying how **network load**, **reference quality**, and **thermal
  conditions** affect timing performance.
- Preparing for Phase 3, where a low-cost **GPS/RTC HAT** and GNSS antenna
  will be used to build and evaluate a commodity **grandmaster clock**.

## Approach

The project uses:

- Two Raspberry Pi 4B nodes running Ubuntu Server 24.04.1 with `chrony` as the
  NTP client/server and clock discipline engine.
- A Nile zero-trust switch providing an isolated L2 segment for the lab.
- A Uputronics GPS/RTC Expansion Board for Raspberry Pi, initially used to
  characterize oscillator and holdover behavior (without a GNSS antenna),
  and later as part of a Pi-based grandmaster design.
- Python-based analysis tools to compute:
  - Offset statistics and percentiles.
  - Allan deviation versus averaging time τ.
  - Cascade metrics between the two Pis.
  - Stress-specific metrics such as iperf throughput and jitter.

The same set of metrics is applied consistently across runs and phases, so
that changes in configuration and environment can be compared directly.

For a detailed plan of the Phase 2 work, see
[`roadmap_phase2.md`](roadmap_phase2.md).
