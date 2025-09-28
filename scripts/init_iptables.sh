#!/usr/bin/env bash
set -euo pipefail

# Idempotently create and hook TORRENT_DETECT chain for detection-only counters.

CHAIN=TORRENT_DETECT

ensure_chain() {
	if ! iptables -L $CHAIN -n >/dev/null 2>&1; then
		iptables -N $CHAIN
	fi
}

flush_rules() {
	iptables -F $CHAIN || true
}

add_rule_if_missing() {
	if ! iptables -C "$@" 2>/dev/null; then
		iptables -A "$@"
	fi
}

hook_tables() {
	# Hook TORRENT_DETECT early in OUTPUT and FORWARD to count client traffic
	add_rule_if_missing OUTPUT -j $CHAIN
	add_rule_if_missing FORWARD -j $CHAIN
}

populate_detect_rules() {
	# String heuristics (detection only); RETURN avoids altering flow, but counts traffic
	add_rule_if_missing $CHAIN -m string --algo bm --string "torrent" -j RETURN
	add_rule_if_missing $CHAIN -m string --algo bm --string "peer_id" -j RETURN
	add_rule_if_missing $CHAIN -m string --algo bm --string "announce" -j RETURN
	add_rule_if_missing $CHAIN -m string --algo bm --string "info_hash" -j RETURN

	# Common tracker ports as heuristic (both TCP/UDP). RETURN to record only.
	for p in 80 443 6881:6889 6969; do
		add_rule_if_missing $CHAIN -p tcp --dport $p -j RETURN
		add_rule_if_missing $CHAIN -p udp --dport $p -j RETURN
	done
}

ensure_chain
flush_rules
populate_detect_rules
hook_tables

echo "[init_iptables] $CHAIN is ready"


