import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("scanInterval") private var scanInterval: Double = 10
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("Monitoring") {
                Picker("Scan interval", selection: $scanInterval) {
                    Text("5 seconds").tag(5.0)
                    Text("10 seconds").tag(10.0)
                    Text("30 seconds").tag(30.0)
                }
            }

            Section("System") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                Link("GitHub", destination: URL(string: "https://github.com/ginoftn/claude-monitor")!)
            }
        }
        .formStyle(.grouped)
        .frame(width: 320, height: 320)
    }
}
