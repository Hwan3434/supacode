import Foundation

enum GitWorktreeHeadResolver {
  /// `nonisolated` so the synchronous file probing can run off the main actor.
  /// The module defaults to main-actor isolation, which would otherwise force
  /// callers like `GitClient.branchName` (a `nonisolated` async hot path on the
  /// worktree-refresh tick) to hop the disk I/O onto the main actor.
  nonisolated static func headURL(for worktreeURL: URL, fileManager: FileManager) -> URL? {
    let gitURL = worktreeURL.appending(path: ".git")
    var isDirectory = ObjCBool(false)
    guard
      fileManager.fileExists(
        atPath: gitURL.path(percentEncoded: false),
        isDirectory: &isDirectory,
      )
    else {
      return nil
    }
    if isDirectory.boolValue {
      return gitURL.appending(path: "HEAD")
    }
    guard let contents = try? String(contentsOf: gitURL, encoding: .utf8) else {
      return nil
    }
    guard let line = contents.split(whereSeparator: \.isNewline).first else {
      return nil
    }
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    let prefix = "gitdir:"
    guard trimmed.hasPrefix(prefix) else {
      return nil
    }
    let pathPart = trimmed.dropFirst(prefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
    guard !pathPart.isEmpty else {
      return nil
    }
    let gitdirURL = URL(fileURLWithPath: String(pathPart), relativeTo: worktreeURL)
      .standardizedFileURL
    return gitdirURL.appending(path: "HEAD")
  }
}
