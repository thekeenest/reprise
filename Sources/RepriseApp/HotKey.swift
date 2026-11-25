import Carbon.HIToolbox
import AppKit

/// System-wide hotkey via Carbon — works without any permission prompts.
final class HotKey {
    struct Combo: Hashable, Identifiable {
        var keyCode: UInt32
        var modifiers: UInt32
        var label: String
        var id: String { label }

        static let optCmdP = Combo(keyCode: UInt32(kVK_ANSI_P), modifiers: UInt32(cmdKey | optionKey), label: "⌥⌘P")
        static let ctrlOptSpace = Combo(keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey | optionKey), label: "⌃⌥Space")
        static let hyperP = Combo(keyCode: UInt32(kVK_ANSI_P), modifiers: UInt32(cmdKey | optionKey | controlKey | shiftKey), label: "⌃⌥⇧⌘P")
        static let all: [Combo] = [.optCmdP, .ctrlOptSpace, .hyperP]

        static func named(_ label: String) -> Combo { all.first { $0.label == label } ?? .optCmdP }
    }

    private var ref: EventHotKeyRef?
    private let id: UInt32
    private static var actions: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private static var handlerInstalled = false

    init(_ combo: Combo, action: @escaping () -> Void) {
        HotKey.installHandlerOnce()
        id = HotKey.nextID
        HotKey.nextID += 1
        HotKey.actions[id] = action
        let hotKeyID = EventHotKeyID(signature: OSType(0x5250_5253), id: id) // 'RPRS'
        RegisterEventHotKey(combo.keyCode, combo.modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
    }

    func invalidate() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
        HotKey.actions[id] = nil
    }

    deinit { invalidate() }

    private static func installHandlerOnce() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hk = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hk)
            let id = hk.id
            DispatchQueue.main.async { HotKey.actions[id]?() }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
