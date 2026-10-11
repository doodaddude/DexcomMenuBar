# DexcomMenuBar

A native, lightweight macOS menu bar app for tracking real-time continuous glucose monitor (CGM) readings from Dexcom Share and Dexcom Cloud. Runs silently in the menu bar with zero Dock or app switcher footprint.

---

## Key Features

- Pure menu bar accessory: Runs directly in your macOS menu bar with no Dock icon and no Command-Tab presence.
- Real-time glucose readings: Displays live blood glucose values and trend arrows (such as 118 -> or 6.5 mmol/L ->).
- Multi-user monitoring: Track two separate Dexcom users side by side in the menu bar with customizable display order.
- Privacy-first status display: User names stay strictly inside the click dropdown card, keeping your menu bar clean and anonymous.
- Independent per-user preferences: Unmirrored toggles for mini trend graphs, rate-of-change deltas, and droplet colors (low, normal, high).
- Intelligent color coding: Color-coded status droplets indicating low, normal, and high glucose levels at a glance.
- Target range sparkline: Popover card renders a 24-hour interactive sparkline chart with customizable target thresholds.
- Sensor countdown tracker: Built-in lifespan countdown tracker for Dexcom G7, G6, and ONE+ sensors with expiration warnings.
- Urgent glucose audio alerts: Customizable audio alerts for urgent low and urgent high glucose thresholds.
- Event logging sheet: Log meals with carbs and macros, insulin doses, physical exercise, and fingerstick meter calibrations.
- Fast meal presets: Instant one-click presets for common meals and snacks.
- Medical export tools: One-click export to clean CSV and formatted PDF reports ready for endocrinologist visits.
- Secure macOS Keychain storage: All Dexcom passwords and developer tokens are stored securely in the native macOS Keychain.
- Multi-region connectivity: Full support for Dexcom US, Outside US (OUS), and Japan servers.
- Officially notarized: Signed with an Apple Developer ID and notarized by Apple for instant, warning-free installation on macOS 13+.

---

## Installation

### Download Disk Image (.dmg)
1. Download `DexcomMenuBar-v1.0.0.dmg` from the latest GitHub Release.
2. Open the downloaded `.dmg` file.
3. Drag `DexcomMenuBar.app` into your `Applications` folder.
4. Launch the app from Applications or Spotlight.

---

## Build from Source

### Requirements
- macOS 13.0 (Ventura) or newer
- Xcode Command Line Tools (`swift --version`)

### Compilation Steps
```bash
git clone https://github.com/doodaddude/DexcomMenuBar.git
cd DexcomMenuBar

# Build and package the .app bundle
./bundle.sh

# Launch the app
open build/DexcomMenuBar.app
```

---

## Initial Setup

1. Click the Dexcom droplet icon in your macOS menu bar.
2. Open Preferences.
3. Enter your Dexcom Share username and password.
4. Select your account region (US, Outside US / OUS, or Japan).
5. Click Save & Sync.
