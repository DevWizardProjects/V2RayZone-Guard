package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"

	"github.com/DevWizardProjects/V2RayZone-Guard/internal/config"
)

func sh(cmd string) error {
	return exec.Command("bash", "-lc", cmd).Run()
}

func readConfig() *config.Config {
	cfg, _ := config.Load("")
	return cfg
}

func printConfig(cfg *config.Config) {
	fmt.Println("Current config (/etc/torrent-guard.conf):")
	fmt.Printf("  PAUSE_SEC=%d\n", cfg.PauseSec)
	fmt.Printf("  SLEEP_SEC=%d\n", cfg.SleepSec)
	fmt.Printf("  COOLDOWN_SEC=%d\n", cfg.CooldownSec)
	fmt.Printf("  ENABLE_IPTABLES=%v\n", cfg.EnableIPTables)
	fmt.Printf("  ENABLE_LOGWATCH=%v\n", cfg.EnableLogWatch)
	fmt.Printf("  LOG_PATH=%s\n", cfg.LogPath)
	fmt.Printf("  LOG_REGEX=%s\n", cfg.LogRegexRaw)
}

func toggle(key string, enable bool) error {
	val := "0"
	if enable {
		val = "1"
	}
	cmd := fmt.Sprintf("sudo sed -i 's/^%s=.*/%s=%s/' /etc/torrent-guard.conf", key, key, val)
	return sh(cmd)
}

func setKey(key, value string) error {
	cmd := fmt.Sprintf("sudo sed -i 's/^%s=.*/%s=%s/' /etc/torrent-guard.conf", key, key, value)
	return sh(cmd)
}

func restartUnits() {
	_ = sh("sudo systemctl restart torrent-guard.service")
	_ = sh("sudo systemctl restart torrent-guard-log.service")
}

func menu() {
	in := bufio.NewScanner(os.Stdin)
	for {
		fmt.Println()
		fmt.Println("tgctl - Torrent Guard control")
		fmt.Println(" 1) Restart iptables detector")
		fmt.Println(" 2) Restart log monitor")
		fmt.Println(" 3) Set pause time (PAUSE_SEC)")
		fmt.Println(" 4) Toggle iptables on/off")
		fmt.Println(" 5) Toggle logwatch on/off")
		fmt.Println(" 6) Set log path")
		fmt.Println(" 7) Set log regex")
		fmt.Println(" 8) Update / reinstall (runs build/install.sh)")
		fmt.Println(" 9) Uninstall (keep config)")
		fmt.Println(" s) Show config")
		fmt.Println(" t) Test-fire (simulate one pause)")
		fmt.Println(" q) Quit")
		fmt.Print("Select: ")
		if !in.Scan() {
			return
		}
		choice := strings.TrimSpace(in.Text())
		switch choice {
		case "1":
			_ = sh("sudo systemctl restart torrent-guard.service")
		case "2":
			_ = sh("sudo systemctl restart torrent-guard-log.service")
		case "3":
			fmt.Print("Seconds (e.g., 15): ")
			if !in.Scan() {
				continue
			}
			sec := strings.TrimSpace(in.Text())
			_ = setKey("PAUSE_SEC", sec)
			restartUnits()
		case "4":
			cfg := readConfig()
			_ = toggle("ENABLE_IPTABLES", !cfg.EnableIPTables)
			restartUnits()
		case "5":
			cfg := readConfig()
			_ = toggle("ENABLE_LOGWATCH", !cfg.EnableLogWatch)
			restartUnits()
		case "6":
			fmt.Print("Log path: ")
			if !in.Scan() {
				continue
			}
			_ = setKey("LOG_PATH", strings.TrimSpace(in.Text()))
			restartUnits()
		case "7":
			fmt.Print("Log regex: ")
			if !in.Scan() {
				continue
			}
			_ = setKey("LOG_REGEX", strings.TrimSpace(in.Text()))
			restartUnits()
		case "8":
			fmt.Println("Running installer...")
			_ = sh("sudo bash /usr/local/src/V2RayZone-Guard/build/install.sh || sudo bash build/install.sh")
		case "9":
			fmt.Println("Uninstalling...")
			_ = sh("sudo bash /usr/local/src/V2RayZone-Guard/build/install.sh uninstall || sudo bash build/install.sh uninstall")
		case "s":
			printConfig(readConfig())
		case "t":
			cfg := readConfig()
			fmt.Println("Simulating one pause via service control...")
			pauseOnce(cfg.PauseSec)
		case "q":
			return
		default:
			fmt.Println("Unknown choice")
		}
	}
}

func discoverService() string {
	candidates := []string{"xray.service", "v2ray.service", "3x-ui.service"}
	for _, s := range candidates {
		if err := exec.Command("bash", "-lc", fmt.Sprintf("systemctl list-unit-files | grep -q '^%s'", s)).Run(); err == nil {
			return s
		}
	}
	return "xray.service"
}

func pauseOnce(sec int) {
	svc := discoverService()
	exec.Command("systemctl", "stop", svc).Run()
	time.Sleep(time.Duration(sec) * time.Second)
	exec.Command("systemctl", "start", svc).Run()
}

func main() {
	printConfig(readConfig())
	menu()
}
