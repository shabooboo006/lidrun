import Carbon
import Foundation

@MainActor
final class GlobalHotKeyController {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var action: (() -> Void)?

    init() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let controller = Unmanaged<GlobalHotKeyController>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in controller.action?() }
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &eventHandlerRef
        )
    }

    func stop() {
        unregister()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    func setEnabled(_ enabled: Bool, action: @escaping () -> Void) {
        self.action = action
        if enabled {
            register()
        } else {
            unregister()
        }
    }

    private func register() {
        unregister()

        let hotKeyID = EventHotKeyID(signature: OSType(0x4C524E31), id: 1)
        let modifiers = UInt32(cmdKey | optionKey | controlKey)
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_L),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status != noErr {
            AppLog.app.error("Failed to register global hotkey: \(status, privacy: .public)")
        }
    }

    private func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }
}
