import AppKit
import SwiftUI

/// Tracks whether the user is currently holding ⌘ or ⌃ so the UI can surface shortcut hints.
@MainActor
@Observable
final class CommandKeyObserver {
  var isPressed: Bool
  private var monitor: Any?
  private var didBecomeActiveObserver: NSObjectProtocol?
  private var didResignActiveObserver: NSObjectProtocol?

  init() {
    isPressed = false
    monitor = nil
    didBecomeActiveObserver = nil
    didResignActiveObserver = nil
    configureObservers()
  }

  private func configureObservers() {
    // Disabled to save performance, as requested by the user.
    // The event monitor was causing unnecessary overhead.
  }

  nonisolated static func shouldShowShortcuts(for modifierFlags: NSEvent.ModifierFlags) -> Bool {
    modifierFlags.contains(.command) || modifierFlags.contains(.control)
  }

  private func handleCommandKeyChange(isDown: Bool) {
    // Flip immediately; consumers fade the visual change in/out themselves.
    isPressed = isDown
  }
}
