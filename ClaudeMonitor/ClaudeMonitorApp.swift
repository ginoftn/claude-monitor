import SwiftUI

@main
struct ClaudeMonitorApp: App {
    @State private var scanner = ProcessScanner()
    @State private var scanAnimationIcon: String?
    @State private var animationTask: Task<Void, Never>?
    @AppStorage("scanInterval") private var scanInterval: Double = 25

    var body: some Scene {
        MenuBarExtra {
            MonitorView(scanner: scanner)
        } label: {
            HStack(spacing: 4) {
                Image(menubarIcon)
                    .renderingMode(.template)
                if scanner.processes.count > 0 {
                    Text("\(scanner.processes.count)")
                }
            }
        }
        .menuBarExtraStyle(.window)
        .onChange(of: scanInterval) { _, newValue in
            scanner.restartScanning(interval: newValue)
        }
        .onChange(of: scanner.isMidScan) { _, scanning in
            if scanning {
                playScanAnimation()
            }
        }

        Settings {
            SettingsView()
        }
    }

    private var menubarIcon: String {
        if let override = scanAnimationIcon {
            return override
        }
        if !scanner.isScanning {
            return "menubar-off"
        } else {
            return "menubar-idle"
        }
    }

    private func playScanAnimation() {
        animationTask?.cancel()
        animationTask = Task { @MainActor in
            // idle → left → idle → right → idle → blink → idle
            let frames: [(String, Double)] = [
                ("menubar-idle",   0.20),
                ("menubar-scan-1", 0.70),
                ("menubar-idle",   0.30),
                ("menubar-scan-2", 0.70),
                ("menubar-idle",   0.30),
                ("menubar-off",    0.35),
            ]
            for (icon, duration) in frames {
                guard !Task.isCancelled else { break }
                scanAnimationIcon = icon
                try? await Task.sleep(for: .seconds(duration))
            }
            scanAnimationIcon = nil
        }
    }

    init() {
        let interval = UserDefaults.standard.double(forKey: "scanInterval")
        scanner.startScanning(interval: interval > 0 ? interval : 25)
    }
}
