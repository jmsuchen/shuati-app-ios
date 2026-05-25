import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var apiKeyDraft = ""
    @State private var saveMessage: String?

    var body: some View {
        @Bindable var appState = appState

        NavigationStack {
            Form {
                Section {
                    SecureField("API Key", text: $apiKeyDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Toggle("优先使用 DeepSeek 生成", isOn: $appState.useRemoteGeneration)
                        .disabled(appState.effectiveAPIKey.isEmpty && apiKeyDraft.isEmpty)

                    Button {
                        appState.apiKey = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        appState.useRemoteGeneration = !appState.effectiveAPIKey.isEmpty
                        saveMessage = appState.apiKey.isEmpty ? "已使用内置 API 或本地生成" : "自定义 API Key 已保存"
                    } label: {
                        Label("保存设置", systemImage: "key")
                    }
                    LabeledContent("内置 API", value: appState.hasBuiltInAPIKey ? "已启用" : "未配置")
                } header: {
                    Text("DeepSeek")
                } footer: {
                    Text("默认优先使用内置 API；也可以在这里填写自定义 Key 覆盖。没有可用 API 时会使用本地规则识别题目。")
                }

                Section {
                    LabeledContent("默认模型", value: "deepseek-v4-flash")
                    LabeledContent("接口地址", value: "api.deepseek.com")
                } header: {
                    Text("模型")
                }

                Section {
                    LabeledContent("目标平台", value: "iOS 17+")
                    LabeledContent("本地存储", value: "SwiftData")
                } header: {
                    Text("关于")
                }

                Section {
                    Stepper(value: $appState.mistakeAutoDeleteThreshold, in: 1...10) {
                        LabeledContent("连对自动删除", value: "\(appState.mistakeAutoDeleteThreshold) 次")
                    }
                } header: {
                    Text("错题")
                } footer: {
                    Text("错题复练时，同一道错题连续答对达到该次数后，会自动从错题本移除。")
                }
            }
            .navigationTitle("设置")
            .onAppear {
                apiKeyDraft = appState.apiKey
            }
            .alert("设置", isPresented: Binding(
                get: { saveMessage != nil },
                set: { if !$0 { saveMessage = nil } }
            )) {
                Button("好") {
                    saveMessage = nil
                }
            } message: {
                Text(saveMessage ?? "")
            }
        }
    }
}
