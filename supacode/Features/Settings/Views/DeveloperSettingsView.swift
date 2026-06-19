import ComposableArchitecture
import SupacodeSettingsFeature
import SupacodeSettingsShared
import SwiftUI

struct DeveloperSettingsView: View {
  @Bindable var store: StoreOf<SettingsFeature>

  var body: some View {
    Form {
      Section {
        DeeplinkRow()
        CLIInstallRow(store: store)
      } footer: {
        Text("`/usr/local/bin`에 `supacode`의 심볼릭 링크를 생성합니다. 이는 앱 터미널에서 `supacode`를 실행하는 데 필수적이지는 않습니다.")
      }
      Section {
        Toggle(isOn: $store.richAgentNotificationsEnabled) {
          Text("풍부한 알림")
          Text("종료 및 알림 훅이 일반 알림 대신 에이전트의 마지막 메시지를 전달합니다.")
        }
        Toggle(isOn: $store.agentPresenceBadgesEnabled) {
          Text("에이전트 배지")
          Text("코딩 에이전트가 해당 화면에서 실행 중일 때 사이드바 및 탭에 아이콘을 표시합니다.")
        }
      } header: {
        Text("코딩 에이전트")
      } footer: {
        Text("이 기능들은 아래의 에이전트별 통합 설치가 필요합니다.")
      }
      Section {
        ForEach(SkillAgent.allCases, id: \.self) { agent in
          AgentIntegrationRow(
            agent: agent,
            state: store.agentIntegrationStates[agent] ?? .checking,
            installAction: { store.send(.agentIntegrationInstallTapped(agent)) },
            uninstallAction: { store.send(.agentIntegrationUninstallTapped(agent)) }
          )
        }
      }
      Section {
        Toggle(isOn: $store.autoUpdateAgentIntegrationsEnabled) {
          Text("에이전트 연동 자동 업데이트")
          Text(
            "Supacode가 포그라운드로 올 때 구버전 연동이 보고된 에이전트의 훅을 다시 설치합니다.")
        }
        .help("Supacode 활성화 시 구버전 에이전트 연동에 표준 훅 레이아웃을 백그라운드에서 다시 적용합니다.")
      }
    }
    .formStyle(.grouped)
    .padding(.top, -20)
    .padding(.leading, -8)
    .padding(.trailing, -6)
    .navigationTitle("개발자")
  }
}

// MARK: - CLI install + Deeplink rows.

private struct DeeplinkRow: View {
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    LabeledContent {
    } label: {
      Text("딥링크")
      Text("딥링크 참조 \u{2197}")
        .foregroundStyle(.tint)
        .contentShape(.rect)
        .accessibilityAddTraits(.isButton)
        .onTapGesture { openWindow(id: WindowID.deeplinkReference) }
    }
  }
}

private struct CLIInstallRow: View {
  @Environment(\.openWindow) private var openWindow
  let store: StoreOf<SettingsFeature>

  var body: some View {
    LabeledContent {
      switch store.cliInstallState {
      case .checking:
        ProgressView()
      case .installed:
        ControlGroup {
          Label("설치됨", systemImage: "checkmark")
          Button("제거", role: .destructive) { store.send(.cliUninstallTapped) }
        }
      case .notInstalled, .failed:
        Button("설치") { store.send(.cliInstallTapped) }
      case .installing:
        Button("설치 중\u{2026}") {}
          .disabled(true)
      case .uninstalling:
        Button("제거 중\u{2026}") {}
          .disabled(true)
      }
    } label: {
      Text("커맨드 라인 도구")
      Text("CLI 참조 \u{2197}")
        .foregroundStyle(.tint)
        .contentShape(.rect)
        .accessibilityAddTraits(.isButton)
        .onTapGesture { openWindow(id: WindowID.cliReference) }
      if let message = store.cliInstallState.errorMessage {
        Text(message).foregroundStyle(.red)
      }
    }
  }
}

// MARK: - Agent integration row.

private struct AgentIntegrationRow: View {
  let agent: SkillAgent
  let state: AgentIntegrationRowState
  let installAction: () -> Void
  let uninstallAction: () -> Void

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Image(agent.assetName)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 18, height: 18)
        .foregroundStyle(.primary)
        // Image has no native baseline; nudge so its visual center sits near the title baseline.
        .alignmentGuide(.firstTextBaseline) { dimension in dimension[.bottom] - 5 }
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(agent.displayName)
        Text(agent.integrationSubtitle)
          .font(.subheadline)
          .foregroundStyle(.secondary)
        if let message = state.errorMessage {
          Text(message).font(.subheadline).foregroundStyle(.red)
        }
      }
      Spacer()
      trailingControl
    }
  }

  @ViewBuilder
  private var trailingControl: some View {
    switch state {
    case .checking:
      ProgressView()
    case .ready(.installed):
      ControlGroup {
        Label("설치됨", systemImage: "checkmark")
        Button("제거", role: .destructive, action: uninstallAction)
      }
    case .ready(.outdated):
      ControlGroup {
        Button("업데이트", action: installAction)
        Button("제거", role: .destructive, action: uninstallAction)
      }
    case .ready(.notInstalled), .failed:
      Button("설치", action: installAction)
    case .installing:
      Button("설치 중\u{2026}") {}
        .disabled(true)
    case .uninstalling:
      Button("제거 중\u{2026}") {}
        .disabled(true)
    }
  }
}

// MARK: - Per-agent integration subtitle.

extension SkillAgent {
  fileprivate var integrationSubtitle: LocalizedStringKey {
    switch self {
    case .claude: "`~/.claude/settings.json`의 훅 및 `~/.claude/skills/`의 스킬."
    case .codex:
      """
      `~/.codex/hooks.json`의 훅 및 `~/.codex/skills/`의 스킬. 설치 후 Codex에서 훅을 신뢰하십시오; \
      첫 메시지를 보내면 배지가 나타납니다.
      """
    case .kiro: "`~/.kiro/agents/`의 훅 및 `~/.kiro/skills/`의 스킬."
    case .pi: "`~/.pi/agent/extensions/`의 익스텐션 및 `~/.pi/agent/skills/`의 스킬."
    }
  }
}
