import SwiftUI

struct AgentContextPopoverButton: View {
  let rootURL: URL
  @State private var isPresented = false
  @State private var snapshot: AgentContextSnapshot?
  @State private var isLoading = false

  var body: some View {
    Button {
      isPresented.toggle()
      loadSnapshot()
    } label: {
      Image(systemName: "sparkles")
        .font(.system(size: 13, weight: .semibold))
        .frame(width: 28, height: 28)
        .background(.regularMaterial, in: Circle())
        .overlay {
          Circle().stroke(.secondary.opacity(0.25), lineWidth: 1)
        }
    }
    .buttonStyle(.plain)
    .help("Show AI context files")
    .accessibilityLabel("AI context files")
    .popover(isPresented: $isPresented) {
      AgentContextPopoverView(
        rootURL: rootURL,
        snapshot: snapshot,
        isLoading: isLoading,
      )
      .task(id: rootURL) {
        loadSnapshot()
      }
    }
    .onChange(of: rootURL) { _, _ in
      snapshot = nil
      if isPresented {
        loadSnapshot()
      }
    }
  }

  private func loadSnapshot() {
    guard !isLoading else { return }
    isLoading = true
    let rootURL = rootURL
    Task {
      let loaded = await Task.detached(priority: .userInitiated) {
        AgentContextSnapshot.load(rootURL: rootURL)
      }.value
      snapshot = loaded
      isLoading = false
    }
  }
}

private struct AgentContextPopoverView: View {
  let rootURL: URL
  let snapshot: AgentContextSnapshot?
  let isLoading: Bool

  var body: some View {
    ScrollView { content.padding() }
      .frame(minWidth: 380, idealWidth: 460, maxWidth: 560, maxHeight: 520)
  }

  private var content: some View {
    VStack(alignment: .leading, spacing: 12) {
      header
      Divider()
      bodyContent
    }
  }

  @ViewBuilder
  private var bodyContent: some View {
    if isLoading && snapshot == nil {
      ProgressView()
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical)
    } else if let snapshot, snapshot.entries.isEmpty {
      ContentUnavailableView(
        "No AI Context Files",
        systemImage: "sparkles",
        description: Text(rootURL.path(percentEncoded: false)),
      )
    } else if let snapshot {
      entriesList(snapshot: snapshot)
    }
  }

  private func entriesList(snapshot: AgentContextSnapshot) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(snapshot.entries) { entry in
        AgentContextEntryView(entry: entry)
      }
      if snapshot.truncated {
        Text("Showing first \(AgentContextSnapshot.maxEntries) matching files.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 8) {
        Image(systemName: "sparkles")
          .foregroundStyle(.secondary)
          .accessibilityHidden(true)
        Text("AI Context")
          .font(.headline)
      }
      Text(rootURL.path(percentEncoded: false))
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(2)
        .truncationMode(.middle)
      if let snapshot {
        Text("\(snapshot.entries.count) files")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }
}

private struct AgentContextEntryView: View {
  let entry: AgentContextSnapshot.Entry

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        Text(entry.kind.rawValue)
          .font(.caption2)
          .foregroundStyle(.secondary)
        Text(entry.relativePath)
          .font(.caption)
          .lineLimit(1)
          .truncationMode(.middle)
        Spacer()
        if let byteCountDescription = entry.byteCountDescription {
          Text(byteCountDescription)
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
        }
      }
      if !entry.preview.isEmpty {
        Text(entry.preview)
          .font(.caption.monospaced())
          .foregroundStyle(.secondary)
          .lineLimit(5)
          .textSelection(.enabled)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 6)
  }
}

extension AgentContextSnapshot.Entry {
  fileprivate var byteCountDescription: String? {
    guard let byteCount else { return nil }
    return ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
  }
}
