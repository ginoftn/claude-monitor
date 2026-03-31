import Foundation
import Observation

@Observable
class ProcessScanner {
    var processes: [ClaudeProcess] = []
    var isScanning = false
    var isMidScan = false

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var scanInterval: TimeInterval = 10

    var interactiveProcesses: [ClaudeProcess] {
        processes.filter { $0.sessionType == .interactive }
            .sorted { $0.cpuPercent > $1.cpuPercent }
    }

    var backgroundProcesses: [ClaudeProcess] {
        processes.filter { $0.sessionType == .background }
            .sorted { $0.cpuPercent > $1.cpuPercent }
    }

    var totalCPU: Double {
        processes.reduce(0) { $0 + $1.cpuPercent }
    }

    var totalMemory: Double {
        processes.reduce(0) { $0 + $1.memoryMB }
    }

    func startScanning(interval: TimeInterval = 10) {
        scanInterval = interval
        isScanning = true
        Task { await scan() }
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { await self.scan() }
        }
    }

    func stopScanning() {
        timer?.invalidate()
        timer = nil
        isScanning = false
    }

    func restartScanning(interval: TimeInterval) {
        stopScanning()
        startScanning(interval: interval)
    }

    func kill(pid: Int) {
        Task {
            await shell("kill -TERM \(pid)")
            await scan()
        }
    }

    @MainActor
    func scan() async {
        isMidScan = true
        defer { isMidScan = false }
        let psOutput = await shell("ps -eo pid,ppid,tty,%cpu,rss,command | grep '[c]laude' | grep -v 'Claude.app' | grep -v grep")
        let uptimes = await fetchUptimes()
        var found: [ClaudeProcess] = []

        for line in psOutput.split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 5, omittingEmptySubsequences: true)
            guard parts.count >= 6 else { continue }
            guard let pid = Int(parts[0]),
                  let ppid = Int(parts[1]) else { continue }
            let tty = String(parts[2])
            guard let cpu = Double(parts[3]),
                  let rssKB = Double(parts[4]) else { continue }
            let command = String(parts[5])

            // Only match claude CLI processes
            guard command.hasPrefix("claude") || command.contains("/claude") else { continue }
            // Skip claude-related helper processes (mcp, lsp, etc.)
            guard !command.contains("claude-") || command.contains("claude-code") else { continue }

            let sessionType = classifySession(ppid: ppid, tty: tty)
            let cwd = await resolveWorkingDirectory(pid: pid, ppid: ppid)
            let title = cwdShortName(cwd)
            let memMB = rssKB / 1024.0

            var process = ClaudeProcess(
                id: "claude-\(pid)",
                pid: pid,
                sessionType: sessionType,
                title: title,
                workingDirectory: cwd,
                tty: tty != "??" ? tty : nil,
                cpuPercent: cpu,
                memoryMB: memMB
            )
            process.uptime = uptimes[pid]
            found.append(process)
        }

        processes = found
    }

    // MARK: - Classification

    private func classifySession(ppid: Int, tty: String) -> SessionType {
        if tty != "??" {
            // Has a TTY — check if parent is a shell (interactive)
            let parentCmd = syncShell("ps -o comm= -p \(ppid)")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let shells = ["zsh", "bash", "fish", "sh", "login", "Terminal", "iTerm2", "WarpTerminal"]
            if shells.contains(where: { parentCmd.contains($0) }) {
                return .interactive
            }
        }
        return .background
    }

    // MARK: - Working Directory

    private func resolveWorkingDirectory(pid: Int, ppid: Int) async -> String {
        // Try parent process cwd first (Claude runs with / as cwd)
        let lsofOutput = await shell("lsof -a -p \(ppid) -d cwd 2>/dev/null | tail -1")
        let parts = lsofOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
        if let last = parts.last {
            let path = String(last)
            if path != "/" && !path.isEmpty { return path }
        }

        // Fallback: try the claude process itself
        let selfOutput = await shell("lsof -a -p \(pid) -d cwd 2>/dev/null | tail -1")
        let selfParts = selfOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
        if let last = selfParts.last {
            return String(last)
        }

        return "/"
    }

    // MARK: - Uptimes

    func focusTerminal(tty: String) {
        // tty format from ps: "ttys003" → we need to match Terminal.app's tty
        let script = """
        tell application "Terminal"
            activate
            set targetTTY to "/dev/\(tty)"
            repeat with w in windows
                repeat with t in tabs of w
                    if tty of t is targetTTY then
                        set selected tab of w to t
                        set index of w to 1
                        return
                    end if
                end repeat
            end repeat
        end tell
        """
        Task {
            await shell("osascript -e '\(script.replacingOccurrences(of: "'", with: "'\\''"))'")
        }
    }

    private func cwdShortName(_ cwd: String) -> String {
        if cwd == "/" { return "unknown" }
        let name = (cwd as NSString).lastPathComponent
        if name.count <= 30 { return name }
        return String(name.prefix(28)) + "…"
    }

    private func fetchUptimes() async -> [Int: String] {
        let output = await shell("ps -eo pid,etime")
        var result: [Int: String] = [:]
        for line in output.split(separator: "\n").dropFirst() {
            let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2, let pid = Int(parts[0]) else { continue }
            let raw = parts[1].trimmingCharacters(in: .whitespaces)
            result[pid] = formatUptime(raw)
        }
        return result
    }

    private func formatUptime(_ etime: String) -> String {
        let parts = etime.split(separator: ":")
        if etime.contains("-") {
            let dayHour = parts[0].split(separator: "-")
            return "\(dayHour[0])d \(dayHour[1])h"
        } else if parts.count == 3 {
            return "\(parts[0])h\(parts[1])m"
        } else if parts.count == 2 {
            let mins = Int(parts[0]) ?? 0
            if mins == 0 { return "<1m" }
            return "\(mins)m"
        }
        return etime
    }

    // MARK: - Shell helpers

    @discardableResult
    private func shell(_ command: String) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = self.syncShell(command)
                continuation.resume(returning: result)
            }
        }
    }

    private func syncShell(_ command: String) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
