import ComposableArchitecture
import SupacodeSettingsShared
import SwiftUI

public struct RepositorySettingsView: View {
  @Bindable var store: StoreOf<RepositorySettingsFeature>

  public init(store: StoreOf<RepositorySettingsFeature>) {
    self.store = store
  }

  public var body: some View {
    let baseRefOptions =
      store.branchOptions.isEmpty ? [store.defaultWorktreeBaseRef] : store.branchOptions
    let settings = $store.settings
    let worktreeBaseDirectoryPath = Binding(
      get: { settings.worktreeBaseDirectoryPath.wrappedValue ?? "" },
      set: { settings.worktreeBaseDirectoryPath.wrappedValue = $0 },
    )
    let exampleWorktreePath = store.exampleWorktreePath
    Form {
      Section {
        if store.isBranchDataLoaded {
          Picker(selection: $store.settings.worktreeBaseRef) {
            Text("자동 \(Text(store.defaultWorktreeBaseRef).foregroundStyle(.secondary))")
              .tag(String?.none)
            ForEach(baseRefOptions, id: \.self) { ref in
              Text(ref).tag(Optional(ref))
            }
          } label: {
            Text("기준 브랜치")
            Text("이 참조에서 새 워크트리 브랜치를 생성합니다.")
          }
        } else {
          LabeledContent {
            ProgressView()
              .controlSize(.small)
          } label: {
            Text("기준 브랜치")
            Text("이 참조에서 새 워크트리 브랜치를 생성합니다.")
          }
        }
      }
      Section {
        Picker(selection: settings.copyIgnoredOnWorktreeCreate) {
          Text("전역 \(Text(store.globalCopyIgnoredOnWorktreeCreate ? "예" : "아니요").foregroundStyle(.secondary))")
            .tag(Bool?.none)
          Text("예").tag(Bool?.some(true))
          Text("아니요").tag(Bool?.some(false))
        } label: {
          Text("새 워크트리에 무시된 파일 복사")
          Text("메인 워크트리에서 gitignore된 파일을 복사합니다.")
        }
        .disabled(store.isBareRepository)
        Picker(selection: settings.copyUntrackedOnWorktreeCreate) {
          Text("전역 \(Text(store.globalCopyUntrackedOnWorktreeCreate ? "예" : "아니요").foregroundStyle(.secondary))")
            .tag(Bool?.none)
          Text("예").tag(Bool?.some(true))
          Text("아니요").tag(Bool?.some(false))
        } label: {
          Text("새 워크트리에 추적되지 않는 파일 복사")
          Text("메인 워크트리에서 추적되지 않는 파일을 복사합니다.")
        }
        .disabled(store.isBareRepository)
        if store.isBareRepository {
          Text("bare 저장소에서는 복사 플래그가 무시됩니다.")
            .font(.footnote)
            .foregroundStyle(.tertiary)
        }
        TextField(
          text: worktreeBaseDirectoryPath,
          prompt: Text(
            SupacodePaths.worktreeBaseDirectory(
              for: store.rootURL,
              globalDefaultPath: store.globalDefaultWorktreeBaseDirectoryPath,
              repositoryOverridePath: nil,
            ).path(percentEncoded: false)
          ),
        ) {
          Text("기본 디렉터리").monospaced(false)
          Text("새 워크트리의 상위 경로입니다.").monospaced(false)
        }.monospaced()
      } header: {
        Text("워크트리")
      } footer: {
        Text("예: `\(exampleWorktreePath)`")
      }
      Section("풀 리퀘스트") {
        Picker(selection: settings.pullRequestMergeStrategy) {
          Text("전역 \(Text(store.globalPullRequestMergeStrategy.title).foregroundStyle(.secondary))")
            .tag(PullRequestMergeStrategy?.none)
          ForEach(PullRequestMergeStrategy.allCases) { strategy in
            Text(strategy.title)
              .tag(PullRequestMergeStrategy?.some(strategy))
          }
        } label: {
          Text("병합 전략")
          Text("커맨드 팔레트에서 PR 병합 시 사용됩니다.")
        }
      }
      Section("환경 변수") {
        ScriptEnvironmentRow(
          name: "SUPACODE_WORKTREE_PATH",
          description: "활성 워크트리 경로.",
        )
        ScriptEnvironmentRow(
          name: "SUPACODE_ROOT_PATH",
          description: "저장소 루트 경로.",
        )
      }
    }
    .formStyle(.grouped)
    .padding(.top, -20)
    .padding(.leading, -8)
    .padding(.trailing, -6)
    .task {
      store.send(.task)
    }
  }
}

// MARK: - Environment row.

private struct ScriptEnvironmentRow: View {
  let name: String
  let description: String

  var body: some View {
    LabeledContent {
      Button {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(name, forType: .string)
      } label: {
        Image(systemName: "doc.on.doc")
          .accessibilityLabel("변수 키 복사")
      }
      .buttonStyle(.borderless)
      .help("변수 키를 복사합니다.")
    } label: {
      Text(name).monospaced()
      Text(description)
    }
  }
}
