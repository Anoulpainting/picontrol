# PiControl

macOS menu bar app to control your [Pironman5](https://www.pironman.com/) Raspberry Pi case.

![macOS](https://img.shields.io/badge/macOS-13%2B-black) ![License](https://img.shields.io/badge/license-MIT-blue)

## Features

- RGB lighting — color, style, brightness, speed
- OLED display — pages, rotation, sleep timeout, temperature unit
- Fan mode
- Docker containers — start / stop / restart
- Systemd services — status, start / stop / restart
- SSH terminal
- File browser
- Reboot & service restart via SSH

## Requirements

- macOS 13 Ventura or later
- Pironman5 case with the [pironman5 service](https://github.com/sunfounder/pironman5) running on your Pi
- Pi accessible on your local network

## Install

```bash
brew tap anoulpainting/picontrol
brew install --cask picontrol
```

## Uninstall

```bash
brew uninstall --zap --cask picontrol
```

`--zap` removes preferences and saved config. Without it, your settings are kept.

## Setup

On first launch, a setup guide walks you through:

1. **IP / Host** — your Pi's local IP (e.g. `192.168.1.100`)
2. **API Port** — default `34001` (pironman5 REST API)
3. **SSH Port** — default `22`
4. **Username** — e.g. `pi`
5. **Auth** — SSH key or password

SSH is optional — only needed for reboot, service restart, terminal, and file browser.

## License

MIT
