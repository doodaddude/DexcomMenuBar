<div align="center">

  <img src="https://raw.githubusercontent.com/doodaddude/DexcomMenuBar/main/Resources/AppIcon.png" width="128" height="128" alt="DexcomMenuBar App Icon" style="border-radius: 28px; box-shadow: 0 10px 30px rgba(0,0,0,0.35);" />

  # DexcomMenuBar for macOS

  ### *Real-time continuous glucose monitoring, floating natively in your Mac menu bar.*

  [![Platform](https://img.shields.io/badge/Platform-macOS%2013%2B-black?style=for-the-badge&logo=apple)](https://github.com/doodaddude/DexcomMenuBar)
  [![Developer ID Notarized](https://img.shields.io/badge/Apple%20Notarized-Developer%20ID-blue?style=for-the-badge&logo=apple)](https://github.com/doodaddude/DexcomMenuBar/releases)
  [![Release](https://img.shields.io/github/v/release/doodaddude/DexcomMenuBar?style=for-the-badge&color=success)](https://github.com/doodaddude/DexcomMenuBar/releases/latest)
  [![License](https://img.shields.io/badge/License-MIT-amber?style=for-the-badge)](LICENSE)

  <p align="center">
    <b>DexcomMenuBar</b> brings glanceable, real-time blood glucose telemetry directly to your macOS status bar. Built with a bespoke <i>Liquid Glass</i> aesthetic, native SwiftUI graphics, multi-wearer side-by-side tracking, and zero Dock footprint: monitor your sensor values, trend arrows, delta velocities, and insulin/carb logs without interrupting your workflow.
  </p>

</div>

---

## 🌟 Key Highlights

- **💧 Pure Menu Bar Accessory:** Runs strictly as an agent process (`LSUIElement = true`) with zero Dock clutter and zero Command-Tab presence.
- **⚡️ Real-Time Dexcom Telemetry:** Live glucose values, trend directional arrows (e.g., `118 ↗` or `6.5 mmol/L →`), and rate-of-change deltas refreshed automatically.
- **👥 Multi-Wearer Side-by-Side:** Track two distinct Dexcom accounts simultaneously with configurable display order and independent settings.
- **🛡️ Privacy-First Menu Display:** Wearer names remain private inside the click popover card, keeping your public menu bar completely anonymous.
- **🔏 Apple Notarized & Signed:** Signed with an Apple Developer ID (*Dakota Hilchey*) and stapled by Apple's Notary Service for seamless, warning-free Gatekeeper installation.

---

## ✨ Features & Capabilities

### 1. 🪟 Menu Bar Integration & Liquid Glass Popover
- **Glanceable Status Item:** Live glucose reading accompanied by a custom color-coded droplet reflecting current category levels (low, normal, high).
- **Optional Mini Sparkline:** Toggle a compact trend bar chart directly in the menu bar to monitor recent trajectories at a glance.
- **Rich Liquid Glass Card:** Clicking the menu bar item smoothly reveals a translucent popover card with 24-hour history, detailed statistics, and time-in-range metrics.
- **Stale Data Detection:** Automatically indicates sensor dropouts or delayed transmissions when readings exceed expected reporting intervals.

### 2. 👥 Multi-User Monitoring (Unmirrored Controls)
- **Concurrent Dual Polling:** Independently queries multiple Dexcom Share accounts across US, Outside US (OUS), or Japan server regions.
- **Unmirrored Display Options:** User 1 can enable the mini menu bar sparkline while User 2 keeps a minimalist numeric view.
- **Custom Droplet Color Palettes:** Assign independent colors for low, normal, and high glucose bands per profile to distinguish wearers instantly.
- **Profile Display Reordering:** Swap display order in settings with one click to prioritize who appears first in the status bar.

### 3. ⏳ Sensor Lifespan & Countdown Tracker
- **Model Support:** Integrated tracking for Dexcom G7, G6, and ONE+ sensor models.
- **Visual Expiration Timer:** Real-time countdown tracking days and hours remaining with warning indicators when a sensor nears end-of-life.
- **One-Click Sensor Reset:** Convenient restart button to reset timers instantly upon inserting a new sensor.

### 4. 📝 Diabetes Event Logging & Rapid Presets
- **Comprehensive Logging Sheet:** Record carbs, insulin units (fast/long acting), physical workouts, and fingerstick meter calibrations.
- **One-Click Meal Favorites:** Instant preset buttons for habitual meals and snacks to make carbohydrate logging instantaneous.
- **Per-User Button Toggle:** Show or hide the quick event logging button on a per-user basis.

### 5. 📊 Clinical Reports & Data Export
- **Endocrinologist Ready:** Export structured glucose records and session history to clean CSV and formatted PDF reports with a single click.
- **Clarity & Cloud Sync Architecture:** Supports modern OAuth2 developer token exchange alongside traditional Dexcom Share credentials.

### 6. 🔒 Security & Native Storage
- **Native macOS Keychain:** Passwords and tokens are stored directly in `Security.framework` using `kSecClassGenericPassword`. Plain text credentials are never saved to disk.
- **Offline Simulation Mode:** Built-in telemetry simulator to test alert sounds, thresholds, and graph rendering without active sensor credentials.

---

## 🎨 Menu Bar Appearance

| Element | Description | Example |
| :--- | :--- | :--- |
| **Droplet Icon** | Color-coded status droplet matching current metabolic state | 🟢 Normal / 🟠 High / 🔴 Low |
| **Glucose Value** | Formatted numeric reading in preferred measurement unit | `118` or `6.5` |
| **Rate-of-Change Delta** | Optional delta change since preceding reading | `(+5)` or `(-0.3)` |
| **Trend Arrow** | Standard Dexcom directional rate indicator | `↑` `↗` `→` `↘` `↓` `⇈` `⇊` |
| **Mini Sparkline** | Optional compact bar graph placed to the right of readings | ` ▂▃▅▆▇` |
| **Multi-User Separator** | Subtle divider pipe separating concurrent profiles | `💧 118 ↗ \| 💧 142 →` |

---

## 🚀 Installation

### Option 1: Apple Notarized DMG (Recommended)
1. Download **[`DexcomMenuBar-v1.0.0.dmg`](https://github.com/doodaddude/DexcomMenuBar/releases/latest/download/DexcomMenuBar-v1.0.0.dmg)** from the latest release.
2. Open the disk image.
3. Drag **DexcomMenuBar.app** into your **Applications** folder.
4. Launch `DexcomMenuBar` from Applications or Spotlight.

### Option 2: Pre-Packaged ZIP
1. Download **[`DexcomMenuBar-v1.0.0-macOS.zip`](https://github.com/doodaddude/DexcomMenuBar/releases/latest/download/DexcomMenuBar-v1.0.0-macOS.zip)**.
2. Unpack the archive:
   ```bash
   unzip DexcomMenuBar-v1.0.0-macOS.zip -d /Applications/
   ```
3. Open the app from your Applications directory.

---

## 🛠️ Build From Source

### Requirements
- macOS 13.0 (Ventura) or newer
- Xcode Command Line Tools (`xcode-select --install`)
- Swift 5.9+ toolchain

### Build & Package
```bash
# 1. Clone repository
git clone https://github.com/doodaddude/DexcomMenuBar.git
cd DexcomMenuBar

# 2. Compile and package the native .app bundle
./bundle.sh

# 3. Launch application
open build/DexcomMenuBar.app
```

---

## ⚙️ Initial Configuration

1. Click the Dexcom droplet icon in your macOS menu bar.
2. Select **Preferences...** (`⌘,`).
3. Under **User 1 Settings**, enter your **Dexcom Share Username** and **Password** (the primary wearer account where Dexcom Share is enabled in the mobile app).
4. Choose your account region:
   - **US** (United States)
   - **OUS** (Outside United States / Canada, UK, Europe, etc.)
   - **Japan**
5. Select your preferred units (`mg/dL` or `mmol/L`).
6. Click **Save & Sync** to begin receiving live telemetry.

---

## 📄 License & Attribution

Distributed under the MIT License. Dexcom, Dexcom G6, Dexcom G7, Dexcom ONE, and Dexcom Share are registered trademarks of Dexcom, Inc. This application is an independent community project not affiliated with or endorsed by Dexcom, Inc.
