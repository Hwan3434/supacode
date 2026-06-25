import Foundation

struct AgentContextSnapshot: Equatable, Sendable {
  struct Entry: Identifiable, Equatable, Sendable {
    let id: String
    let relativePath: String
    let kind: Kind
    let preview: String
    let byteCount: Int?

    enum Kind: String, Equatable, Sendable {
      case agentInstructions = "Instructions"
      case claude = "Claude"
      case codex = "Codex"
      case gemini = "Gemini"
      case geminiAntigravity = "Gemini / Antigravity"
      case skill = "Skill"
      case hook = "Hook"
      case mcp = "MCP"
      case command = "Command"
      case memory = "Memory"
      case env = "Env"
      case settings = "Settings"
      case other = "AI"
    }
  }

  let rootURL: URL
  let entries: [Entry]
  let truncated: Bool

  nonisolated static let maxEntries = 80
  private nonisolated static let maxDepth = 6
  private nonisolated static let previewByteLimit = 1_600
  private nonisolated static let maxPreviewFileBytes = 256_000

  nonisolated static func load(rootURL: URL) -> AgentContextSnapshot {
    let root = rootURL.standardizedFileURL
    let files = collectCandidateFiles(rootURL: root)
    let limited = files.prefix(maxEntries)
    let entries = limited.compactMap { url -> Entry? in
      makeEntry(url: url, rootURL: root)
    }
    return AgentContextSnapshot(
      rootURL: root,
      entries: entries,
      truncated: files.count > maxEntries,
    )
  }

  private nonisolated static func collectCandidateFiles(rootURL: URL) -> [URL] {
    let fileManager = FileManager.default
    let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
    guard
      let enumerator = fileManager.enumerator(
        at: rootURL,
        includingPropertiesForKeys: Array(keys),
        options: [.skipsPackageDescendants],
      )
    else {
      return []
    }

    var result: [URL] = []
    for case let url as URL in enumerator {
      let relativePath = relativePath(for: url, rootURL: rootURL)
      if shouldSkipTraversal(relativePath: relativePath) {
        enumerator.skipDescendants()
        continue
      }
      if depth(of: relativePath) > maxDepth {
        enumerator.skipDescendants()
        continue
      }
      guard let values = try? url.resourceValues(forKeys: keys) else { continue }
      if values.isDirectory == true {
        continue
      }
      guard values.isRegularFile == true || values.isSymbolicLink == true else { continue }
      guard isCandidate(relativePath: relativePath) else { continue }
      result.append(url)
      if result.count > maxEntries { break }
    }

    return result.sorted {
      relativePath(for: $0, rootURL: rootURL).localizedCaseInsensitiveCompare(
        relativePath(for: $1, rootURL: rootURL)
      ) == .orderedAscending
    }
  }

  private nonisolated static func makeEntry(url: URL, rootURL: URL) -> Entry? {
    let relativePath = relativePath(for: url, rootURL: rootURL)
    let byteCount = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
    guard byteCount.map({ $0 <= maxPreviewFileBytes }) ?? true else {
      return Entry(
        id: relativePath,
        relativePath: relativePath,
        kind: kind(for: relativePath),
        preview: "",
        byteCount: byteCount,
      )
    }
    guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else { return nil }
    let prefix = data.prefix(previewByteLimit)
    let rawPreview = String(bytes: prefix, encoding: .utf8) ?? ""
    let preview = sanitizedPreview(
      rawPreview,
      kind: kind(for: relativePath),
    )
    return Entry(
      id: relativePath,
      relativePath: relativePath,
      kind: kind(for: relativePath),
      preview: preview,
      byteCount: byteCount ?? data.count,
    )
  }

  private nonisolated static func shouldSkipTraversal(relativePath: String) -> Bool {
    let lowercased = relativePath.lowercased()
    return lowercased == ".git"
      || lowercased.hasPrefix(".git/")
      || lowercased == "node_modules"
      || lowercased.hasPrefix("node_modules/")
      || lowercased == ".build"
      || lowercased.hasPrefix(".build/")
      || lowercased == "deriveddata"
      || lowercased.hasPrefix("deriveddata/")
  }

  private nonisolated static func isCandidate(relativePath: String) -> Bool {
    let lowercased = relativePath.lowercased()
    let filename = URL(filePath: lowercased).lastPathComponent
    let isRootFile = !lowercased.contains("/")
    return filename == "agents.md"
      || filename == "claude.md"
      || filename == "codex.md"
      || filename == "gemini.md"
      || filename == "antigravity.md"
      || (isRootFile && filename == ".geminiignore")
      || (isRootFile && filename == ".env")
      || lowercased.hasPrefix(".agents/")
      || lowercased.hasPrefix(".claude/")
      || lowercased.hasPrefix(".codex/")
      || lowercased.hasPrefix(".gemini/")
  }

  private nonisolated static func kind(for relativePath: String) -> Entry.Kind {
    let lowercased = relativePath.lowercased()
    let filename = URL(filePath: lowercased).lastPathComponent
    if filename == "agents.md" { return .agentInstructions }
    if filename == ".env" { return .env }
    if filename == "claude.md" || lowercased.hasPrefix(".claude/") { return .claude }
    if filename == "codex.md" || lowercased.hasPrefix(".codex/") { return .codex }
    if filename == "gemini.md" { return .gemini }
    if filename == "antigravity.md" || lowercased.hasPrefix(".agents/") { return .geminiAntigravity }
    if lowercased.hasPrefix(".gemini/") { return .geminiAntigravity }
    if filename == "skill.md" || lowercased.contains("/skills/") { return .skill }
    if lowercased.contains("/commands/") { return .command }
    if filename == "mcp_config.json" || lowercased.contains("/mcp") { return .mcp }
    if filename.contains("hook") || lowercased.contains("/hooks/") { return .hook }
    if filename == "memory.md" || lowercased.contains("/memory/") { return .memory }
    if filename.hasSuffix(".json") || filename.hasSuffix(".toml") || filename.hasSuffix(".yaml") {
      return .settings
    }
    return .other
  }

  private nonisolated static func relativePath(for url: URL, rootURL: URL) -> String {
    let rootPath = rootURL.standardizedFileURL.path(percentEncoded: false)
    let path = url.standardizedFileURL.path(percentEncoded: false)
    guard path.hasPrefix(rootPath) else { return url.lastPathComponent }
    let startIndex = path.index(path.startIndex, offsetBy: rootPath.count)
    return String(path[startIndex...]).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
  }

  private nonisolated static func depth(of relativePath: String) -> Int {
    relativePath.split(separator: "/", omittingEmptySubsequences: true).count
  }

  private nonisolated static func sanitizedPreview(_ raw: String, kind: Entry.Kind) -> String {
    let cleaned =
      raw
      .replacing("\u{0}", with: "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard kind == .env else { return cleaned }
    return
      cleaned
      .split(separator: "\n", omittingEmptySubsequences: false)
      .map { line -> String in
        guard
          line.range(
            of: #"(?i)^\s*[A-Z0-9_]*(TOKEN|SECRET|PASSWORD|KEY|AUTH|CREDENTIAL|CERT)[A-Z0-9_]*\s*="#,
            options: .regularExpression
          ) != nil
        else {
          return String(line)
        }
        let key = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false).first ?? line
        return "\(key)=<redacted>"
      }
      .joined(separator: "\n")
  }
}
