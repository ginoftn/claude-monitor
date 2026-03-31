import SwiftUI

enum SessionType: String, CaseIterable {
    case interactive = "Interactive"
    case background = "Background"
}

extension SessionType {
    var color: Color {
        switch self {
        case .interactive: return .orange
        case .background: return .blue
        }
    }

    var icon: String {
        switch self {
        case .interactive: return "terminal"
        case .background: return "gearshape.2"
        }
    }
}

struct ClaudeProcess: Identifiable {
    let id: String
    let pid: Int
    let sessionType: SessionType
    var title: String
    let workingDirectory: String
    let tty: String?
    let cpuPercent: Double
    let memoryMB: Double
    var uptime: String? = nil
}
