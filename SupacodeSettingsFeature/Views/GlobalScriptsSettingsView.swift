import ComposableArchitecture
import SupacodeSettingsShared
import SwiftUI

/// Settings sub-section for managing scripts shared across every repository.
public struct GlobalScriptsSettingsView: View {
  @Bindable var store: StoreOf<SettingsFeature>

  public init(store: StoreOf<SettingsFeature>) {
    self.store = store
  }

  public var body: some View {
    Group {
      if store.globalScripts.isEmpty {
        ContentUnavailableView(
          "전역 스크립트 없음",
          systemImage: "terminal",
          description: Text("스크립트를 추가하여 모든 저장소의 도구 모음과 커맨드 팔레트에서 사용할 수 있게 하세요."),
        )
      } else {
        scriptsForm
      }
    }
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button {
          store.send(.addGlobalScript)
        } label: {
          Image(systemName: "plus")
            .accessibilityLabel("전역 스크립트 추가")
        }
        .help("새 전역 스크립트를 추가합니다.")
      }
    }
    .dismissSystemColorPanelOnDisappear()
  }

  private var scriptsForm: some View {
    ScrollViewReader { proxy in
      Form {
        Section(
          footer: Text("전역 스크립트는 모든 저장소의 도구 모음과 커맨드 팔레트에서 사용할 수 있습니다.")
        ) {}

        ForEach($store.globalScripts) { $script in
          Section {
            TextField("이름", text: $script.name)
            LabeledContent("색상") {
              ColorSwatchRow(color: $script.tintColor)
            }
            ScriptCommandEditor(text: $script.command, label: script.displayName)
            Button("스크립트 제거…", role: .destructive) {
              store.send(.removeGlobalScript(script.id))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
            .help("이 스크립트를 제거합니다.")
          } header: {
            Label {
              Text("\(script.displayName) 스크립트")
                .font(.body)
                .bold()
            } icon: {
              Image(systemName: script.resolvedSystemImage)
                .foregroundStyle(script.resolvedTintColor.color)
                .accessibilityHidden(true)
            }
            .labelStyle(.verticallyCentered)
          }
          .id(script.id)
        }
      }
      .formStyle(.grouped)
      .padding(.top, -20)
      .padding(.leading, -8)
      .padding(.trailing, -6)
      // Scroll the newly appended section into view; otherwise an add gives no
      // visible feedback when the form is already taller than the window.
      .onChange(of: store.globalScripts.count) { oldCount, newCount in
        guard newCount > oldCount, let last = store.globalScripts.last else { return }
        withAnimation { proxy.scrollTo(last.id, anchor: .top) }
      }
    }
  }
}
