# PHASE 2 MASTER REFERENCE
## Low-Cost Timing Synchronization for Rural Substations
**Researcher**: William Hall, DeVlieg Scholar — University of Idaho CIIR  
**Sponsors**: Idaho Power / Schweitzer Engineering Laboratories (SEL)  
**Advisors**: Dr. John Shovic (PI) · Dr. Mary Everett (Assistant PI)  
**Last Updated**: 2026-03-24

---

## 1. INFRASTRUCTURE QUICK REFERENCE

### Network
| Node | IP | Role | Stratum | NTP Source |
|---|---|---|---|---|
| pi-jitter-1 | 192.168.50.10 | NTP server | 4 | time.cloudflare.com (GPS-disciplined, UTC-traceable) |
| pi-jitter-2 | 192.168.50.11 | NTP client | 5 | 192.168.50.10 (pi-jitter-1) |
| T14 (tank208) | 192.168.50.3 | Control node | N/A | NILE interface enp2s0f0 |
| X1C7 (tank208) | 192.168.50.34 | tshark capture node | N/A | enx607d09b72874 (USB-C GigE) |

### SSH
```bash
ssh rpi@192.168.50.10      # Pi1
ssh rpi@192.168.50.11      # Pi2
ssh tank208@192.168.50.34  # X1C7
```

### Key Paths
| Location | Path |
|---|---|
| Run data (T14) | ~/Research/phase2_data/run{N}/ |
| Scripts (T14) | ~/Research/ |
| Python analysis | ~/Research/phase2_scripts/ |
| Pi offset logs | ~/pi{1,2}_offsets_run{N}.txt |
| Pi thermal logs | ~/pi{1,2}_thermal_run{N}.txt |
| Pi tshark captures | ~/run{N}_captures/ |
| X1C7 captures | ~/run{N}_captures/ |

### Compliance Threshold
**IEEE C37.238-2017**: 100 µs RMS offset — hard pass/fail for protective relay timing

---

## 2. NILE ARCHITECTURE NOTES

- NILE **routes** not switches the 192.168.50.0/24 subnet via proxy-ARP
- All inter-node traffic traverses the NILE router — confirmed by TTL=59 on ping (5 hops consumed)
- Pi1↔Pi2 NTP exchanges are NOT visible to a passive third-party capture node (Zero Trust prevents lateral observation)
- X1C7 capture node sees: Pi1↔Cloudflare exchanges only (as third-party witness)
- Pi node captures see: all their own traffic (endpoint capture is the correct methodology)
- Switch port counters/SPAN ports: not available on NILE Zero Trust infrastructure — document as architecture constraint
- NILE IT contact: Dave Beeston (beeston@uidaho.edu) — authorized X1C7 personal device 2026-03-24
- X1C7 Tailscale interface generates its own NTP traffic visible in pcap captures — these packets are X1C7's personal NTP pool, not research traffic. Filter to 192.168.50.x addresses only when analyzing X1C7 captures.
---

## 3. RUN EXECUTION ORDER

Every run follows this exact sequence. Do not deviate.

```
./phase2_startup.sh {N}         # Start collectors + iperf3 server
./phase2_tshark.sh start {N}    # Start packet capture on all 3 nodes
./phase2_saturation.sh {N}      # Deploy sat_run to Pi2 (laptop can disconnect after)

[ Soak period — minimum 24 hours ]

./phase2_tshark.sh stop {N}     # Stop captures BEFORE shutdown
./phase2_shutdown.sh {N}        # Stop collectors, pull all data
./phase2_tshark.sh pull {N}     # Pull pcap files to T14
python3 ~/Research/phase2_scripts/phase2_analyze.py --run {N} --datadir ~/Research/phase2_data/run{N} --outdir ~/Research/phase2_data/run{N}
```

**Critical**: tshark stop MUST precede shutdown — pcap files must be closed before data pull.

---

## 4. MONITORING COMMANDS

```bash
# Check saturation progress on Pi2
ssh rpi@192.168.50.11 "tail -f /tmp/saturation_log_run{N}.txt"

# Check collectors running
ssh rpi@192.168.50.10 "pgrep -f offset_collector && pgrep -f thermal_collector"
ssh rpi@192.168.50.11 "pgrep -f offset_collector && pgrep -f thermal_collector"

# Check iperf3 server on Pi1
ssh rpi@192.168.50.10 "ss -tlnp | grep 5201"

# Check tshark running on all nodes
ssh rpi@192.168.50.10 "pgrep -a tshark"
ssh rpi@192.168.50.11 "pgrep -a tshark"
ssh tank208@192.168.50.34 "pgrep -a tshark"

# Check live offset on Pi1
ssh rpi@192.168.50.10 "tail -3 ~/pi1_offsets_run{N}.txt"

# Check live offset on Pi2
ssh rpi@192.168.50.11 "tail -3 ~/pi2_offsets_run{N}.txt"

# Verify bad NTP source still absent (wire level)
# Run after shutdown — open pcap in Wireshark, filter: ip.addr == 23.142.248.8
```

---

## 5. COMPLETED RUNS

### Run 1 — Clean Baseline Soak
- **Duration**: ~40 hours
- **Load**: None
- **Result**: IEEE C37.238 compliant
  - Pi1 RMS: 13.835 µs (7.2× margin)
  - Pi2 RMS: 10.626 µs (9.4× margin)
- **Key Finding**: Upstream NTP source 23.142.248.8 causing servo correction spikes — offsets 60–80ms higher than Cloudflare while chrony polled both simultaneously
- **Cascade lag confirmed**: 4m 31s between Pi1 and Pi2 spike onsets — correct stratum chain behavior
- **Network**: 450 Mbit/s TCP, 0.016ms UDP jitter, 0% packet loss
- **tshark**: Not yet deployed

### Run 2 — Bad Source Removed
- **Duration**: 24+ hours
- **Load**: None
- **Changes**: 23.142.248.8 removed from chrony.conf, `maxdistance 0.050` added
- **Result**: IEEE C37.238 compliant — validates source removal fix
- **Key Finding**: Spike behavior eliminated after bad source removal
- **tshark**: Not yet deployed

### Run 3 — Verification / Script Integrity
- **Duration**: Short verification run
- **Load**: None
- **Purpose**: Pre-characterization verification before primary runs
- **Critical Finding**: Shutdown scripts had live processes not being killed:
  - chrony capture loop
  - iperf3 server log
  - offset tracking loop
  - thermal tracking loop
  - All active on both Pi1 and Pi2
- **Resolution**: All processes identified and killed. phase2_startup.sh, phase2_shutdown.sh, and all collector scripts rewritten with verified process termination
- **Significance**: Run 4 data is clean as a direct result of these corrections. Methodological integrity finding — not a failure
- **tshark**: Not yet deployed

### Run 4 — Primary Characterization (120-hour soak)
- **Duration**: 118.47 hours
- **Load**: iperf3 saturation intended but server never started (Connection Refused on all 6 burst/UDP logs)
  - Root cause: saturation.sh deployed clients before server was started
  - Recovery runs executed 2026-03-24 after run closed (not time-coincident with chrony soak)
- **Result**: IEEE C37.238 compliant throughout
  - Pi1 RMS: 12.83 µs (7.8× margin), end-state: 7.19 µs
  - Pi2 RMS: 14.42 µs (6.9× margin), end-state: 13.04 µs
- **Effective classification**: No-load baseline on NILE — complements Run 1/2
- **OADEV**: Monotonically decreasing — servo noise floor dominance confirmed, not oscillator instability
- **Thermal**: Pi1 mean 32.2°C, Pi2 mean 37.0°C — no throttling events
- **Spikes**: Pi1 1.23% samples >50µs, Pi2 1.71% — correlation analysis pending
- **Script fixes applied before Run 5**:
  - startup.sh: iperf3 failure now hard exits (not silent continue)
  - saturation.sh: hard port 5201 gate added — exits if not listening before deploying sat_run
  - startup.sh: pgrep alternation fixed (separate calls, not `\|`)
  - startup.sh: sudo cat replaces wc < for chrony log baseline
  - Pi1 and Pi2: /etc/sudoers.d/chrony-cat added for passwordless chrony log access
- **tshark**: Not deployed (tshark infrastructure built during this run's closure)

### Run 5 — High Plateau Saturation (IN PROGRESS)
- **Started**: 2026-03-24T23:21:39Z
- **Expected minimum shutdown**: 2026-03-26T12:00 local (Thursday noon return)
- **Load**: Phase A 60-min quiet baseline → 3× TCP burst cycles (300s each, 4 streams) + UDP tests (100M, 120s) → extended chrony soak
- **Plateau target**: High (~450 Mbit/s TCP saturation)
- **tshark**: Active on Pi1, Pi2, X1C7 — filter: udp port 123 or port 5201
- **Saturation PID on Pi2**: 1653944
- **New instrumentation**: First run with tshark packet capture on all three nodes
- **Result**: PENDING

---

## 6. B1 PLATEAU ROADMAP

| Run | Plateau | Target Rate | Status |
|---|---|---|---|
| Run 1/2/4 | No load (baseline) | 0 Mbit/s | ✅ Complete |
| Run 5 | High | ~450 Mbit/s | 🔄 In progress |
| Run 6 | Medium | ~150 Mbit/s | ⏳ Thu → Fri |
| Run 7 | Low | ~15 Mbit/s | ⏳ Fri → Mon |

**B1 Deliverable**: "Impact of Network/UDP Load on NTP Time Synchronization over Nile" — stats, ADEV, CDF/CCDF per plateau, IEEE C37.238/PTP language

---

## 7. PLANNED SCHEDULE

| Day | Action |
|---|---|
| Tue 2026-03-24 | Run 5 started — high plateau |
| Thu 2026-03-26 noon | Return — shutdown Run 5, pull, analyze |
| Thu 2026-03-26 ~3pm | Start Run 6 — medium plateau |
| Fri 2026-03-27 ~3pm | Return — shutdown Run 6, pull, analyze |
| Fri 2026-03-27 ~5pm | Start Run 7 — low plateau |
| Mon 2026-03-30 noon | Return — shutdown Run 7, pull, analyze |
| Mon 2026-03-30 afternoon | Cross-run comparison analysis |
| Tue/Wed 2026-03-31/04-01 | B1 findings report compilation |

---

## 8. TSHARK METHODOLOGY

### Architecture
| Node | Interface | Captures | Limitation |
|---|---|---|---|
| Pi1 | eth0 | Pi1↔Cloudflare + Pi2 requests to Pi1 | None |
| Pi2 | eth0 | Pi2↔Pi1 stratum cascade | None |
| X1C7 | enx607d09b72874 | Pi1↔Cloudflare only (third-party witness) | NILE routes inter-node traffic — cannot see Pi1↔Pi2 |

### Filter Applied
```
udp port 123 or port 5201
```
NTP exchanges + iperf3 load traffic. Never capture unfiltered during saturation — unfiltered at 450 Mbit/s would generate ~1 TB/5hr.

### File Size Estimates
| Scenario | Duration | Size |
|---|---|---|
| NTP only, stable | 48hr | ~6 MB |
| NTP + iperf3 | 48hr | ~100 MB |
| Unfiltered saturation | 5hr | ~1 TB — NEVER do this |

### Post-Run Analysis
```bash
# Export NTP timestamps to CSV
tshark -r pi1_run{N}.pcap \
  -Y "ntp" \
  -T fields \
  -e frame.time_epoch \
  -e ip.src \
  -e ip.dst \
  -e ntp.stratum \
  -E header=y -E separator=, \
  > ntp_packets.csv

# Audit bad source absent
# Wireshark filter: ip.addr == 23.142.248.8
# Zero results = confirmed clean at wire level

# Confirm Cloudflare active under load
# Wireshark filter: ip.addr == 162.159.200.1 && ntp
```

---

## 9. KNOWN ISSUES AND FIXES APPLIED

| Issue | Run Found | Fix Applied | Status |
|---|---|---|---|
| 23.142.248.8 bad NTP source causing spikes | Run 1 | Removed from chrony.conf, maxdistance 0.050 added | ✅ Fixed Run 2 |
| Collectors not killed on shutdown | Run 3 | Separate pkill calls, scripts rewritten | ✅ Fixed Run 4 |
| sat_run never killed on shutdown | Run 3 | pkill -f sat_run{N} added to shutdown.sh | ✅ Fixed Run 4 |
| iperf3 server not started before clients | Run 4 | Server start moved to startup.sh, hard exit on failure | ✅ Fixed Run 5 |
| saturation.sh no iperf3 gate | Run 4 | Hard port 5201 check before sat_run deploy | ✅ Fixed Run 5 |
| pgrep alternation \| not working | Run 5 | Replaced with separate pgrep calls | ✅ Fixed Run 5 |
| wc < permission denied for chrony log | Run 5 | sudo cat pipe to wc, sudoers updated Pi1+Pi2 | ✅ Fixed Run 5 |
| tshark paths hardcoded run5 | Run 5 | Changed to run${N} throughout tshark.sh | ✅ Fixed Run 5 |
| stale tshark.sh duplicate in scripts/ | Run 5 | Deleted — canonical location is ~/Research/ | ✅ Fixed Run 5 |
| X1C7 no SSH server | Run 5 setup | openssh-server installed and enabled | ✅ Fixed |
| X1C7 no Ethernet port | Run 5 setup | USB-C to GigE adapter (AX88179 chipset) | ✅ Fixed |
| WiFi capture node cannot see NTP unicast | Run 5 setup | WiFi ruled out — wired adapter required | ✅ Documented |
| Pi2 passwordless sudo not configured | Open | Interactive SSH required for initial sudoers setup | ⚠️ Workaround in place |
| Google NTP source removed from Pi1 | Pre-Run5 | Observed 1.2ms disagreement with Cloudflare causing servo oscillation. Pi1 IP-pinned to single source 162.159.200.1 | ✅ Fixed pre-Run5 |

---

## 10. COMPLIANCE DECISION THRESHOLDS

| Metric | Pass | Fail | Notes |
|---|---|---|---|
| RMS offset | < 100 µs | ≥ 100 µs | IEEE C37.238-2017 hard threshold |
| Spike rate | Document + correlate | — | No hard threshold; sponsor-relevant above 3% |
| Thermal | < 80°C | ≥ 80°C | RPi4B throttle onset |
| UDP jitter | < 1 ms | ≥ 1 ms | Operational guide; NTP path viability |
| Packet loss | 0% | > 0% | UDP/123 transport integrity |

---

## 11. OPEN ITEMS

- [ ] Pi2 interactive sudoers configuration — passwordless sudo not fully automated
- [ ] UTC traceability statement — cite Cloudflare GPS-disciplined infrastructure in methodology
- [ ] Email Beeston requesting documentation of UDP/123 traffic policy on NILE — methodology limitation disclosure
- [ ] ADEV cross-run comparison once Runs 5/6/7 complete
- [ ] Spike correlation: Pi1 spike timestamps vs cron/APT timers and NILE routing events (Run 4 open item)
- [ ] OUR Symposium abstract due 2026-04-05 — discuss with Everett
- [ ] OUR Symposium 2026-04-27 — Memorial Gym, professional obligation as DeVlieg Scholar
- [ ] SURF proposal submitted for Summer 2026 (Phase 3 GPS grand master clock)

---

## 12. PHASE 3 PREVIEW

- GPS grand master clock integration (SURF Summer 2026)
- PTP/IEEE-1588 protocol replaces NTP — Wireshark IEEE-1588 dissector required
- tshark methodology from Phase 2 carries forward directly
- X1C7 USB-C Ethernet adapter software timestamping accuracy: ~1–10 µs (sufficient for protocol analysis, insufficient as independent timing reference)
- Arduino Opta PLC IT/OT boundary testing — deferred pending Phase 2 completion

---

## 13. KEY CONTACTS

| Person | Role | Email |
|---|---|---|
| Dr. John Shovic | PI, CIIR Director | jshovic@uidaho.edu |
| Dr. Mary Everett | Assistant PI | Day-to-day decisions |
| Dave Beeston | NILE IT, Technology Solutions Partner II | beeston@uidaho.edu |

## Run 7 — Spike Root Cause (2026-04-17)

**Pi-1 spike: -7,664.5 µs at 2026-04-07T07:07:34Z UTC**
- Phase: quiet soak (6 days post-plateau)
- Pre-spike offset elevated at +307 µs — upstream Cloudflare degraded before event
- Single bad poll response from 162.159.200.1; last_offset held for 7 samples (~70s)
- Recovery: one poll interval (64s); settled to -16 µs within two polls
- Attribution: upstream Cloudflare bad sample — not NILE, not hardware
- Chrony outlier rejection operated correctly
