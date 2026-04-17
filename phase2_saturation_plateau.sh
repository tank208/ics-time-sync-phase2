#!/bin/bash
# phase2_saturation_plateau.sh — v1
# Sustained plateau load for Phase B1.
# Deploys to Pi-2, runs as background nohup. Laptop can disconnect.
# Traffic: Pi-2 (client) → NILE → Pi-1 (server) — same path as NTP.
#
# Usage: ./phase2_saturation_plateau.sh <run_id> [duration_hours]
# Default duration: 90 hours (covers 4-day unattended window)

N=${1:?"Usage: ./phase2_saturation_plateau.sh <run_id> [duration_hours]"}
DURATION_HOURS=${2:-90}
PI1="rpi@192.168.50.10"
PI2="rpi@192.168.50.11"
PI1_IP="192.168.50.10"
DATADIR="$HOME/Research/phase2_data/run${N}"
SATLOG="$DATADIR/saturation_log_run${N}.txt"

mkdir -p "$DATADIR"

log() { echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] $*" | tee -a "$SATLOG"; }

log "=== SATURATION PLATEAU DEPLOY run=${N} v1 ==="
log "Target: 15 Mbit/s sustained for ${DURATION_HOURS} hours"

# ── Verify collectors running ─────────────────────────────────────────────────
PI1_OK=$(ssh "$PI1" "pgrep -af offset_collector > /dev/null && echo YES || echo NO")
PI2_OK=$(ssh "$PI2" "pgrep -af offset_collector > /dev/null && echo YES || echo NO")

if [ "$PI1_OK" != "YES" ] || [ "$PI2_OK" != "YES" ]; then
  log "ERROR: Collectors not running — Pi1=${PI1_OK} Pi2=${PI2_OK}"
  log "Run ./phase2_startup.sh ${N} first."
  exit 1
fi
log "Collectors confirmed — Pi1=${PI1_OK} Pi2=${PI2_OK}"

# ── Verify iperf3 server on Pi-1 ──────────────────────────────────────────────
log "Verifying iperf3 server on Pi-1 port 5201..."
IPERF_LISTENING=$(ssh "$PI1" \
  "ss -tlnp 2>/dev/null | grep ':5201' | wc -l || echo 0")

if [ "${IPERF_LISTENING}" -lt 1 ]; then
  log "ERROR: iperf3 server not listening on Pi-1:5201"
  log "       Run phase2_startup.sh first."
  log "ABORTING — plateau NOT deployed."
  exit 1
fi
log "SUCCESS: iperf3 confirmed listening on Pi-1:5201"

# ── Write plateau runner to Pi-2 ──────────────────────────────────────────────
log "Writing plateau runner to Pi-2:/tmp/sat_run${N}.sh..."

ssh "$PI2" "cat > /tmp/sat_run${N}.sh" << EOF
#!/bin/bash
# Plateau runner — executes entirely on Pi-2
# Sustained 15 Mbit/s TCP for ${DURATION_HOURS} hours
# One iperf3 segment per hour — separate log per segment

PI1_IP="${PI1_IP}"
N="${N}"
DURATION_HOURS="${DURATION_HOURS}"
SATLOG="/tmp/saturation_log_run${N}.txt"

log() { echo "[\$(date -u '+%Y-%m-%dT%H:%M:%SZ')] \$*" | tee -a "\$SATLOG"; }

snap_ntp() {
  local LABEL=\$1
  log "NTP_SNAPSHOT label=\${LABEL}"
  echo "=== \$(date -u '+%Y-%m-%dT%H:%M:%SZ') \${LABEL} ===" >> /tmp/ntp_snaps_run${N}.txt
  chronyc tracking >> /tmp/ntp_snaps_run${N}.txt 2>/dev/null
}

log "=== PLATEAU START run=${N} target=15Mbit/s duration=\${DURATION_HOURS}h ==="
log "Traffic: Pi-2 -> \${PI1_IP} (Pi-1) — same path as NTP"

snap_ntp "plateau_start"

for (( HOUR=1; HOUR<=DURATION_HOURS; HOUR++ )); do
  SEGLOG="/tmp/iperf3_plateau_h\${HOUR}_run${N}.log"
  log "SEGMENT_START hour=\${HOUR}/\${DURATION_HOURS} rate=15Mbit/s duration=3600s"
  RETRY=0
  IPERF_OK=0
  while [ \$RETRY -lt 3 ] && [ \$IPERF_OK -eq 0 ]; do
    iperf3 -c \${PI1_IP} -p 5201 -t 3600 -b 15M -P 1 > "\${SEGLOG}" 2>&1
    if grep -qE "sender\$" "\${SEGLOG}"; then
      IPERF_OK=1
    else
      RETRY=\$((RETRY + 1))
      log "SEGMENT_RETRY hour=\${HOUR} attempt=\${RETRY} — iperf3 connect failed, waiting 15s"
      sleep 15
    fi
  done
  RESULT=\$(grep -E "sender\$" "\${SEGLOG}" | tail -1 | awk '{print \$7, \$8}' 2>/dev/null || echo "parse error")
  log "SEGMENT_END hour=\${HOUR} throughput=\${RESULT} retries=\${RETRY}"
  snap_ntp "hour_\${HOUR}"
done

snap_ntp "plateau_end"
log "=== PLATEAU COMPLETE run=${N} ==="
EOF

ssh "$PI2" "chmod +x /tmp/sat_run${N}.sh"

# ── Launch on Pi-2 as background nohup ───────────────────────────────────────
log "Launching plateau runner on Pi-2 as background nohup..."
ssh "$PI2" "nohup /tmp/sat_run${N}.sh > /tmp/sat_stdout_run${N}.log 2>&1 & echo \"Plateau PID: \$!\""

log "=== DEPLOY COMPLETE — laptop can disconnect ==="
log "Monitor: ssh rpi@192.168.50.11 'tail -f /tmp/saturation_log_run${N}.txt'"
log "Check process: ssh rpi@192.168.50.11 'pgrep -af sat_run'"
log "Plateau runs ${DURATION_HOURS} hours — verify segment logs hourly"

echo ""
echo "Plateau running on Pi-2. Safe to disconnect laptop."
echo "Monitor: ssh rpi@192.168.50.11 'tail -f /tmp/saturation_log_run${N}.txt'"
