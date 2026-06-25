import Foundation
import Testing

@testable import supacode

struct AgentContextSnapshotTests {
  @Test func loadFindsAgentContextFilesAcrossSupportedCLIs() throws {
    let root = try makeTemporaryDirectory()
    try write("repo guidance", to: root.appending(path: "AGENTS.md"))
    try write("claude guidance", to: root.appending(path: "CLAUDE.md"))
    try write("codex hooks", to: root.appending(path: ".codex/hooks.json"))
    try write("claude settings", to: root.appending(path: ".claude/settings.local.json"))
    try write("gemini context", to: root.appending(path: "GEMINI.md"))
    try write("gemini settings", to: root.appending(path: ".gemini/settings.json"))
    try write("agy mcp", to: root.appending(path: ".agents/mcp_config.json"))
    try write("agy skill", to: root.appending(path: ".agents/skills/review/SKILL.md"))

    let snapshot = AgentContextSnapshot.load(rootURL: root)
    let paths = snapshot.entries.map(\.relativePath)

    #expect(paths.contains("AGENTS.md"))
    #expect(paths.contains("CLAUDE.md"))
    #expect(paths.contains("GEMINI.md"))
    #expect(paths.contains(".codex/hooks.json"))
    #expect(paths.contains(".claude/settings.local.json"))
    #expect(paths.contains(".gemini/settings.json"))
    #expect(paths.contains(".agents/mcp_config.json"))
    #expect(paths.contains(".agents/skills/review/SKILL.md"))
  }

  @Test func loadRedactsEnvPreviewSecrets() throws {
    let root = try makeTemporaryDirectory()
    try write(
      """
      GEMINI_API_KEY=secret
      PUBLIC_VALUE=visible
      """,
      to: root.appending(path: ".gemini/.env"),
    )

    let snapshot = AgentContextSnapshot.load(rootURL: root)
    let entry = try #require(snapshot.entries.first { $0.relativePath == ".gemini/.env" })

    #expect(entry.preview.contains("GEMINI_API_KEY=<redacted>"))
    #expect(entry.preview.contains("PUBLIC_VALUE=visible"))
    #expect(!entry.preview.contains("secret"))
  }

  private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appending(path: "supacode-agent-context-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  private func write(_ contents: String, to url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true,
    )
    try contents.write(to: url, atomically: true, encoding: .utf8)
  }
}
