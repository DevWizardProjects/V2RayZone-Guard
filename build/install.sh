#!/usr/bin/env bash
set -euo pipefail

PREFIX_BIN=/usr/local/bin
PREFIX_UNIT=/etc/systemd/system
CONF_FILE=/etc/torrent-guard.conf

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ensure_go() {
	if command -v go >/dev/null 2>&1; then
		return
	fi
	echo "[install] Go toolchain not found; installing..."

	# Try distro package manager first
	if command -v apt-get >/dev/null 2>&1; then
		DEBIAN_FRONTEND=noninteractive apt-get update -y || true
		DEBIAN_FRONTEND=noninteractive apt-get install -y golang || \
		DEBIAN_FRONTEND=noninteractive apt-get install -y golang-go || true
	fi
	if ! command -v go >/dev/null 2>&1; then
		if command -v dnf >/dev/null 2>&1; then
			dnf install -y golang || true
		elif command -v yum >/dev/null 2>&1; then
			yum install -y golang || true
		elif command -v apk >/dev/null 2>&1; then
			apk add --no-cache go || true
		elif command -v pacman >/dev/null 2>&1; then
			pacman -Sy --noconfirm go || true
		fi
	fi

	# Fallback to official tarball
	if ! command -v go >/dev/null 2>&1; then
		GO_VERSION=${GO_VERSION:-1.22.6}
		ARCH=$(uname -m)
		case "$ARCH" in
			x86_64|amd64) GOARCH=amd64 ;;
			aarch64|arm64) GOARCH=arm64 ;;
			*) echo "[install] unsupported arch: $ARCH; please install Go manually"; exit 1 ;;
		esac
		URL="https://go.dev/dl/go${GO_VERSION}.linux-${GOARCH}.tar.gz"
		echo "[install] downloading Go ${GO_VERSION} for ${GOARCH}"
		tmp=$(mktemp -d)
		curl -fsSL "$URL" -o "$tmp/go.tgz"
		rm -rf /usr/local/go
		tar -C /usr/local -xzf "$tmp/go.tgz"
		rm -rf "$tmp"
		echo 'export PATH=/usr/local/go/bin:$PATH' > /etc/profile.d/go.sh
		chmod 0644 /etc/profile.d/go.sh
		export PATH=/usr/local/go/bin:$PATH
	fi

	if ! command -v go >/dev/null 2>&1; then
		echo "[install] failed to install Go automatically; aborting"
		exit 1
	fi
	go version || true
}

ensure_binaries() {
	mkdir -p "$REPO_ROOT/bin"
	if [[ ! -x "$REPO_ROOT/bin/tgctl" || ! -x "$REPO_ROOT/bin/tglogwatch" ]]; then
		echo "[install] building Go binaries"
		ensure_go
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


