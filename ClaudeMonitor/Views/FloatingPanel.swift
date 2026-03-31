import AppKit
import SwiftUI

class FloatingPanel<Content: View>: NSPanel {
    init(@ViewBuilder content: @escaping () -> Content) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 460),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )

        level = .normal
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isExcludedFromWindowsMenu = true
        minSize = NSSize(width: 300, height: 180)
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        let hostingView = NSHostingView(rootView: content())
        contentView = hostingView
    }

    override var canBecomeKey: Bool { true }
}

// MARK: - FloatingPanelManager

@MainActor
class FloatingPanelManager {
    static let shared = FloatingPanelManager()
    private var panel: FloatingPanel<AnyView>?

    func show(scanner: ProcessScanner) {
        if let panel, panel.isVisible {
            panel.orderFront(nil)
            return
        }

        let panel = FloatingPanel {
            AnyView(
                MonitorView(scanner: scanner)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .frame(minWidth: 300)
            )
        }

        if let screen = NSScreen.main {
            let visibleFrame = screen.visibleFrame
            let x = visibleFrame.maxX - 400
            let y = visibleFrame.minY + 20
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.orderFront(nil)
        self.panel = panel
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func toggle(scanner: ProcessScanner) {
        if let panel, panel.isVisible {
            hide()
        } else {
            show(scanner: scanner)
        }
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }
}
