import ComposableArchitecture
import Foundation

nonisolated enum ClaudeHookSettings {
  /// Canonical hook map for Claude. One composite command per (event,
  /// matcher) slot keeps the prune-and-replace cycle idempotent. Reads the
  /// live notification toggles so a settings change is reflected the next
  /// time hooks are installed (see `SettingsFeature`'s reinstall-on-toggle
  /// binding case, which fires this immediately rather than waiting for the
  /// next outdated-check).
  static func hooksByEvent() throws -> [String: [JSONValue]] {
    @Shared(.settingsFile) var settingsFile
    return try AgentHookPayloadSupport.extractHookGroups(
      from: ClaudeHooksPayload(
        notifyOnTurnComplete: settingsFile.global.notifyOnTurnCompleteEnabled,
        notifyOnAwaitingInput: settingsFile.global.notifyOnAwaitingInputEnabled,
      ),
      invalidConfiguration: ClaudeHookSettingsError.invalidConfiguration,
    )
  }
}

nonisolated enum ClaudeHookSettingsError: Error {
  case invalidConfiguration
}

// MARK: - Hook payload.

// Atomic state-set: UserPromptSubmit / PreToolUse fire `busy`. The
// AskUserQuestion|ExitPlanMode PreToolUse matcher and PermissionRequest set
// `awaitingInput` (an explicit prompt the user must answer). PostToolUseFailure
// and PermissionDenied set `error`. Notification fires notify-only; Stop and
// SessionEnd reset to `idle`. The pid liveness sweep is the safety net for
// crashed turns. Only Claude has tool-level granularity; Codex and Kiro stay
// turn-level, so their shimmer spans the whole turn.
private nonisolated struct ClaudeHooksPayload: Encodable {
  static let awaitingInputToolMatcher = "AskUserQuestion|ExitPlanMode"

  enum CodingKeys: String, CodingKey {
    case hooks
  }

  // `hooks` is computed (conditional on the toggle inputs below), so synthesis
  // can't derive `encode(to:)` from CodingKeys alone — write it explicitly.
  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(hooks, forKey: .hooks)
  }

  private static let busy = AgentHookSettingsCommand.compositeCommand(
    events: [.busy], forwardStdinAsNotification: false, agent: .claude, )
  private static let idle = AgentHookSettingsCommand.compositeCommand(
    events: [.idle], forwardStdinAsNotification: false, agent: .claude, )
  private static let awaitingInput = AgentHookSettingsCommand.compositeCommand(
    events: [.awaitingInput], forwardStdinAsNotification: false, agent: .claude, )
  private static let notifyOnly = AgentHookSettingsCommand.compositeCommand(
    events: [], forwardStdinAsNotification: true, agent: .claude, )
  private static let idleAndNotify = AgentHookSettingsCommand.compositeCommand(
    events: [.idle], forwardStdinAsNotification: true, agent: .claude, )
  private static let sessionStart = AgentHookSettingsCommand.compositeCommand(
    events: [.sessionStart], forwardStdinAsNotification: false, agent: .claude, )
  private static let sessionEndAndIdle = AgentHookSettingsCommand.compositeCommand(
    events: [.sessionEnd, .idle], forwardStdinAsNotification: false, agent: .claude, )
  private static let errorAndNotify = AgentHookSettingsCommand.compositeCommand(
    events: [.error], forwardStdinAsNotification: true, agent: .claude, )

  let notifyOnTurnComplete: Bool
  let notifyOnAwaitingInput: Bool

  // Computed (not a stored literal) since the Stop/Notification entries are
  // conditional on the live notification-toggle settings. `compositeCommand`
  // preconditions against an all-off composite (no events, no notify), so a
  // disabled toggle swaps to an `idle`-only command (Stop) or drops the key
  // entirely (Notification) rather than emitting an empty composite.
  var hooks: [String: [AgentHookGroup]] {
    var map: [String: [AgentHookGroup]] = [
      "SessionStart": [
        .init(hooks: [.init(command: Self.sessionStart, timeout: 5)])
      ],
      "UserPromptSubmit": [
        .init(hooks: [.init(command: Self.busy, timeout: 10)])
      ],
      "PreToolUse": [
        .init(matcher: "", hooks: [.init(command: Self.busy, timeout: 5)]),
        // Array-order: matched-by-name fires AFTER matcher-"", so awaiting wins.
        .init(
          matcher: Self.awaitingInputToolMatcher,
          hooks: [.init(command: Self.awaitingInput, timeout: 5)],
        ),
      ],
      "PermissionRequest": [
        .init(hooks: [.init(command: Self.awaitingInput, timeout: 5)])
      ],
      // "PostToolUse": [
      //   .init(matcher: "", hooks: [.init(command: Self.idle, timeout: 5)])
      // ],
      "Stop": [
        .init(hooks: [
          .init(command: notifyOnTurnComplete ? Self.idleAndNotify : Self.idle, timeout: 10)
        ])
      ],
      "PostToolUseFailure": [
        .init(hooks: [.init(command: Self.errorAndNotify, timeout: 10)])
      ],
      "PermissionDenied": [
        .init(hooks: [.init(command: Self.errorAndNotify, timeout: 10)])
      ],
      "SessionEnd": [
        .init(matcher: "", hooks: [.init(command: Self.sessionEndAndIdle, timeout: 5)])
      ],
    ]
    if notifyOnAwaitingInput {
      map["Notification"] = [
        .init(matcher: "", hooks: [.init(command: Self.notifyOnly, timeout: 10)])
      ]
    }
    return map
  }
}
