package config

import (
	"bufio"
	"os"
	"regexp"
	"strconv"
	"strings"
	"time"
)

const DefaultPath = "/etc/torrent-guard.conf"

type Config struct {
	PauseSec       int
	SleepSec       int
	CooldownSec    int
	EnableIPTables bool
	EnableLogWatch bool
	LogPath        string
	LogRegexRaw    string
	LogRegex       *regexp.Regexp
}

func Load(path string) (*Config, error) {
	if path == "" {
		path = DefaultPath
	}
	cfg := &Config{
		PauseSec:       15,
		SleepSec:       5,
		CooldownSec:    60,
		EnableIPTables: true,
		EnableLogWatch: true,
		LogPath:        "/usr/local/x-ui/access.log",
		LogRegexRaw:    "(?i)torrent|peer_id|announce|info_hash",
	}

	f, err := os.Open(path)
	if err != nil {
		return cfg, nil
	}
	defer f.Close()

	s := bufio.NewScanner(f)
	for s.Scan() {
		line := strings.TrimSpace(s.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		kv := strings.SplitN(line, "=", 2)
		if len(kv) != 2 {
			continue
		}
		key := strings.TrimSpace(kv[0])
		val := strings.TrimSpace(kv[1])
		switch key {
		case "PAUSE_SEC":
			if v, err := strconv.Atoi(val); err == nil {
				cfg.PauseSec = v
			}
		case "SLEEP_SEC":
			if v, err := strconv.Atoi(val); err == nil {
				cfg.SleepSec = v
			}
		case "COOLDOWN_SEC":
			if v, err := strconv.Atoi(val); err == nil {
				cfg.CooldownSec = v
			}
		case "ENABLE_IPTABLES":
			cfg.EnableIPTables = val == "1" || strings.EqualFold(val, "true")
		case "ENABLE_LOGWATCH":
			cfg.EnableLogWatch = val == "1" || strings.EqualFold(val, "true")
		case "LOG_PATH":
			cfg.LogPath = val
		case "LOG_REGEX":
			cfg.LogRegexRaw = val
		}
	}

	_ = s.Err()

	// Compile regex (case-insensitive supported by embedded inline flag)
	if cfg.LogRegexRaw != "" {
		re, err := regexp.Compile(cfg.LogRegexRaw)
		if err == nil {
			cfg.LogRegex = re
		}
	}
	return cfg, nil
}

func CooldownExceeded(last time.Time, seconds int) bool {
	if seconds <= 0 {
		return true
	}
	return time.Since(last) >= time.Duration(seconds)*time.Second
}
