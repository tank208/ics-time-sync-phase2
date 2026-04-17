#!/bin/bash
# phase2_shutdown.sh — v3 (Run 4+)
# Stops collection on both Pis, pulls all data to laptop.
# Usage: ./phase2_shutdown.sh <run_id>

N=${1:? "Usage: ./phase2_shutdown.sh <run_id>"}
PI1="rpi@192.168.50.10"
PI2="rpi@192.168.50.11"
BASE_DIR="$HOME/Research/phase2_data"
DATADIR="$BASE_DIR/run${N}"
LOGFILE="$DATADIR/shutdown_run${N}.log"

mkdir -p "$DATADIR"

# ── Write stop time FIRST ─────────────────────────────────────────────────────
STOP_TIME=$(date --iso-8601=seconds)
STOP_UTC=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
echo "$STOP_TIME" > "$DATADIR/run${N}_stop_time.txt"
echo "RUN_STOP_UTC=${STOP_UTC}" >> "$DATADIR/run${N}_metadata.txt"
echo "[${STOP_TIME}] phase2_shutdown.sh run${N} v3 started" | tee "$LOGFILE"

# ── Capture end states BEFORE stopping collectors ─────────────────────────────
echo "[$(date --iso-8601=seconds)] Capturing pi1 end state..." | tee -a "$LOGFILE"
ssh "$PI1" "chronyc tracking"    >  "$DATADIR/pi1_chrony_end_state.txt"
ssh "$PI1" "chronyc sources -v"  >> "$DATADIR/pi1_chrony_end_state.txt"
ssh "$PI1" "chronyc sourcestats" >> "$DATADIR/pi1_chrony_end_state.txt"

echo "[$(date --iso-8601=seconds)] Capturing pi2 end state..." | tee -a "$LOGFILE"
ssh "$PI2" "chronyc tracking"    >  "$DATADIR/pi2_chrony_end_state.txt"
ssh "$PI2" "chronyc sources -v"  >> "$DATADIR/pi2_chrony_end_state.txt"
ssh "$PI2" "chronyc sourcestats" >> "$DATADIR/pi2_chrony_end_state.txt"

ssh "$PI1" "ip addr show && ip route" > "$DATADIR/network_endstate_run${N}.txt"
ssh "$PI1" "ss -tunap"               >> "$DATADIR/network_endstate_run${N}.txt"

# ── Stop collectors — use separate pkill calls, no alternation regex ──────────
# Fixes: \| alternation never worked in pkill
# Fixes: collectors are now named offset_collector.sh / thermal_collector.sh
echo "[$(date --iso-8601=seconds)] Stopping collectors on pi1..." | tee -a "$LOGFILE"
ssh "$PI1" "pkill -f offset_collector 2>/dev/null; pkill -f thermal_collector 2>/dev/null; echo 'Pi1 collectors stopped'"

echo "[$(date --iso-8601=seconds)] Stopping collectors on pi2..." | tee -a "$LOGFILE"
ssh "$PI2" "pkill -f offset_collector 2>/dev/null; pkill -f thermal_collector 2>/dev/null; echo 'Pi2 collectors stopped'"

# ── Stop saturation script on Pi-2 ───────────────────────────────────────────
# Fixes: sat_run script was never killed, kept running after shutdown
echo "[$(date --iso-8601=seconds)] Stopping saturation script on pi2..." | tee -a "$LOGFILE"
ssh "$PI2" "pkill -f sat_run${N} 2>/dev/null; pkill -f iperf3 2>/dev/null; echo 'Saturation stopped'"

# ── Kill iperf3 server on Pi-1 ────────────────────────────────────────────────
echo "[$(date --iso-8601=seconds)] Killing iperf3 server on pi1..." | tee -a "$LOGFILE"
ssh "$PI1" "pkill -f iperf3 2>/dev/null; echo 'iperf3 cleared'"

sleep 2

# ── Pull Pi-1 data files ──────────────────────────────────────────────────────
echo "[$(date --iso-8601=seconds)] Pulling pi1 data files..." | tee -a "$LOGFILE"
scp "$PI1:~/pi1_offsets_run${N}.txt"  "$DATADIR/pi1_offsets_run${N}.txt"
scp "$PI1:~/pi1_thermal_run${N}.txt"  "$DATADIR/pi1_thermal_run${N}.txt"
scp "$PI1:~/pi1_tracking_run${N}.txt" "$DATADIR/pi1_tracking_run${N}.txt"

# ── Pull Pi-2 data files ──────────────────────────────────────────────────────
echo "[$(date --iso-8601=seconds)] Pulling pi2 data files..." | tee -a "$LOGFILE"
scp "$PI2:~/pi2_offsets_run${N}.txt"  "$DATADIR/pi2_offsets_run${N}.txt"
scp "$PI2:~/pi2_thermal_run${N}.txt"  "$DATADIR/pi2_thermal_run${N}.txt"
scp "$PI2:~/pi2_tracking_run${N}.txt" "$DATADIR/pi2_tracking_run${N}.txt"

# ── Pull saturation logs from Pi-2 ───────────────────────────────────────────
# Fixes: saturation logs were never pulled
echo "[$(date --iso-8601=seconds)] Pulling saturation logs from pi2..." | tee -a "$LOGFILE"
scp "$PI2:/tmp/saturation_log_run${N}.txt" \
  "$DATADIR/saturation_log_run${N}.txt" 2>/dev/null \
  || echo "[WARN] saturation_log not found on pi2" | tee -a "$LOGFILE"

scp "$PI2:/tmp/ntp_snaps_run${N}.txt" \
  "$DATADIR/ntp_snaps_run${N}.txt" 2>/dev/null \
  || echo "[WARN] ntp_snaps not found on pi2" | tee -a "$LOGFILE"

# Pull iperf3 burst result files from Pi-2
for BURST in 1 2 3; do
  scp "$PI2:/tmp/iperf3_tcp_burst${BURST}_run${N}.log" \
    "$DATADIR/iperf3_tcp_sat_burst${BURST}_run${N}.log" 2>/dev/null || true
  scp "$PI2:/tmp/iperf3_udp_phase${BURST}_run${N}.log" \
    "$DATADIR/iperf3_udp_phase${BURST}_run${N}.log" 2>/dev/null || true
done
echo "[$(date --iso-8601=seconds)] Saturation logs pulled." | tee -a "$LOGFILE"

# Pull iperf3 server log from Pi-1
scp "$PI1:/tmp/iperf3_server_run${N}.log" \
  "$DATADIR/iperf3_server_run${N}.log" 2>/dev/null \
  || echo "[WARN] iperf3 server log not found on pi1" | tee -a "$LOGFILE"

# ── Pull Pi-1 chrony system logs ──────────────────────────────────────────────
echo "[$(date --iso-8601=seconds)] Pulling pi1 chrony system logs..." | tee -a "$LOGFILE"
ssh "$PI1" "sudo cp /var/log/chrony/measurements.log \
  /tmp/pi1_chrony_measurements_run${N}.log && \
  sudo chmod 644 /tmp/pi1_chrony_measurements_run${N}.log"
scp "$PI1:/tmp/pi1_chrony_measurements_run${N}.log" \
  "$DATADIR/pi1_chrony_measurements_run${N}.log"
# ── Pull Pi-1 rotated chrony logs (covers runs longer than 1 week) ────────────
for ROT in 1 2 3 4; do
  ssh "$PI1" "sudo cp /var/log/chrony/measurements.log.${ROT} \
    /tmp/pi1_chrony_measurements_run${N}.log.${ROT} 2>/dev/null && \
    sudo chmod 644 /tmp/pi1_chrony_measurements_run${N}.log.${ROT} 2>/dev/null" 2>/dev/null || true
  scp "$PI1:/tmp/pi1_chrony_measurements_run${N}.log.${ROT}" \
    "$DATADIR/pi1_chrony_measurements_run${N}.log.${ROT}" 2>/dev/null \
    && echo "[$(date --iso-8601=seconds)] Pi1 measurements.log.${ROT} pulled." | tee -a "$LOGFILE" \
    || true
done

ssh "$PI1" "sudo cp /var/log/chrony/statistics.log \
  /tmp/pi1_chrony_statistics_run${N}.log 2>/dev/null && \
  sudo chmod 644 /tmp/pi1_chrony_statistics_run${N}.log 2>/dev/null" || true
scp "$PI1:/tmp/pi1_chrony_statistics_run${N}.log" \
  "$DATADIR/pi1_chrony_statistics_run${N}.log" 2>/dev/null \
  || echo "[WARN] No statistics.log on pi1 (non-fatal)" | tee -a "$LOGFILE"

# ── Pull Pi-2 chrony system logs via sudo wrapper ────────────────────────────
# Fixes: shutdown script used direct sudo cp — but sudoers only permits the wrapper
# Wrapper installed by configure_chrony_sudo.sh: /usr/local/bin/pull_chrony_logs.sh
echo "[$(date --iso-8601=seconds)] Pulling pi2 chrony system logs..." | tee -a "$LOGFILE"
if ssh "$PI2" "sudo /usr/local/bin/pull_chrony_logs.sh run${N}" 2>/dev/null; then
  scp "$PI2:/tmp/pi2_chrony_measurements_run${N}.log" \
    "$DATADIR/pi2_chrony_measurements_run${N}.log" 2>/dev/null \
    && echo "[$(date --iso-8601=seconds)] Pi2 chrony measurements pulled." | tee -a "$LOGFILE" \
    || echo "[WARN] pi2 chrony measurements scp failed" | tee -a "$LOGFILE"
  scp "$PI2:/tmp/pi2_chrony_statistics_run${N}.log" \
    "$DATADIR/pi2_chrony_statistics_run${N}.log" 2>/dev/null \
    || echo "[WARN] pi2 statistics.log not available (non-fatal)" | tee -a "$LOGFILE"
else
  echo "[WARN] Pi2 chrony sudo pull failed — wrapper not configured or denied." \
    | tee -a "$LOGFILE"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
START_TIME=$(cat "$DATADIR/run${N}_start_time.txt" 2>/dev/null || echo "unknown")

echo "" | tee -a "$LOGFILE"
echo "[$(date --iso-8601=seconds)] Run ${N} start: ${START_TIME}" | tee -a "$LOGFILE"
echo "[$(date --iso-8601=seconds)] Run ${N} stop:  ${STOP_TIME}"  | tee -a "$LOGFILE"

echo "" | tee -a "$LOGFILE"
echo "=== DATA PULL SUMMARY ===" | tee -a "$LOGFILE"
for FILE in \
  pi1_offsets_run${N}.txt     pi2_offsets_run${N}.txt \
  pi1_thermal_run${N}.txt     pi2_thermal_run${N}.txt \
  pi1_chrony_measurements_run${N}.log \
  pi2_chrony_measurements_run${N}.log \
  saturation_log_run${N}.txt
do
  if [ -f "$DATADIR/$FILE" ]; then
    COUNT=$(wc -l < "$DATADIR/$FILE")
    SIZE=$(du -sh "$DATADIR/$FILE" | cut -f1)
    echo "  OK      $FILE — ${COUNT} lines, ${SIZE}" | tee -a "$LOGFILE"
  else
    echo "  MISSING $FILE" | tee -a "$LOGFILE"
  fi
done

echo "" | tee -a "$LOGFILE"
echo "Run ${N} shutdown complete." | tee -a "$LOGFILE"
echo "Next: python3 ~/Research/phase2_analyze.py --run ${N} --datadir ${DATADIR} --outdir ${DATADIR}" \
  | tee -a "$LOGFILE"
