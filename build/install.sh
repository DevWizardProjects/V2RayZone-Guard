#!/usr/bin/env bash
set -euo pipefail

PREFIX_BIN=/usr/local/bin
PREFIX_UNIT=/etc/systemd/system
CONF_FILE=/etc/torrent-guard.conf

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ensure_binaries() {
	mkdir -p "$REPO_ROOT/bin"
	if [[ ! -x "$REPO_ROOT/bin/tgctl" || ! -x "$REPO_ROOT/bin/tglogwatch" ]]; then
		echo "[install] building Go binaries"
		( cd "$REPO_ROOT" && GO111MODULE=on go build -o bin/tgctl ./cmd/tgctl )
		( cd "$REPO_ROOT" && GO111MODULE=on go build -o bin/tglogwatch ./cmd/tglogwatch )
	fi
}

install_files() {
	echo "[install] installing binaries to $PREFIX_BIN"
	cp "$REPO_ROOT/bin/tgctl" "$PREFIX_BIN/tgctl"
	cp "$REPO_ROOT/bin/tglogwatch" "$PREFIX_BIN/tglogwatch"
	cp "$REPO_ROOT/scripts/torrent_guard.sh" "$PREFIX_BIN/torrent_guard.sh"
	chmod 0755 "$PREFIX_BIN/tgctl" "$PREFIX_BIN/tglogwatch" "$PREFIX_BIN/torrent_guard.sh"

	echo "[install] installing systemd units to $PREFIX_UNIT"
	cp "$REPO_ROOT/systemd/torrent-guard.service" "$PREFIX_UNIT/torrent-guard.service"
	cp "$REPO_ROOT/systemd/torrent-guard-log.service" "$PREFIX_UNIT/torrent-guard-log.service"
	chmod 0644 "$PREFIX_UNIT/torrent-guard.service" "$PREFIX_UNIT/torrent-guard-log.service"

	if [[ ! -f "$CONF_FILE" ]]; then
		echo "[install] creating default config at $CONF_FILE"
		cat > "$CONF_FILE" <<'EOF'
PAUSE_SEC=15
SLEEP_SEC=5
COOLDOWN_SEC=60
ENABLE_IPTABLES=1
ENABLE_LOGWATCH=1
LOG_PATH=/usr/local/x-ui/access.log
LOG_REGEX=(?i)torrent|peer_id|announce|info_hash
EOF
		chmod 0644 "$CONF_FILE"
	else
		echo "[install] keeping existing $CONF_FILE"
	fi
}

init_iptables() {
	if command -v iptables >/dev/null 2>&1; then
		echo "[install] initializing iptables detection chain"
		bash "$REPO_ROOT/scripts/init_iptables.sh" || true
	else
		echo "[install] iptables not found; skipping chain setup"
	fi
}

enable_services() {
	echo "[install] reloading systemd and enabling services"
	systemctl daemon-reload
	systemctl enable --now torrent-guard.service
	systemctl enable --now torrent-guard-log.service
}

uninstall() {
	echo "[uninstall] disabling services"
	set +e
	systemctl disable --now torrent-guard.service 2>/dev/null || true
	systemctl disable --now torrent-guard-log.service 2>/dev/null || true
	set -e

	echo "[uninstall] removing binaries and unit files"
	rm -f "$PREFIX_BIN/tgctl" "$PREFIX_BIN/tglogwatch" "$PREFIX_BIN/torrent_guard.sh"
	rm -f "$PREFIX_UNIT/torrent-guard.service" "$PREFIX_UNIT/torrent-guard-log.service"
	systemctl daemon-reload || true

	echo "[uninstall] kept config file at $CONF_FILE"
}

usage() {
	echo "Usage: $0 [uninstall]"
}

if [[ ${1:-} == "uninstall" ]]; then
	uninstall
	exit 0
fi

ensure_binaries
install_files
init_iptables
enable_services

echo "[install] done. Try: tgctl"


