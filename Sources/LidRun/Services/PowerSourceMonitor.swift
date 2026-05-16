import Foundation
import IOKit.ps

@MainActor
final class PowerSourceMonitor: ObservableObject {
    @Published private(set) var snapshot: PowerSnapshot = .unknown

    private var timer: Timer?
    private var runLoopSource: CFRunLoopSource?
    var onChange: ((PowerSnapshot) -> Void)?

    func start() {
        refresh()

        if runLoopSource == nil {
            let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
            if let source = IOPSNotificationCreateRunLoopSource({ context in
                guard let context else { return }
                let monitor = Unmanaged<PowerSourceMonitor>.fromOpaque(context).takeUnretainedValue()
                Task { @MainActor in monitor.refresh() }
            }, context)?.takeRetainedValue() {
                runLoopSource = source
                CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalStateDidChange),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
            self.runLoopSource = nil
        }
        NotificationCenter.default.removeObserver(self)
    }

    func refresh() {
        let newSnapshot = readSnapshot()
        guard newSnapshot != snapshot else { return }
        snapshot = newSnapshot
        onChange?(newSnapshot)
    }

    private func readSnapshot() -> PowerSnapshot {
        var isOnACPower = false
        var batteryPercent: Int?

        if let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] {
            for source in sources {
                guard let description = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any] else {
                    continue
                }

                if let state = description[kIOPSPowerSourceStateKey] as? String {
                    isOnACPower = state == kIOPSACPowerValue
                }

                if let current = description[kIOPSCurrentCapacityKey] as? Int,
                   let max = description[kIOPSMaxCapacityKey] as? Int,
                   max > 0 {
                    batteryPercent = Int((Double(current) / Double(max) * 100).rounded())
                }
            }
        }

        return PowerSnapshot(
            isOnACPower: isOnACPower,
            batteryPercent: batteryPercent,
            thermalState: ProcessInfo.processInfo.thermalState
        )
    }

    @objc private func thermalStateDidChange() {
        refresh()
    }
}
