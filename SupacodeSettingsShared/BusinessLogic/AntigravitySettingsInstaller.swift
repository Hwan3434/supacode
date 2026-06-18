import Foundation

nonisolated struct AntigravitySettingsInstaller {
  let homeDirectoryURL: URL
  let fileManager: FileManager

  init(
    homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser,
    fileManager: FileManager = .default
  ) {
    self.homeDirectoryURL = homeDirectoryURL
    self.fileManager = fileManager
  }

  func installState() -> ComponentInstallState {
    let content = (try? String(contentsOf: settingsURL, encoding: .utf8)) ?? ""
    if content.contains(Self.hooksRuleMarker) {
      return .installed
    }
    return .notInstalled
  }

  func installAllHooks() throws {
    var content = (try? String(contentsOf: settingsURL, encoding: .utf8)) ?? ""
    if !content.contains(Self.hooksRuleMarker) {
      if !content.isEmpty && !content.hasSuffix("\n") {
        content += "\n"
      }
      content += Self.hooksRuleContent
      try fileManager.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      try content.write(to: settingsURL, atomically: true, encoding: .utf8)
    }
  }

  func uninstallAllHooks() throws {
    let content = (try? String(contentsOf: settingsURL, encoding: .utf8)) ?? ""
    guard content.contains(Self.hooksRuleMarker) else { return }
    
    // Naive string replacement to remove the block
    let newContent = content.replacingOccurrences(of: Self.hooksRuleContent, with: "")
    try newContent.write(to: settingsURL, atomically: true, encoding: .utf8)
  }

  private var settingsURL: URL {
    Self.settingsURL(homeDirectoryURL: homeDirectoryURL)
  }

  static func settingsURL(homeDirectoryURL: URL) -> URL {
    homeDirectoryURL
      .appendingPathComponent(".gemini", isDirectory: true)
      .appendingPathComponent("config", isDirectory: true)
      .appendingPathComponent("AGENTS.md", isDirectory: false)
  }

  static let hooksRuleMarker = "<RULE[supacode_hooks]>"
  
  static let hooksRuleContent = """
\(hooksRuleMarker)
# Supacode Integration Hooks
To support Supacode's rich notifications and agent badges, you MUST proactively notify the system of your status.
Whenever you finish a significant action and are waiting for the user, use the `run_command` tool to execute:
`echo "Task completed" | supacode integration event --event idle --agent antigravity --notify`
Whenever you start working on a long-running task, execute:
`supacode integration event --event busy --agent antigravity`
</RULE[supacode_hooks]>
"""
}
