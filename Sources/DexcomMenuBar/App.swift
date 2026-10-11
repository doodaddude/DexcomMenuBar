import Cocoa
import SwiftUI
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var settingsWindow: NSWindow?
    private var manager: GlucoseManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("[DexcomMenuBar] applicationDidFinishLaunching started")
        NSApp.setActivationPolicy(.accessory)

        self.manager = GlucoseManager()

        // Setup Popover
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 350, height: 460)
        popover.behavior = .transient
        popover.animates = true

        let contentView = MenuBarView(manager: manager) { [weak self] in
            self?.openSettingsWindow()
        }
        popover.contentViewController = NSHostingController(rootView: contentView)
        self.popover = popover

        // Setup NSStatusItem
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            updateStatusItem()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onDataUpdated),
            name: .glucoseDataUpdated,
            object: nil
        )

        // Request notification permissions for urgent glucose alerts
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let err = error {
                NSLog("[DexcomMenuBar] Notification auth error: %@", err.localizedDescription)
            }
        }

        // Periodic 60s timer to refresh the 'X mins ago' text in menu bar
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateStatusItem()
            }
        }

        // Automatically show settings on launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.openSettingsWindow()
        }
    }

    @objc private func onDataUpdated() {
        DispatchQueue.main.async { [weak self] in
            self?.updateStatusItem()
        }
    }

    private func updateStatusItem() {
        guard let button = statusItem?.button, let manager = manager else { return }

        let compositeImage = createMultiUserMenuBarImage(for: manager)
        button.image = compositeImage
        button.imagePosition = .imageOnly
        button.attributedTitle = NSAttributedString(string: "")
    }

    /// Creates a composite menu bar image supporting single or multiple user profiles in configurable order:
    /// Per profile: [Droplet Icon] [Number & Trend Arrow] [Optional Trend Bar Chart to the right]
    /// Profiles are separated by a clean subtle divider pipe "|".
    /// IMPORTANT: User names are NOT drawn in the menu bar image (they appear at the top of the popped-out menu).
    private func createMultiUserMenuBarImage(for manager: GlucoseManager) -> NSImage {
        let profiles = manager.activeMenuBarProfiles
        let height: CGFloat = 22

        struct SegmentSpec {
            let profileId: UserProfileID
            let isLiveActive: Bool
            let isExpired: Bool
            let dropletTint: NSColor
            let attributedText: NSAttributedString
            let textSize: NSSize
            let showChart: Bool
            let chartWidth: CGFloat
            let totalWidth: CGFloat
        }

        var segments: [SegmentSpec] = []
        let dropletWidth: CGFloat = 14
        let dropletToTextGap: CGFloat = 4.5
        let textToChartGap: CGFloat = 6.0
        let textFont = NSFont.systemFont(ofSize: 13, weight: .semibold)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: textFont,
            .foregroundColor: NSColor.labelColor
        ]

        for profile in profiles {
            let reading = manager.currentReading(for: profile)
            let isLiveActive = (reading != nil && !reading!.isStale)
            let isExpired = manager.isSensorExpired(for: profile)

            let dropletTint: NSColor
            if let reading = reading {
                if manager.colorIconEnabled(for: profile) {
                    if reading.isStale {
                        dropletTint = NSColor.secondaryLabelColor
                    } else {
                        let cat = manager.category(for: reading, profile: profile)
                        switch cat {
                        case .low, .veryLow:
                            dropletTint = manager.lowIconColor(for: profile).nsColor
                        case .high, .veryHigh:
                            dropletTint = manager.highIconColor(for: profile).nsColor
                        case .normal:
                            dropletTint = manager.normalIconColor(for: profile).nsColor
                        }
                    }
                } else {
                    dropletTint = NSColor.labelColor
                }
            } else {
                dropletTint = NSColor.secondaryLabelColor
            }

            let titleStr = manager.menuBarTitle(for: profile)
            let attrStr = NSAttributedString(string: titleStr, attributes: textAttributes)
            let txtSize = attrStr.size()

            let showChart = manager.showMenuBarTrendChart(for: profile) && !manager.recentReadings(for: profile).isEmpty
            let chartW: CGFloat = showChart ? 32 : 0

            var segWidth = dropletWidth + dropletToTextGap + txtSize.width
            if showChart {
                segWidth += textToChartGap + chartW
            }

            segments.append(SegmentSpec(
                profileId: profile,
                isLiveActive: isLiveActive,
                isExpired: isExpired,
                dropletTint: dropletTint,
                attributedText: attrStr,
                textSize: txtSize,
                showChart: showChart,
                chartWidth: chartW,
                totalWidth: segWidth
            ))
        }

        let interSegmentGap: CGFloat = 10
        let dividerWidth: CGFloat = 1
        var totalCanvasWidth: CGFloat = 2 // initial left margin

        for (idx, seg) in segments.enumerated() {
            totalCanvasWidth += seg.totalWidth
            if idx < segments.count - 1 {
                totalCanvasWidth += interSegmentGap * 2 + dividerWidth
            }
        }
        totalCanvasWidth += 2 // trailing padding

        let image = NSImage(size: NSSize(width: ceil(totalCanvasWidth), height: height))
        image.lockFocus()

        var currentX: CGFloat = 2

        for (idx, seg) in segments.enumerated() {
            let profile = seg.profileId
            // 1. Draw Droplet Icon
            let dropConfig = NSImage.SymbolConfiguration(pointSize: 12.0, weight: .semibold)
            if let baseDrop = NSImage(systemSymbolName: "drop.fill", accessibilityDescription: "Dexcom")?.withSymbolConfiguration(dropConfig) {
                let dropRect = NSRect(x: currentX, y: 3.5, width: dropletWidth, height: 15)
                baseDrop.draw(in: dropRect, from: .zero, operation: .sourceOver, fraction: 1.0)

                seg.dropletTint.set()
                dropRect.fill(using: .sourceAtop)
            }

            // Stale / Disconnected dot badge
            if !seg.isLiveActive {
                let dotRect = NSRect(x: currentX + 8.5, y: 2.5, width: 6.0, height: 6.0)
                let dotPath = NSBezierPath(ovalIn: dotRect)
                NSColor.windowBackgroundColor.setStroke()
                dotPath.lineWidth = 1.0
                dotPath.stroke()

                NSColor.systemOrange.setFill()
                dotPath.fill()

                let linePath = NSBezierPath()
                linePath.move(to: NSPoint(x: currentX + 10.0, y: 4.0))
                linePath.line(to: NSPoint(x: currentX + 13.0, y: 7.0))
                NSColor.white.setStroke()
                linePath.lineWidth = 1.0
                linePath.stroke()
            }

            // Sensor Expired Warning Badge
            if seg.isExpired {
                let warnConfig = NSImage.SymbolConfiguration(pointSize: 7.0, weight: .bold)
                if let warnImg = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Sensor Expired")?.withSymbolConfiguration(warnConfig) {
                    let warnRect = NSRect(x: currentX - 0.5, y: 1.0, width: 8.5, height: 7.0)
                    NSColor.systemRed.set()
                    warnImg.draw(in: warnRect, from: .zero, operation: .sourceOver, fraction: 1.0)
                }
            }

            // 2. Draw Number & Arrow Text
            let textX = currentX + dropletWidth + dropletToTextGap
            let textY = round((height - seg.textSize.height) / 2.0) - 0.5
            seg.attributedText.draw(at: NSPoint(x: textX, y: textY))

            // 3. Draw Optional Trend Chart
            if seg.showChart {
                let chartOriginX = textX + seg.textSize.width + textToChartGap
                let barAreaWidth: CGFloat = seg.chartWidth

                let minutesAgo = manager.currentReading(for: profile)?.minutesAgo ?? 0
                let showTimeLabel = (minutesAgo >= 6)

                let barAreaHeight: CGFloat = showTimeLabel ? 10.0 : 13.0
                let barBottomY: CGFloat = 3.0

                if showTimeLabel {
                    let timeString = "\(minutesAgo)m"
                    let timeFont = NSFont.systemFont(ofSize: 7.0, weight: .bold)
                    let timeAttributes: [NSAttributedString.Key: Any] = [
                        .font: timeFont,
                        .foregroundColor: NSColor.systemOrange
                    ]
                    let attributedTime = NSAttributedString(string: timeString, attributes: timeAttributes)
                    let timeSize = attributedTime.size()
                    let timeX = chartOriginX + max(0, (barAreaWidth - timeSize.width) / 2.0)
                    let timeY: CGFloat = 13.5
                    attributedTime.draw(at: NSPoint(x: timeX, y: timeY))
                }

                let recent = manager.recentReadings(for: profile)
                let sampleReadings = Array(recent.prefix(7).reversed())
                let barCount = sampleReadings.count

                if barCount > 0 {
                    let barWidth: CGFloat = max(2.0, (barAreaWidth - CGFloat(barCount - 1) * 1.5) / CGFloat(barCount))
                    let lowThresh = manager.lowThreshold(for: profile)
                    let highThresh = manager.highThreshold(for: profile)
                    let minVal = max(35.0, lowThresh - 25.0)
                    let maxVal = min(350.0, highThresh + 60.0)
                    let valRange = max(30.0, maxVal - minVal)

                    for (bIdx, reading) in sampleReadings.enumerated() {
                        let xPos = chartOriginX + CGFloat(bIdx) * (barWidth + 1.5)
                        let normalized = CGFloat(max(0.12, min(1.0, (reading.value - minVal) / valRange)))
                        let barH = max(2.0, barAreaHeight * normalized)
                        let barRect = NSRect(x: xPos, y: barBottomY, width: barWidth, height: barH)

                        let cat = manager.category(for: reading, profile: profile)
                        let barColor: NSColor
                        if manager.colorIconEnabled(for: profile) {
                            switch cat {
                            case .low, .veryLow:
                                barColor = manager.lowIconColor(for: profile).nsColor
                            case .high, .veryHigh:
                                barColor = manager.highIconColor(for: profile).nsColor
                            case .normal:
                                barColor = manager.normalIconColor(for: profile).nsColor
                            }
                        } else {
                            barColor = NSColor.labelColor.withAlphaComponent(0.8)
                        }

                        let barPath = NSBezierPath(roundedRect: barRect, xRadius: 1.0, yRadius: 1.0)
                        barColor.setFill()
                        barPath.fill()
                    }
                }
            }

            currentX += seg.totalWidth

            // Draw clean vertical separator divider between user segments
            if idx < segments.count - 1 {
                let divX = currentX + interSegmentGap
                let divRect = NSRect(x: divX, y: 4.5, width: 1.0, height: 13.0)
                NSColor.separatorColor.withAlphaComponent(0.45).setFill()
                divRect.fill()
                currentX += interSegmentGap * 2 + dividerWidth
            }
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }

        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(openSettingsMenuAction), keyEquivalent: ","))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit DexcomMenuBar", action: #selector(quitApp), keyEquivalent: "q"))
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
            return
        }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    @objc private func openSettingsMenuAction() {
        openSettingsWindow()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func openSettingsWindow() {
        if popover.isShown {
            popover.performClose(nil)
        }

        if let existing = settingsWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        guard let manager = manager else { return }
        let settingsView = SettingsView(manager: manager)
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 580),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Dexcom Share Settings"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false

        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct MainLauncher {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
    }
}
