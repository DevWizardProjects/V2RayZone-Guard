package main

import (
	"bufio"
	"fmt"
	"os/exec"
	"time"

	"github.com/DevWizardProjects/torrent-guard/internal/config"
)

func logf(format string, a ...any) {
	fmt.Printf("[tglogwatch] "+format+"\n", a...)
}

func discoverService() string {
	candidates := []string{"xray.service", "v2ray.service", "3x-ui.service"}
	for _, s := range candidates {
		cmd := exec.Command("bash", "-lc", fmt.Sprintf("systemctl list-unit-files | grep -q '^%s'", s))
		if err := cmd.Run(); err == nil {
			return s
		}
	}
	return "xray.service"
}

func pauseCore(svc string, sec int) {
	logf("Pausing core via %s for %ds", svc, sec)
	exec.Command("systemctl", "stop", svc).Run()
	time.Sleep(time.Duration(sec) * time.Second)
	logf("Resuming core via %s", svc)
	exec.Command("systemctl", "start", svc).Run()
}

func main() {
	svc := discoverService()
	logf("Using service: %s", svc)

	var lastAction time.Time
	for {
		cfg, _ := config.Load("")
		if !cfg.EnableLogWatch {
			logf("logwatch disabled; sleeping %ds", cfg.SleepSec)
			time.Sleep(time.Duration(cfg.SleepSec) * time.Second)
			continue
		}
		if cfg.LogRegex == nil {
			logf("invalid LOG_REGEX; sleeping")
			time.Sleep(3 * time.Second)
			continue
		}

		cmd := exec.Command("bash", "-lc", fmt.Sprintf("tail -F %q", cfg.LogPath))
		stdout, err := cmd.StdoutPipe()
		if err != nil {
			logf("tail pipe error: %v", err)
			time.Sleep(3 * time.Second)
			continue
		}
		if err := cmd.Start(); err != nil {
			logf("tail start error: %v", err)
			time.Sleep(3 * time.Second)
			continue
		}

		s := bufio.NewScanner(stdout)
		for s.Scan() {
			line := s.Text()
			if cfg.LogRegex.MatchString(line) {
				if config.CooldownExceeded(lastAction, cfg.CooldownSec) {
					pauseCore(svc, cfg.PauseSec)
					lastAction = time.Now()
				} else {
					logf("match but in cooldown; ignored")
				}
			}
		}
		_ = s.Err()
		// respawn tail if it exits (rotation or error)
		if cmd.Process != nil {
			_ = cmd.Process.Kill()
		}
		logf("tail exited; restarting in %ds", cfg.SleepSec)
		time.Sleep(time.Duration(cfg.SleepSec) * time.Second)
	}
}
