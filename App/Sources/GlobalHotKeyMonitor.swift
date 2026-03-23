import Carbon
import Foundation

@MainActor
final class GlobalHotKeyMonitor {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let hotKeyID = EventHotKeyID(signature: OSType(0x434C4950), id: 1)

    @MainActor
    private static var action: (() -> Void)?

    init(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        Self.action = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetEventDispatcherTarget(),
            GlobalHotKeyMonitor.handleHotKey,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &hotKeyRef)
    }

    nonisolated private static let handleHotKey: EventHandlerUPP = { _, event, _ in
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr else { return noErr }
        if hotKeyID.signature == OSType(0x434C4950) && hotKeyID.id == 1 {
            Task { @MainActor in
                action?()
            }
        }
        return noErr
    }
}
