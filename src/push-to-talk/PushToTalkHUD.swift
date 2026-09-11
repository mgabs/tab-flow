import Cocoa

/// Borderless, non-activating overlay shown only while push-to-talk is actively talking.
/// Modeled visually on macOS's native volume/brightness HUD: centered near the bottom of the
/// main screen, auto-hidden the instant talking stops.
class PushToTalkHUD {
    private static var panel: NSPanel?
    private static let width: CGFloat = 160
    private static let height: CGFloat = 56

    static func setVisible(_ visible: Bool) {
        visible ? show() : hide()
    }

    private static func show() {
        guard panel == nil, let screen = NSScreen.main else { return }
        let x = screen.frame.midX - width / 2
        let y = screen.frame.minY + 80
        let newPanel = NSPanel(contentRect: NSRect(x: x, y: y, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        newPanel.level = .statusBar
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = true
        newPanel.ignoresMouseEvents = true
        newPanel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        newPanel.contentView = makeContentView()
        newPanel.orderFrontRegardless()
        panel = newPanel
    }

    private static func makeContentView() -> NSView {
        let background = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 14
        background.layer?.masksToBounds = true
        let icon = NSImageView(frame: NSRect(x: (width - 24) / 2, y: 22, width: 24, height: 24))
        if #available(macOS 11.0, *) {
            icon.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: nil)
        }
        icon.imageScaling = .scaleProportionallyDown
        icon.contentTintColor = .systemRed
        let label = NSTextField(labelWithString: NSLocalizedString("Talking…", comment: "Push-to-talk on-screen indicator"))
        label.frame = NSRect(x: 0, y: 4, width: width, height: 16)
        label.alignment = .center
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .labelColor
        background.addSubview(icon)
        background.addSubview(label)
        return background
    }

    private static func hide() {
        panel?.orderOut(nil)
        panel = nil
    }
}
