import ComposableArchitecture
import SupacodeSettingsShared
import SwiftUI

/// Settings sub-section for managing on-demand and lifecycle scripts.
public struct RepositoryScriptsSettingsView: View {
  @Bindable var store: StoreOf<RepositorySettingsFeature>

  public init(store: StoreOf<RepositorySettingsFeature>) {
    self.store = store
  }

  public var body: some View {
    ScrollViewReader { proxy in
      Form {
        // Setup + Archive scripts are git-only — worktree creation
        // and worktree archival are the triggers and folders have
        // neither. The Delete script stays: it runs before the folder
        // itself is removed from Supacode through the blocking-script
        // pipeline.
        if store.isGitRepository {
          LifecycleScriptSection(
            text: $store.settings.setupScript,
            title: "설정 스크립트",
            subtitle: "워크트리 생성 후 한 번 실행됩니다.",
            icon: "truck.box.badge.clock",
            iconColor: .blue,
            footerExample: "pnpm install",
          )
          LifecycleScriptSection(
            text: $store.settings.archiveScript,
            title: "보관 스크립트",
            subtitle: "워크트리를 보관하기 전에 실행됩니다.",
            icon: "archivebox",
            iconColor: .orange,
            footerExample: "docker compose down",
          )
        }
        LifecycleScriptSection(
          text: $store.settings.deleteScript,
          title: "삭제 스크립트",
          subtitle: store.isGitRepository
            ? "워크트리를 삭제하기 전에 실행됩니다."
            : "이 폴더를 Supacode에서 제거하기 전에 실행됩니다.",
          icon: "trash",
          iconColor: .red,
          footerExample: "docker compose down",
        )

        // User-defined scripts, each in its own section.
        ForEach($store.settings.scripts) { $script in
          Section {
            if script.kind == .custom {
              TextField("이름", text: $script.name)
              LabeledContent("색상") {
                ColorSwatchRow(color: $script.tintColor)
              }
            }
            ScriptCommandEditor(text: $script.command, label: script.displayName)
            Button("스크립트 제거…", role: .destructive) {
              store.send(.removeScript(script.id))
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
              Image(systemName: script.resolvedSystemImage).foregroundStyle(script.resolvedTintColor.color)
                .accessibilityHidden(true)
            }.labelStyle(.verticallyCentered)
          }
          .id(script.id)
        }

      }
      .alert($store.scope(state: \.alert, action: \.alert))
      .formStyle(.grouped)
      .padding(.top, -20)
      .padding(.leading, -8)
      .padding(.trailing, -6)
      // Mirror `GlobalScriptsSettingsView` — scroll the new section into view
      // so an add gives feedback when the form already overflows.
      .onChange(of: store.settings.scripts.count) { oldCount, newCount in
        guard newCount > oldCount, let last = store.settings.scripts.last else { return }
        withAnimation { proxy.scrollTo(last.id, anchor: .top) }
      }
    }
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        let usedKinds = Set(store.settings.scripts.map(\.kind))
        Menu {
          ForEach(ScriptKind.allCases, id: \.self) { kind in
            if kind == .custom || !usedKinds.contains(kind) {
              Button {
                store.send(.addScript(kind))
              } label: {
                Label {
                  Text("\(kind.defaultName) 스크립트")
                } icon: {
                  Image.tintedSymbol(kind.defaultSystemImage, color: kind.defaultTintColor.nsColor)
                }
              }
            }
          }
        } label: {
          Image(systemName: "plus")
            .accessibilityLabel("스크립트 추가")
        }
        .help("새 스크립트를 추가합니다.")
      }
    }
    .dismissSystemColorPanelOnDisappear()
  }
}

/// Reusable section for lifecycle scripts (setup, archive, delete).
private struct LifecycleScriptSection: View {
  @Binding var text: String
  let title: String
  let subtitle: String
  let icon: String
  let iconColor: Color
  let footerExample: String

  var body: some View {
    Section {
      ScriptCommandEditor(text: $text, label: title)
    } header: {
      Label {
        VStack(alignment: .leading, spacing: 0) {
          Text(title)
            .font(.body)
            .bold()
            .lineLimit(1)
          Text(subtitle)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      } icon: {
        Image(systemName: icon).foregroundStyle(iconColor).accessibilityHidden(true)
      }.labelStyle(.verticallyCentered)
    } footer: {
      Text("예: `\(footerExample)`")
    }
  }
}
