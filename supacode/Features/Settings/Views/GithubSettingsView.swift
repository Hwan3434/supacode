import ComposableArchitecture
import SupacodeSettingsFeature
import SupacodeSettingsShared
import SwiftUI

@MainActor @Observable
final class GithubSettingsViewModel {
  enum State: Equatable {
    case loading
    case unavailable
    case outdated
    case notAuthenticated
    case authenticated(username: String, host: String)
    case error(String)
  }

  var state: State = .loading

  @ObservationIgnored
  @Dependency(GithubIntegrationClient.self) private var githubIntegration

  @ObservationIgnored
  @Dependency(GithubCLIClient.self) private var githubCLI

  func load() async {
    state = .loading
    let isAvailable = await githubIntegration.isAvailable()
    guard isAvailable else {
      state = .unavailable
      return
    }

    do {
      if let status = try await githubCLI.authStatus() {
        state = .authenticated(username: status.username, host: status.host)
      } else {
        state = .notAuthenticated
      }
    } catch let error as GithubCLIError {
      switch error {
      case .outdated:
        state = .outdated
      case .unavailable:
        state = .unavailable
      case .gatewayTimeout:
        state = .error(error.localizedDescription ?? "GitHub returned a gateway timeout.")
      case .commandFailed(let message):
        state = .error(message)
      }
    } catch {
      state = .error(error.localizedDescription)
    }
  }
}

struct GithubSettingsView: View {
  @Bindable var store: StoreOf<SettingsFeature>
  @State private var viewModel = GithubSettingsViewModel()

  var body: some View {
    Form {
      Section {
        Toggle(isOn: $store.githubIntegrationEnabled) {
          Text("GitHub 연동 활성화")
          Text("커맨드 팔레트에서 풀 리퀘스트 확인 및 병합 작업을 수행합니다.")
        }
      }
      Section("GitHub CLI") {
        switch viewModel.state {
        case .loading:
          LabeledContent("GitHub CLI 확인 중…") {
            ProgressView().controlSize(.small)
          }

        case .unavailable:
          Label {
            VStack(alignment: .leading, spacing: 2) {
              Text("GitHub CLI를 찾을 수 없음")
              Text("`gh`를 설치하여 풀 리퀘스트 확인을 활성화하십시오.")
                .foregroundStyle(.secondary)
                .font(.callout)
            }
          } icon: {
            Image(systemName: "xmark.circle")
              .foregroundStyle(.red)
              .accessibilityHidden(true)
          }

        case .notAuthenticated:
          Label {
            VStack(alignment: .leading, spacing: 2) {
              Text("인증되지 않음")
              Text("터미널에서 `gh auth login`을 실행하여 인증하십시오.")
                .foregroundStyle(.secondary)
                .font(.callout)
            }
          } icon: {
            Image(systemName: "exclamationmark.triangle")
              .foregroundStyle(.orange)
              .accessibilityHidden(true)
          }

        case .outdated:
          Label {
            VStack(alignment: .leading, spacing: 2) {
              Text("GitHub CLI 구버전")
              Text("모든 기능을 지원하려면 최신 버전으로 업데이트하십시오.")
                .foregroundStyle(.secondary)
                .font(.callout)
            }
          } icon: {
            Image(systemName: "exclamationmark.triangle")
              .foregroundStyle(.orange)
              .accessibilityHidden(true)
          }

        case .authenticated(let username, let host):
          LabeledContent("로그인된 계정") {
            Text(username)
          }
          LabeledContent("호스트") {
            Text(host)
          }

        case .error(let message):
          Label {
            VStack(alignment: .leading, spacing: 2) {
              Text("상태 확인 오류")
              Text(message)
                .foregroundStyle(.secondary)
                .font(.callout)
            }
          } icon: {
            Image(systemName: "exclamationmark.triangle")
              .foregroundStyle(.red)
              .accessibilityHidden(true)
          }
        }

        switch viewModel.state {
        case .unavailable:
          Button("GitHub CLI 다운로드") {
            NSWorkspace.shared.open(URL(string: "https://cli.github.com")!)
          }
        case .outdated:
          Button("GitHub CLI 업데이트") {
            NSWorkspace.shared.open(URL(string: "https://cli.github.com")!)
          }
        default:
          EmptyView()
        }
      }
      Section("풀 리퀘스트") {
        Picker(selection: $store.pullRequestMergeStrategy) {
          ForEach(PullRequestMergeStrategy.allCases) { strategy in
            Text(strategy.title)
              .tag(strategy)
          }
        } label: {
          Text("병합 전략")
          Text("커맨드 팔레트에서 PR 병합 시 기본 전략입니다.")
        }
        Picker(selection: $store.mergedWorktreeAction) {
          Text("아무것도 하지 않음").tag(MergedWorktreeAction?.none)
          ForEach(MergedWorktreeAction.allCases) { action in
            Text(action.title).tag(MergedWorktreeAction?.some(action))
          }
        } label: {
          Text("풀 리퀘스트가 병합될 때")
          switch store.mergedWorktreeAction {
          case .archive:
            Text("풀 리퀘스트가 병합되면 워크트리를 보관합니다.")
          case .delete:
            Text("워크트리 설정의 \"워크트리와 함께 로컬 브랜치 삭제\" 옵션을 따릅니다.")
          case nil:
            EmptyView()
          }
        }
      }
    }
    .formStyle(.grouped)
    .padding(.top, -20)
    .padding(.leading, -8)
    .padding(.trailing, -6)
    .navigationTitle("GitHub")
    .task {
      await viewModel.load()
    }
    .onChange(of: store.githubIntegrationEnabled) { _, _ in
      Task {
        await viewModel.load()
      }
    }
  }
}
