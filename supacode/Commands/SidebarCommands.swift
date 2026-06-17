import Sharing
import SupacodeSettingsShared
import SwiftUI

struct SidebarCommands: Commands {
  @FocusedValue(\.toggleLeftSidebarAction) private var toggleLeftSidebarAction
  @FocusedValue(\.revealInSidebarAction) private var revealInSidebarAction
  @Shared(.settingsFile) private var settingsFile
  @Shared(.appStorage("worktreeRowHideSubtitleOnMatch")) private var hideSubtitleOnMatch = true
  @Shared(.sidebarNestWorktreesByBranch) private var nestWorktreesByBranch: Bool
  @Shared(.appStorage("nestedWorktreesOnboardingDismissedAt"))
  private var nestedOnboardingDismissedAt: Date = .distantPast
  @Shared(.sidebarGroupPinnedRows) private var groupPinnedRows: Bool
  @Shared(.sidebarGroupActiveRows) private var groupActiveRows: Bool
  @Shared(.appStorage("highlightRelevantOnboardingDismissedAt"))
  private var highlightOnboardingDismissedAt: Date = .distantPast

  /// Binding that pairs the nesting toggle with a permadismiss of the
  /// onboarding card on transitions to `false`. Lives on the menu command
  /// (which is always present in the menu bar) so the dismiss fires even
  /// when the sidebar column is hidden. Moving it onto the card view's
  /// `.onChange` would silently break for users who toggle while the
  /// sidebar is collapsed.
  private var nestWorktreesToggle: Binding<Bool> {
    Binding(
      get: { nestWorktreesByBranch },
      set: { newValue in
        $nestWorktreesByBranch.withLock { $0 = newValue }
        guard !newValue,
          !NestedWorktreesOnboardingCardView.isDismissed(at: nestedOnboardingDismissedAt)
        else { return }
        $nestedOnboardingDismissedAt.withLock { $0 = .now }
      }
    )
  }

  /// Mirrors `nestWorktreesToggle` so the dismiss also fires when the menu
  /// is used while the sidebar column is hidden (no `SidebarListView` body
  /// is alive to dispatch `.sidebarGroupingTogglesChanged`). The reducer
  /// handler still fires when the sidebar is visible, so this is a
  /// belt-and-suspenders pair, not the only trigger.
  private var groupPinnedRowsToggle: Binding<Bool> {
    Binding(
      get: { groupPinnedRows },
      set: { newValue in
        $groupPinnedRows.withLock { $0 = newValue }
        dismissHighlightOnboardingIfBothOff()
      }
    )
  }

  private var groupActiveRowsToggle: Binding<Bool> {
    Binding(
      get: { groupActiveRows },
      set: { newValue in
        $groupActiveRows.withLock { $0 = newValue }
        dismissHighlightOnboardingIfBothOff()
      }
    )
  }

  private func dismissHighlightOnboardingIfBothOff() {
    guard !groupPinnedRows, !groupActiveRows,
      !HighlightRelevantOnboardingCardView.isDismissed(at: highlightOnboardingDismissedAt)
    else { return }
    $highlightOnboardingDismissedAt.withLock { $0 = .now }
  }

  var body: some Commands {
    let overrides = settingsFile.global.shortcutOverrides
    let toggleLeftSidebar = AppShortcuts.toggleLeftSidebar.effective(from: overrides)
    let revealInSidebar = AppShortcuts.revealInSidebar.effective(from: overrides)
    CommandGroup(replacing: .sidebar) {
      Button("왼쪽 사이드바 토글", systemImage: "sidebar.leading") {
        toggleLeftSidebarAction?()
      }
      .appKeyboardShortcut(toggleLeftSidebar)
      .help("왼쪽 사이드바 토글 (\(toggleLeftSidebar?.display ?? "없음"))")
      .disabled(toggleLeftSidebarAction?.isEnabled != true)
      Button("사이드바에서 보기") {
        revealInSidebarAction?()
      }
      .appKeyboardShortcut(revealInSidebar)
      .help("사이드바에서 보기 (\(revealInSidebar?.display ?? "없음"))")
      .disabled(revealInSidebarAction?.isEnabled != true)
      Section {
        Menu("관련된 사이드바 항목 그룹화") {
          Toggle("고정된 항목 그룹화", isOn: groupPinnedRowsToggle)
          Toggle("활성화된 항목 그룹화", isOn: groupActiveRowsToggle)
        }
        Toggle("브랜치별로 워크트리 중첩", isOn: nestWorktreesToggle)
        Toggle("일치할 때 워크트리 이름 숨기기", isOn: Binding($hideSubtitleOnMatch))
      }
    }
  }
}

private struct ToggleLeftSidebarActionKey: FocusedValueKey {
  typealias Value = FocusedAction<Void>
}

private struct RevealInSidebarActionKey: FocusedValueKey {
  typealias Value = FocusedAction<Void>
}

extension FocusedValues {
  var toggleLeftSidebarAction: FocusedAction<Void>? {
    get { self[ToggleLeftSidebarActionKey.self] }
    set { self[ToggleLeftSidebarActionKey.self] = newValue }
  }

  var revealInSidebarAction: FocusedAction<Void>? {
    get { self[RevealInSidebarActionKey.self] }
    set { self[RevealInSidebarActionKey.self] = newValue }
  }
}
