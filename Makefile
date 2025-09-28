BIN_DIR := bin
DIST_DIR := dist
PKG := github.com/DevWizardProjects/torrent-guard

.PHONY: all build install uninstall fmt vet lint release clean

all: build

build:
	@echo "[make] building tgctl and tglogwatch"
	@mkdir -p $(BIN_DIR)
	GO111MODULE=on go build -o $(BIN_DIR)/tgctl ./cmd/tgctl
	GO111MODULE=on go build -o $(BIN_DIR)/tglogwatch ./cmd/tglogwatch

install: build
	@echo "[make] running installer"
	@sudo bash build/install.sh

uninstall:
	@echo "[make] uninstalling"
	@sudo bash build/install.sh uninstall

fmt:
	go fmt ./...

vet:
	go vet ./...

lint: fmt vet
	@echo "[make] lint ok"

release:
	@echo "[make] building static release binaries"
	@mkdir -p $(DIST_DIR)
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64  go build -ldflags "-s -w" -o $(DIST_DIR)/tgctl_linux_amd64 ./cmd/tgctl
	CGO_ENABLED=0 GOOS=linux GOARCH=arm64  go build -ldflags "-s -w" -o $(DIST_DIR)/tgctl_linux_arm64 ./cmd/tgctl
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64  go build -ldflags "-s -w" -o $(DIST_DIR)/tglogwatch_linux_amd64 ./cmd/tglogwatch
	CGO_ENABLED=0 GOOS=linux GOARCH=arm64  go build -ldflags "-s -w" -o $(DIST_DIR)/tglogwatch_linux_arm64 ./cmd/tglogwatch
	@echo "[make] artifacts in $(DIST_DIR)"

clean:
	rm -rf $(BIN_DIR) $(DIST_DIR)


