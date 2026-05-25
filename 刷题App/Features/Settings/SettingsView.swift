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
                    LabeledContent {
                        Text(appState.hasBuiltInAPIKey ? "已启用" : "未配置")
                    } label: {
                        Label("内置 API", systemImage: "key.radiowaves.forward")
                    }
                } header: {
                    Text("DeepSeek")
                } footer: {
                    Text("默认优先使用内置 API；也可以在这里填写自定义 Key 覆盖。题库只保存材料，练习时再按所选题型出题。")
                }

                Section {
                    LabeledContent {
                        Text("deepseek-v4-flash")
                    } label: {
                        Label("默认模型", systemImage: "cpu")
                    }
                    LabeledContent {
                        Text("api.deepseek.com")
                    } label: {
                        Label("接口地址", systemImage: "network")
                    }
                } header: {
                    Text("模型")
                }

                Section {
                    LabeledContent {
                        Text("iOS 17+")
                    } label: {
                        Label("目标平台", systemImage: "iphone")
                    }
                    LabeledContent {
                        Text("SwiftData")
                    } label: {
                        Label("本地存储", systemImage: "internaldrive")
                    }
                } header: {
                    Text("关于")
                }

                Section {
                    Stepper(value: $appState.mistakeAutoDeleteThreshold, in: 1...10) {
                        LabeledContent {
                            Text("\(appState.mistakeAutoDeleteThreshold) 次")
                        } label: {
                            Label("连对自动删除", systemImage: "checkmark.seal")
                        }
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
