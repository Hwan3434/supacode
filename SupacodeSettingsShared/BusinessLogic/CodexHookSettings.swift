import ComposableArchitecture
import Foundation

nonisolated enum CodexHookSettings {
  /// Single canonical hook map for Codex. See `ClaudeHookSettings` for the
  /// composite-command rationale (one Supacode-managed entry per slot →
  /// idempotent prune-and-replace).
  static func hooksByEvent() throws -> [String: [JSONValue]] {
    @Shared(.settingsFile) var settingsFile
    return try AgentHookPayloadSupport.extractHookGroups(
      from: CodexHooksPayload(notifyOnTurnComplete: settingsFile.global.notifyOnTurnCompleteEnabled),
      invalidConfiguration: CodexHookSettingsError.invalidConfiguration,
    )
  }
}

nonisolated enum CodexHookSettingsError: Error {
  case invalidConfiguration
}

// MARK: - Hook payload.

// Turn-level activity only — Codex doesn't expose PreToolUse/PostToolUse
// at a useful granularity (Bash-only), so a single `busy` at submit and
// a single `idle` + notify at stop is the cleanest model. SessionStart
// fires on the first turn rather than on session open (openai/codex#15266),
// so the badge appears once the user submits a prompt. Codex has no
// SessionEnd, so the badge clears via the pid liveness sweep when Codex
// exits.
private nonisolated struct CodexHooksPayload: Encodable {
  enum CodingKeys: String, CodingKey {
    case hooks
  }

  // `hooks` is computed (conditional on `notifyOnTurnComplete`), so synthesis
  // can't derive `encode(to:)` from CodingKeys alone — write it explicitly.
  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(hooks, forKey: .hooks)
  }

  private static let busy = AgentHookSettingsCommand.compositeCommand(
    events: [.busy], forwardStdinAsNotification: false, agent: .codex, )
  private static let idle = AgentHookSettingsCommand.compositeCommand(
    events: [.idle], forwardStdinAsNotification: false, agent: .codex, )
  private static let idleAndNotify = AgentHookSettingsCommand.compositeCommand(
    events: [.idle], forwardStdinAsNotification: true, agent: .codex, )
  private static let sessionStart = AgentHookSettingsCommand.compositeCommand(
    events: [.sessionStart], forwardStdinAsNotification: false, agent: .codex, )

  let notifyOnTurnComplete: Bool

  var hooks: [String: [AgentHookGroup]] {
    [
      "SessionStart": [
        .init(hooks: [.init(command: Self.sessionStart, timeout: 5)])
      ],
      "UserPromptSubmit": [
        .init(hooks: [.init(command: Self.busy, timeout: 10)])
      ],
      "Stop": [
        .init(hooks: [
          .init(command: notifyOnTurnComplete ? Self.idleAndNotify : Self.idle, timeout: 10)
        ])
      ],
    ]
  }
}
