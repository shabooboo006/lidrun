import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let state: AppState
    private var cancellables = Set<AnyCancellable>()

    init(state: AppState) {
        self.state = state
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureStatusItem()
        configurePopover()
        bindState()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateIcon()
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 360, height: 600)
        popover.contentViewController = NSHostingController(
            rootView: LidRunPopoverView()
                .environmentObject(state)
                .environmentObject(state.settings)
                .environmentObject(state.helperAuthorization)
        )
    }

    private func bindState() {
        state.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateIcon()
                }
            }
            .store(in: &cancellables)

        state.settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateIcon()
                }
            }
            .store(in: &cancellables)

        state.helperAuthorization.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateIcon()
                }
            }
            .store(in: &cancellables)
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        button.image = StatusIconRenderer.image(
            active: state.isActive || state.lidRunState == .running,
            colored: state.settings.coloredIcon,
            lidState: state.lidRunState,
            helperStatus: state.helperAuthorization.status
        )
        button.toolTip = state.statusMessage
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent

        if event?.type == .rightMouseUp {
            togglePopover(sender)
            return
        }

        if state.settings.quickToggleClick {
            state.toggleActive()
        } else {
            togglePopover(sender)
        }
    }

    private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
