import SwiftUI

struct MonitorView: View {
    @Bindable var scanner: ProcessScanner
    @State private var processToKill: ClaudeProcess? = nil
    @State private var showKillAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                Text("ClaudeMonitor")
                    .font(.system(.headline, design: .monospaced))
                    .fontWeight(.bold)
                Spacer()
                Text("\(scanner.processes.count)")
                    .font(.system(.title2, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundStyle(scanner.processes.isEmpty ? .tertiary : .primary)
                Text(scanner.processes.count == 1 ? "session" : "sessions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 10)

            // Stats bar
            if !scanner.processes.isEmpty {
                HStack(spacing: 16) {
                    StatBadge(label: "CPU", value: String(format: "%.0f%%", scanner.totalCPU))
                    StatBadge(label: "RAM", value: formatMemory(scanner.totalMemory))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }

            Divider()
                .padding(.horizontal, 16)

            // Content
            if scanner.processes.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "terminal")
                        .font(.system(size: 28, weight: .thin))
                        .foregroundStyle(.quaternary)
                    Text("No active sessions")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    if !scanner.interactiveProcesses.isEmpty {
                        SessionSection(
                            type: .interactive,
                            processes: scanner.interactiveProcesses,
                            onKill: { process in
                                processToKill = process
                                showKillAlert = true
                            },
                            onFocus: { process in
                                if let tty = process.tty { scanner.focusTerminal(tty: tty) }
                            }
                        )
                    }

                    if !scanner.backgroundProcesses.isEmpty {
                        if !scanner.interactiveProcesses.isEmpty {
                            Divider()
                                .padding(.horizontal, 16)
                        }
                        SessionSection(
                            type: .background,
                            processes: scanner.backgroundProcesses,
                            onKill: { process in
                                processToKill = process
                                showKillAlert = true
                            },
                            onFocus: { process in
                                if let tty = process.tty { scanner.focusTerminal(tty: tty) }
                            }
                        )
                    }
                }
                .padding(.vertical, 4)
            }

            Divider()
                .padding(.horizontal, 16)

            // Footer
            HStack {
                Text("↻ \(Int(max(UserDefaults.standard.double(forKey: "scanInterval"), 10).rounded()))s")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.quaternary)
                Spacer()
                SettingsLink {
                    Image(systemName: "gear")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Settings")

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Quit")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .frame(width: 400)
        .alert("Kill this session?", isPresented: $showKillAlert, presenting: processToKill) { process in
            Button("Cancel", role: .cancel) { }
            Button("Kill", role: .destructive) {
                scanner.kill(pid: process.pid)
            }
        } message: { process in
            Text("\(process.title) (PID \(process.pid)) will be terminated.")
        }
    }

    private func formatMemory(_ mb: Double) -> String {
        if mb >= 1024 { return String(format: "%.1fG", mb / 1024) }
        return String(format: "%.0fM", mb)
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.fill.quaternary, in: Capsule())
    }
}

// MARK: - Session Section

struct SessionSection: View {
    let type: SessionType
    let processes: [ClaudeProcess]
    var onKill: ((ClaudeProcess) -> Void)? = nil
    var onFocus: ((ClaudeProcess) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack(spacing: 6) {
                Circle()
                    .fill(type.color)
                    .frame(width: 6, height: 6)
                Text(type.rawValue.uppercased())
                    .font(.system(.caption2, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundStyle(type.color)
                Spacer()
                Text("\(processes.count)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 6)

            // Process rows
            ForEach(processes) { process in
                ProcessRowView(
                    process: process,
                    onKill: { onKill?(process) },
                    onFocus: { onFocus?(process) }
                )
            }
        }
    }
}
