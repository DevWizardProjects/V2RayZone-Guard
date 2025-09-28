#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/DevWizardProjects/torrent-guard.git"
DEST_DIR="/usr/local/src/torrent-guard"

need_root() {
	if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
		echo "[installer] elevating to root..."
		exec sudo -E bash "$0" "$@"
	fi
}

fetch_repo() {
	echo "[installer] syncing repo to $DEST_DIR"
	if command -v git >/dev/null 2>&1; then
		if [[ -d "$DEST_DIR/.git" ]]; then
			echo "[installer] updating existing clone"
			git -C "$DEST_DIR" fetch --depth 1 origin
			git -C "$DEST_DIR" reset --hard origin/main
		else
			mkdir -p "$DEST_DIR"
			git clone --depth 1 "$REPO_URL" "$DEST_DIR"
		fi
	else
		echo "[installer] git not found; downloading tarball"
		tmpdir=$(mktemp -d)
		curl -fsSL "https://github.com/DevWizardProjects/torrent-guard/archive/refs/heads/main.tar.gz" -o "$tmpdir/src.tgz"
		tar -xzf "$tmpdir/src.tgz" -C "$tmpdir"
		rm -rf "$DEST_DIR"
		mkdir -p "$DEST_DIR"
		shopt -s dotglob
		mv "$tmpdir"/torrent-guard-main/* "$DEST_DIR"/
		rm -rf "$tmpdir"
	fi
}

run_install() {
	bash "$DEST_DIR/build/install.sh"
}

run_uninstall() {
	bash "$DEST_DIR/build/install.sh" uninstall
}

main() {
	need_root "$@"
	case "${1:-}" in
		uninstall)
			run_uninstall
			;;
		*)
			fetch_repo
			run_install
			;;
	esac

	echo "[installer] complete"
	echo "- CLI: tgctl"
	echo "- Logs: journalctl -u torrent-guard.service -f | journalctl -u torrent-guard-log.service -f"
}

main "$@"


