import SwiftUI

struct ToolbarNotificationsPopoverButton: View {
  let groups: [ToolbarNotificationRepositoryGroup]
  let unseenWorktreeCount: Int
  let onSelectNotification: (Worktree.ID, WorktreeTerminalNotification) -> Void
  let onDismissAll: () -> Void
  @State private var isPresented = false

  private var notificationCount: Int {
    groups.reduce(0) { count, repository in
      count
        + repository.worktrees.reduce(0) { worktreeCount, worktree in
          worktreeCount + worktree.notifications.filter { !$0.isRead }.count
        }
    }
  }

  var body: some View {
    Button {
      isPresented.toggle()
    } label: {
      HStack(spacing: 6) {
        Image(systemName: unseenWorktreeCount > 0 ? "bell.badge.fill" : "bell.fill")
          .foregroundStyle(unseenWorktreeCount > 0 ? .orange : .secondary)
          .accessibilityHidden(true)
        if notificationCount > 0 {
          Text(notificationCount, format: .number)
            .font(.caption.monospacedDigit())
        }
      }
    }
    .help("Click to show notifications.")
    .accessibilityLabel("Notifications")
    .popover(isPresented: $isPresented) {
      ToolbarNotificationsPopoverView(
        groups: groups,
        onSelectNotification: { worktreeID, notification in
          onSelectNotification(worktreeID, notification)
          isPresented = false
        },
        onDismissAll: {
          onDismissAll()
          isPresented = false
        },
      )
    }
    .onChange(of: groups) { _, newValue in
      if newValue.isEmpty {
        isPresented = false
      }
    }
  }
}
