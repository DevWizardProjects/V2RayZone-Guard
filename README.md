V2RayZone Guard (Torrent Guard)

What it does
- Detects potential torrent traffic via iptables heuristics and x-ui access log patterns.
- Automatically pauses the Xray/V2Ray core (3x-ui stack) for a short period, then resumes.
- Two detectors, two services:
  - torrent-guard.service: Bash watcher that reads iptables counters.
  - torrent-guard-log.service: Go daemon that tails x-ui logs and matches regex.
- Single CLI (tgctl) to manage config, toggles, services, install/uninstall.

Install (one-liner)
```
bash <(curl -Ls https://raw.githubusercontent.com/DevWizardProjects/V2RayZone-Guard/main/install.sh)
```

Quick usage
- Show config: `sudo tgctl`
- Restart detectors: `sudo tgctl` → menu options
- Logs:
  - `journalctl -u torrent-guard.service -f`
  - `journalctl -u torrent-guard-log.service -f`

Config
File: `/etc/torrent-guard.conf`
```
PAUSE_SEC=15
SLEEP_SEC=5
COOLDOWN_SEC=60
ENABLE_IPTABLES=1
ENABLE_LOGWATCH=1
LOG_PATH=/usr/local/x-ui/access.log
LOG_REGEX=(?i)torrent|peer_id|announce|info_hash
```

Paths
- Bash guard: `/usr/local/bin/torrent_guard.sh`
- Log watcher: `/usr/local/bin/tglogwatch`
- CLI: `/usr/local/bin/tgctl`

Systemd units
- `torrent-guard.service` (needs CAP_NET_ADMIN)
- `torrent-guard-log.service`

iptables init (idempotent)
- Use `scripts/init_iptables.sh` to create and hook a `TORRENT_DETECT` chain. Safe to rerun.

Troubleshooting
- Service name auto-discovery tries: `xray.service`, `v2ray.service`, then `3x-ui.service`.
- iptables counters: `sudo iptables -L TORRENT_DETECT -vnx`
- Log trigger test: `echo "peer_id=123" | sudo tee -a /usr/local/x-ui/access.log`

Security
- Services run as root; `torrent-guard.service` uses `AmbientCapabilities=CAP_NET_ADMIN`.
- File modes: scripts 0755, units 0644, config 0644.

Development
- Build: `make build`
- Install: `sudo make install`
- Uninstall: `sudo make uninstall`
- Release: `make release` (produces static binaries for linux/amd64, linux/arm64)


