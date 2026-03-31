import Foundation

enum SessionTitleResolver {

    /// Resolve a human-readable title for a Claude Code session.
    /// Pure Swift port of session-title.py — no Python dependency.
    static func resolve(pid: Int, cwd: String) -> String {
        let home = NSHomeDirectory()

        // Step 1: Find session file
        let sessionFile = "\(home)/.claude/sessions/\(pid).json"
        guard let sessionData = try? Data(contentsOf: URL(fileURLWithPath: sessionFile)),
              let session = try? JSONSerialization.jsonObject(with: sessionData) as? [String: Any],
              let sessionId = session["sessionId"] as? String else {
            return fallbackTitle(pid: pid, cwd: cwd)
        }

        // Step 2: Find conversation JSONL
        let projectsDir = "\(home)/.claude/projects"
        guard let convFile = findConversationFile(sessionId: sessionId, in: projectsDir) else {
            return fallbackTitle(pid: pid, cwd: cwd)
        }

        // Step 3: Extract title from first meaningful user message
        if let title = extractTitle(from: convFile) {
            return title
        }

        return fallbackTitle(pid: pid, cwd: cwd)
    }

    private static func findConversationFile(sessionId: String, in projectsDir: String) -> String? {
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(atPath: projectsDir) else { return nil }
        for dir in dirs {
            let candidate = "\(projectsDir)/\(dir)/\(sessionId).jsonl"
            if fm.fileExists(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    private static func extractTitle(from path: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let content = String(data: data, encoding: .utf8) else { return nil }

        let skipPrefixes = ["Base directory", "# ", "<", "[Image:", "[Request interrupted", "[Request cancelled"]

        for line in content.split(separator: "\n") {
            guard let msg = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  msg["type"] as? String == "user",
                  let message = msg["message"] as? [String: Any],
                  let parts = message["content"] as? [[String: Any]] else { continue }

            for part in parts {
                guard part["type"] as? String == "text",
                      var text = part["text"] as? String else { continue }

                text = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if text.isEmpty { continue }
                if skipPrefixes.contains(where: { text.hasPrefix($0) }) { continue }
                // Skip bare slash commands
                if text.hasPrefix("/") && !text.contains(" ") { continue }
                // Skip very short messages
                if text.count < 10 { continue }
                // Clean slash-command prefix
                if text.hasPrefix("/"), let spaceIdx = text.firstIndex(of: " ") {
                    text = String(text[text.index(after: spaceIdx)...])
                }
                // Capitalize
                text = text.prefix(1).uppercased() + text.dropFirst()
                // Truncate
                if text.count > 50 {
                    text = String(text.prefix(47)) + "..."
                }
                // Return first meaningful message as title
                return text
            }
        }

        return nil
    }

    private static func fallbackTitle(pid: Int, cwd: String) -> String {
        if cwd != "/" {
            let name = (cwd as NSString).lastPathComponent
            if name.count <= 30 { return name }
            return String(name.prefix(28)) + "…"
        }
        return "Session #\(pid)"
    }
}
