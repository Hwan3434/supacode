import ComposableArchitecture
import SupacodeSettingsFeature
import SupacodeSettingsShared
import SwiftUI

struct WorktreeCreationPromptView: View {
  @Bindable var store: StoreOf<WorktreeCreationPromptFeature>
  @FocusState private var isBranchFieldFocused: Bool

  var body: some View {
    Form {
      Section {
        TextField("브랜치 이름", text: $store.branchName)
          .focused($isBranchFieldFocused)
          .onSubmit {
            store.send(.createButtonTapped)
          }
      } header: {
        // `NavigationStack` with title and subtitle is bugged inside
        // sheets in macOS 26.*, and this is a nice enough fallback.
        Text("새 워크트리")
        Text("`\(store.repositoryName)`에 브랜치를 생성합니다.")
      } footer: {
        WorktreeCreationFooter(store: store)
      }
      .headerProminence(.increased)

      Section {
        WorktreeBaseRefField(store: store)

        Toggle(isOn: $store.fetchOrigin) {
          Text("원격 브랜치 가져오기")
          Text(
            "워크트리를 생성하기 전에 기준 브랜치가 최신인지 확인하기 위해 `git fetch`를 실행합니다."
          )
        }
        .disabled(store.isSelectedBaseRefLocal)
      }

      WorktreeAppearanceSection(store: store)

      WorktreeOptionsSection(store: store)
    }
    .formStyle(.grouped)
    .scrollBounceBehavior(.basedOnSize)
    .safeAreaInset(edge: .bottom, spacing: 0) {
      HStack {
        if store.isValidating {
          ProgressView()
            .controlSize(.small)
        }
        Spacer()
        Button("취소") {
          store.send(.cancelButtonTapped)
        }
        .keyboardShortcut(.cancelAction)
        .help("취소 (Esc)")
        Button("생성") {
          store.send(.createButtonTapped)
        }
        .keyboardShortcut(.defaultAction)
        .help("생성 (↩)")
        .disabled(store.isValidating)
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 20)
    }
    .frame(minWidth: 420)
    .task { isBranchFieldFocused = true }
    .dismissSystemColorPanelOnDisappear()
  }
}

private struct WorktreeAppearanceSection: View {
  @Bindable var store: StoreOf<WorktreeCreationPromptFeature>

  var body: some View {
    Section("모양", isExpanded: $store.showAppearanceOptions) {
      TextField("제목", text: $store.title, prompt: Text(store.worktreeNamePlaceholder))
      LabeledContent("색상") {
        ColorSwatchRow(color: $store.color)
      }
    }
  }
}

private struct WorktreeOptionsSection: View {
  @Bindable var store: StoreOf<WorktreeCreationPromptFeature>

  var body: some View {
    Section("고급", isExpanded: $store.showAdvancedOptions) {
      // Title-string fields so tapping the label focuses the field, matching
      // the branch-name field above.
      TextField("워크트리 이름", text: $store.worktreeNameOverride, prompt: Text(store.worktreeNamePlaceholder))
      TextField("상위 폴더", text: $store.worktreePathOverride, prompt: Text(store.defaultWorktreeBaseDirectory))
    }
  }
}

private struct WorktreeCreationFooter: View {
  let store: StoreOf<WorktreeCreationPromptFeature>

  var body: some View {
    if let message = store.validationMessage ?? store.worktreeNameValidationError, !message.isEmpty {
      Text(message)
        .foregroundStyle(.red)
    } else {
      Text(store.resolvedWorktreeLocationPreview)
        .monospaced()
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

private struct WorktreeBaseRefField: View {
  @Bindable var store: StoreOf<WorktreeCreationPromptFeature>

  var body: some View {
    LabeledContent {
      HStack(spacing: 8) {
        if store.isLoadingBranches {
          ProgressView()
            .controlSize(.small)
        }
        Menu {
          WorktreeBaseRefMenuContent(store: store)
        } label: {
          Text(store.baseRefMenuLabel)
            .lineLimit(1)
            .truncationMode(.middle)
        }
      }
    } label: {
      Text("기준 브랜치")
      Text("새 워크트리를 생성할 기준 브랜치 또는 참조입니다.")
    }
  }
}

private struct WorktreeBaseRefMenuContent: View {
  @Bindable var store: StoreOf<WorktreeCreationPromptFeature>

  var body: some View {
    WorktreeBaseRefMenuItem(
      store: store,
      ref: nil,
      label: store.automaticBaseRef.isEmpty
        ? Text("자동")
        : Text(store.automaticBaseRef) + Text(" 자동").foregroundStyle(.secondary)
    )
    if let defaultBranch = store.defaultBranch {
      // Tagged "Local" to distinguish it from the remote-tracking Auto ref above.
      WorktreeBaseRefMenuItem(
        store: store,
        ref: defaultBranch,
        label: Text(defaultBranch) + Text(" 로컬").foregroundStyle(.secondary)
      )
    }

    Divider()

    if let branchMenu = store.branchMenu {
      if !branchMenu.localBranches.isEmpty {
        Menu("로컬") {
          ForEach(branchMenu.localBranches) { node in
            WorktreeBranchNodeMenu(store: store, node: node)
          }
        }
      }
      ForEach(branchMenu.remotes) { remote in
        WorktreeRemoteBranchMenu(store: store, remote: remote)
      }
    } else {
      Text("브랜치 불러오는 중…")
    }
  }
}

private struct WorktreeRemoteBranchMenu: View {
  @Bindable var store: StoreOf<WorktreeCreationPromptFeature>
  let remote: BaseRefBranchMenu.Remote

  var body: some View {
    Menu {
      ForEach(remote.branches) { node in
        WorktreeBranchNodeMenu(store: store, node: node)
      }
    } label: {
      Text(remote.name) + Text(" 원격").foregroundStyle(.secondary)
    }
  }
}

private struct WorktreeBranchNodeMenu: View {
  @Bindable var store: StoreOf<WorktreeCreationPromptFeature>
  let node: BranchMenuNode

  var body: some View {
    if node.children.isEmpty {
      WorktreeBaseRefMenuItem(store: store, ref: node.ref, label: Text(node.name))
    } else {
      Menu(node.name) {
        // A namespace segment that is also a branch (rare) stays selectable.
        if let ref = node.ref {
          WorktreeBaseRefMenuItem(store: store, ref: ref, label: Text(node.name))
        }
        ForEach(node.children) { child in
          WorktreeBranchNodeMenu(store: store, node: child)
        }
      }
    }
  }
}

private struct WorktreeBaseRefMenuItem: View {
  @Bindable var store: StoreOf<WorktreeCreationPromptFeature>
  let ref: String?
  let label: Text

  var body: some View {
    Button {
      store.send(.baseRefSelected(ref))
    } label: {
      if store.selectedBaseRef == ref {
        Label {
          label
        } icon: {
          Image(systemName: "checkmark")
            .accessibilityHidden(true)
        }
      } else {
        label
      }
    }
  }
}
