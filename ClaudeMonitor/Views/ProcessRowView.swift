import SwiftUI

struct ProcessRowView: View {
    let process: ClaudeProcess
    var onKill: (() -> Void)? = nil
    var onFocus: (() -> Void)? = nil
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // PID
            Text("\(process.pid)")
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .trailing)

            // Project name
            Text(process.title)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            // Metrics
            if let uptime = process.uptime {
                Text(uptime)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(width: 48, alignment: .trailing)
            }

            Text(String(format: "%.0f%%", process.cpuPercent))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(process.cpuPercent > 50 ? .orange : .secondary)
                .frame(width: 32, alignment: .trailing)

            Text(formatMemory(process.memoryMB))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)

            // Kill button
            if let onKill {
                Button(action: onKill) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red.opacity(isHovered ? 0.8 : 0.3))
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .help("Kill session")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(isHovered ? Color.white.opacity(0.05) : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture {
            onFocus?()
        }
        .contextMenu {
            if process.tty != nil {
                Button("Focus in Terminal") { onFocus?() }
            }
            Divider()
            Button("Copy PID") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("\(process.pid)", forType: .string)
            }
            Button("Copy working directory") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(process.workingDirectory, forType: .string)
            }
            Divider()
            if let onKill {
                Button("Kill session", role: .destructive) { onKill() }
            }
        }
    }

    private func formatMemory(_ mb: Double) -> String {
        if mb >= 1024 { return String(format: "%.1fG", mb / 1024) }
        return String(format: "%.0fM", mb)
    }
}
