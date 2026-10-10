#!/usr/bin/env bash
# Two-process LAN TDM test on localhost: a headless host and a headless client.
# Usage: tests/run_net_test.sh [godot-binary]
set -u
GODOT="${1:-godot}"
cd "$(dirname "$0")/.."
LOG=$(mktemp -d)
timeout 240 "$GODOT" --headless res://tests/test_runner.tscn -- net_host < /dev/null > "$LOG/host.log" 2>&1 &
HP=$!
sleep 4
timeout 240 "$GODOT" --headless res://tests/test_runner.tscn -- net_client < /dev/null > "$LOG/client.log" 2>&1 &
CP=$!
wait $HP; HR=$?
wait $CP; CR=$?
grep -hE "PASS|FAIL|RESULT|NET_" "$LOG/host.log" "$LOG/client.log"
grep -hE "SCRIPT ERROR" "$LOG/host.log" "$LOG/client.log" | sort | uniq -c | head -5
HS=$(grep -h "NET_SCORES host" "$LOG/host.log" | awk '{print $3}')
CS=$(grep -h "NET_SCORES client" "$LOG/client.log" | awk '{print $3}')
if [ -n "$HS" ] && [ "$HS" = "$CS" ]; then echo "  PASS  final scores identical on host and client ($HS)"; else echo "  FAIL  final scores differ (host=$HS client=$CS)"; HR=1; fi
echo "logs: $LOG"
[ $HR -eq 0 ] && [ $CR -eq 0 ]
