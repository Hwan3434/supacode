import ComposableArchitecture
import SupacodeSettingsShared
import SwiftUI

public struct WorktreeSettingsView: View {
  @Bindable var store: StoreOf<SettingsFeature>

  public init(store: StoreOf<SettingsFeature>) {
    self.store = store
  }

  public var body: some View {
    let defaultPath = SupacodePaths.reposDirectory.path(percentEncoded: false)
    let resolvedBase =
      SupacodePaths.normalizedWorktreeBaseDirectoryPath(
        store.defaultWorktreeBaseDirectoryPath
      ) ?? defaultPath
    let examplePath = "\(resolvedBase)*/**/*"
    Form {
      Section {
        Toggle(isOn: $store.promptForWorktreeCreation) {
          Text("생성 시 브랜치 이름 프롬프트 표시")
          Text("워크트리를 생성하기 전에 브랜치 이름과 기준 참조를 선택합니다.")
        }
        Toggle(isOn: $store.fetchOriginBeforeWorktreeCreation) {
          Text("워크트리 생성 전 원격 브랜치 가져오기")
          Text("기준 브랜치가 최신인지 확인하기 위해 git fetch를 실행합니다.")
        }
        TextField(
          text: $store.defaultWorktreeBaseDirectoryPath,
          prompt: Text(defaultPath),
        ) {
          Text("기본 디렉터리").monospaced(false)
          Text("새 워크트리의 상위 경로입니다.").monospaced(false)
        }.monospaced()
      } footer: {
        Text("예: `\(examplePath)`")
      }
      Section {
        Toggle(isOn: $store.copyIgnoredOnWorktreeCreate) {
          Text("새 워크트리에 무시된 파일 복사")
          Text("메인 워크트리에서 gitignore된 파일을 복사합니다.")
        }
        Toggle(isOn: $store.copyUntrackedOnWorktreeCreate) {
          Text("새 워크트리에 추적되지 않는 파일 복사")
          Text("메인 워크트리에서 추적되지 않는 파일을 복사합니다.")
        }
      }
      Section("정리") {
        Picker(
          "보관된 워크트리 자동 삭제",
          selection: Binding(
            get: { store.autoDeleteArchivedWorktreesAfterDays },
            set: { store.send(.requestAutoDeleteDaysChange($0)) },
          ),
        ) {
          Text("안 함").tag(AutoDeletePeriod?.none)
          ForEach(AutoDeletePeriod.allCases, id: \.rawValue) { period in
            Text(period.label).tag(AutoDeletePeriod?.some(period))
          }
        }
      }
      Section {
        Toggle(isOn: $store.deleteBranchOnDeleteWorktree) {
          Text("워크트리와 함께 로컬 브랜치 삭제")
          Text("워크트리와 함께 로컬 브랜치를 제거합니다. 원격 브랜치는 GitHub에서 삭제해야 합니다.")
          Text("커밋되지 않은 변경 사항은 손실됩니다.").foregroundStyle(.red)
        }
      }
    }
    .formStyle(.grouped)
    .padding(.top, -20)
    .padding(.leading, -8)
    .padding(.trailing, -6)
    .navigationTitle("워크트리")
  }
}
