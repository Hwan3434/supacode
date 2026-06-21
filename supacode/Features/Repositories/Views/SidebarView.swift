import ComposableArchitecture
import Sharing
import SupacodeSettingsShared
import SwiftUI

struct SidebarView: View {
  @Bindable var store: StoreOf<RepositoriesFeature>
  let terminalManager: WorktreeTerminalManager
  @Shared(.settingsFile) private var settingsFile

  var body: some View {
    let state = store.state
    let confirmAlert = state.confirmWorktreeAlert
    // Reads only the selected rows' minimal fields (not every leaf's full state
    // via `orderedSidebarItems()`), so this render-path body isn't invalidated
    // by unrelated per-leaf ticks. See `sidebarSelectionActionTargets`.
    let actionTargets = state.sidebarSelectionActionTargets
    let archiveTargets = actionTargets.archive
    let deleteTargets = actionTargets.delete
    let openRepo = AppShortcuts.openRepository.effective(from: settingsFile.global.shortcutOverrides)

    return SidebarListView(
      store: store,
      terminalManager: terminalManager,
    )
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button {
          store.send(.setOpenPanelPresented(true))
        } label: {
          Label {
            Text("Add…")
          } icon: {
            Image(systemName: "folder.badge.plus")
              .offset(y: -1)
              .accessibilityHidden(true)
          }
        }
        .labelStyle(.iconOnly)
        .help("Add Repository or Folder (\(openRepo?.display ?? "none"))")
      }
    }
    .focusedSceneAction(
      \.confirmWorktreeAction,
      enabled: confirmAlert != nil,
      token: confirmAlert,
    ) {
      if let alert = confirmAlert {
        store.send(.alert(.presented(alert)))
      }
    }
    .focusedAction(
      \.archiveWorktreeAction,
      enabled: !archiveTargets.isEmpty,
      token: archiveTargets,
    ) {
      if archiveTargets.count == 1, let target = archiveTargets.first {
        store.send(.requestArchiveWorktree(target.worktreeID, target.repositoryID))
      } else {
        store.send(.requestArchiveWorktrees(archiveTargets))
      }
    }
    .focusedAction(
      \.deleteWorktreeAction,
      enabled: !deleteTargets.isEmpty,
      token: deleteTargets,
    ) {
      store.send(.requestDeleteSidebarItems(deleteTargets))
    }
  }
}
