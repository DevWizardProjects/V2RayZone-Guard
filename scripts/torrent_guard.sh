#!/usr/bin/env bash
set -euo pipefail

CONF_FILE=/etc/torrent-guard.conf
SERVICE_CANDIDATES=(xray.service v2ray.service x-ui.service 3x-ui.service)

log() { echo "[torrent-guard] $*"; }

discover_service() {
	# Allow explicit override via config: SERVICE_NAME
	if [[ -n "${SERVICE_NAME:-}" ]]; then
		echo "$SERVICE_NAME"
		return 0
	fi
	for s in "${SERVICE_CANDIDATES[@]}"; do
		if systemctl list-unit-files | grep -q "^${s}"; then
			echo "$s"
			return 0
		fi
	done
	echo "xray.service" # default guess
}

read_config() {
	# shellcheck disable=SC1090
	if [[ -f "$CONF_FILE" ]]; then source "$CONF_FILE"; fi
	PAUSE_SEC=${PAUSE_SEC:-15}
	SLEEP_SEC=${SLEEP_SEC:-5}
	COOLDOWN_SEC=${COOLDOWN_SEC:-60}
	ENABLE_IPTABLES=${ENABLE_IPTABLES:-1}
	SERVICE_NAME=${SERVICE_NAME:-}
}

sum_counters() {
	# Sum pkts from TORRENT_DETECT chain
	if iptables -L TORRENT_DETECT -vnx >/dev/null 2>&1; then
		iptables -L TORRENT_DETECT -vnx | awk 'NR>2 && $1 ~ /^[0-9]+$/ {s+=$1} END{print s+0}'
		return
	fi
	echo 0
}

pause_core() {
	local svc="$1"
	log "Pausing core via $svc for ${PAUSE_SEC}s"
	systemctl stop "$svc" || true
	sleep "$PAUSE_SEC"
	log "Resuming core via $svc"
	systemctl start "$svc" || true
}

main() {
	local last_total=0
	local last_action_time=0
	local svc
	svc=$(discover_service)
	log "Using service: $svc"

	while true; do
		read_config
		if [[ "${ENABLE_IPTABLES}" != "1" ]]; then
			log "iptables detector disabled; sleeping ${SLEEP_SEC}s"
			sleep "$SLEEP_SEC"
			continue
		fi

		local now total
		now=$(date +%s)
		total=$(sum_counters || echo 0)
		if (( total > last_total )); then
			if (( now - last_action_time >= COOLDOWN_SEC )); then
				pause_core "$svc"
				last_action_time=$(date +%s)
			else
				log "In cooldown; detection ignored"
			fi
			last_total=$total
		fi
		sleep "$SLEEP_SEC"
	done
}

main "$@"


