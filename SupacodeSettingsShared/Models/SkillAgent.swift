public nonisolated enum SkillAgent: String, Equatable, Sendable, CaseIterable, Codable {
  case claude
  case codex
  case kiro
  // swiftlint:disable:next identifier_name
  case pi
  case antigravity

  /// Path under the user's home where the agent stores its config
  /// (e.g. `.claude`, `.codex`, `.kiro`, `.pi/agent`).
  public var configDirectoryName: String {
    switch self {
    case .claude: ".claude"
    case .codex: ".codex"
    case .kiro: ".kiro"
    case .pi: ".pi/agent"
    case .antigravity: ".gemini/config"
    }
  }

  /// User-facing name (e.g. "Claude Code", "Codex").
  public var displayName: String {
    switch self {
    case .claude: "Claude Code"
    case .codex: "Codex"
    case .kiro: "Kiro"
    case .pi: "Pi"
    case .antigravity: "Antigravity CLI"
    }
  }

  /// Asset catalog name for the agent's logo mark.
  public var assetName: String {
    switch self {
    case .claude: "claude-code-mark"
    case .codex: "codex-mark"
    case .kiro: "kiro-mark"
    case .pi: "pi-mark"
    case .antigravity: "antigravity-mark"
    }
  }
}
