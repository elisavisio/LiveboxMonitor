# Livebox Monitor — Flutter Desktop Edition

A modern, pure-Dart / Flutter desktop remake of **Livebox Monitor** for Orange **Livebox 4, 5, 6, 7, W7, S & Pro**, Wi-Fi Repeaters, and Orange TV Decoders.

Built with **Material 3**, adaptive **Dark / Light** themes, Livebox Orange (`#FF7900`) accent styling, collapsible desktop sidebar navigation, KPI telemetry cards, and real-time interactive charts — with **no Python runtime required**.

## Features

- **Direct Orange Livebox Sysbus API (Pure Dart)**: Implements `X-Sah-Login` authentication, session cookie & `X-Context` management, `POST /ws` JSON-RPC calls, event channel polling, and direct HTTP port 8080 control for Orange TV Decoders.
- **Interactive Demo Mode**: Launch a full stateful Livebox 7 W7 simulation with 14 devices, 2 Wi-Fi 6 repeaters, 1 UHD TV decoder, live traffic curves, and live events — great for exploring the UI without a Livebox on your LAN.
- **11 Complete Desktop Workspaces**:
  1. **Overview & Info**: WAN/Fiber/IPv6 KPI cards, live WAN sparkline, ONT optical power (Rx/Tx dBm, temp, voltage), hardware/firmware details, quick Wi-Fi/Guest switches, and network interface table.
  2. **Devices & Inspector**: Searchable & filterable master-detail device list with RSSI signal bars, Wake-on-LAN, rename, device type assignment, WAN block/unblock, static IP pinning, and offline device cleanup.
  3. **Traffic Graphs**: Interactive `fl_chart` multi-series real-time area charts (Download/Upload) with per-interface switching, peak/average/current KPI cards, hover tooltips, and pause/resume.
  4. **Events**: Live event stream with per-device sidebar filtering, search, CSV export, and JSON payload inspector.
  5. **DHCP**: DHCPv4/v6 configuration editor, delegated IPv6 prefix info, active leases, and static IP binding CRUD.
  6. **NAT / PAT**: Port Forwarding (IPv4 & UPnP) rules, Protocol Forwarding (PTF), and DMZ host configuration.
  7. **Firewall**: IPv4 & IPv6 security level selectors (`Low`, `Medium`, `High`, `Custom`), ICMP ping response controls, and custom IPv4/IPv6 firewall rules CRUD.
  8. **Phone / VoIP**: Call history with incoming/outgoing/missed/spam badges, handset Ring Test, and Livebox phonebook CRUD.
  9. **Repeaters**: Dynamic repeater selector cards, backhaul telemetry & RSSI, Wi-Fi toggle, connected clients, and reboot history.
  10. **TV Decoders**: Live Now Playing banner, quick channel zap bar, and tactile Virtual Remote Control wired to Orange decoder HTTP port 8080 keycodes.
  11. **Actions & Tools**: Global/Guest Wi-Fi & Scheduler, per-band SSID editor, Livebox Speed Test, LED brightness & front screen settings, Reboot & Reboot History, Cloud Backup/Restore, DynDNS, Static IPv4 Routes, and a **Raw Sysbus API Explorer**.
- **Bilingual (EN / FR)** with instant runtime switching and **Saved Connection Profiles**.

## Running & Building

Ensure [Flutter](https://docs.flutter.dev/get-started/install) (`>= 3.24` / Dart `>= 3.10`) is installed.

```bash
cd flutter_app
flutter pub get

# Run on your desktop OS:
flutter run -d macos    # macOS
flutter run -d windows  # Windows
flutter run -d linux    # Linux

# Release builds:
flutter build macos --release
flutter build windows --release
flutter build linux --release
```

## Running Tests

```bash
cd flutter_app
flutter analyze
flutter test
```
