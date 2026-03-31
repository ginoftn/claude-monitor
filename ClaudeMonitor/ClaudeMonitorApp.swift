import SwiftUI

@main
struct ClaudeMonitorApp: App {
    @State private var scanner = ProcessScanner()
    @AppStorage("scanInterval") private var scanInterval: Double = 10

    var body: some Scene {
        MenuBarExtra {
            MonitorView(scanner: scanner)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "terminal")
                if scanner.processes.count > 0 {
                    Text("\(scanner.processes.count)")
                }
            }
        }
        .menuBarExtraStyle(.window)
        .onChange(of: scanInterval) { _, newValue in
            scanner.restartScanning(interval: newValue)
        }

        Settings {
            SettingsView()
        }
    }

    init() {
        let interval = UserDefaults.standard.double(forKey: "scanInterval")
        scanner.startScanning(interval: interval > 0 ? interval : 10)
    }
}
