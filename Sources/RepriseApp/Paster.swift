import AppKit
import ApplicationServices

/// Clipboard + "type it for me". Pasting into the previously focused app needs the
/// Accessibility permission (to post ⌘V); without it Reprise simply copies.
enum Paster {
    static func clipboardString() -> String {
        NSPasteboard.general.string(forType: .string) ?? ""
    }

    static func copy(_ text: String, images: [URL] = []) {
        let pb = NSPasteboard.general
        pb.clearContents()
        var items: [NSPasteboardWriting] = [text as NSString]
        items.append(contentsOf: images.map { $0 as NSURL })
        pb.writeObjects(items)
    }

    static var canAutoPaste: Bool { AXIsProcessTrusted() }

    static func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    /// Posts ⌘V to whatever app is frontmost.
    static func pasteIntoFrontmost(after delay: TimeInterval = 0.12) {
        guard canAutoPaste else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            let src = CGEventSource(stateID: .combinedSessionState)
            let v: CGKeyCode = 0x09
            let down = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: true)
            let up = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: false)
            down?.flags = .maskCommand
            up?.flags = .maskCommand
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
        }
    }
}
