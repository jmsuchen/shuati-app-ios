import SwiftData
import SwiftUI

struct BankDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var isConfirmingDelete = false

    let bank: QuestionBank

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(bank.sourceFileName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(bank.sourcePreview)
                        .font(.body)
                        .lineLimit(8)
                }
                .padding(.vertical, 4)
            } header: {
                Text("原文预览")
            }

            Section {
                ForEach(bank.questions) { question in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(question.sourceText)
                            .font(.body)
                        HStack {
                            Text("练习时生成题型")
                            Text(question.knowledgeTags.joined(separator: " / "))
                        }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("识别内容")
            }
        }
        .navigationTitle(bank.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    appState.activePracticeBank = bank
                } label: {
                    Label("开始练习", systemImage: "play.fill")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
        }
        .confirmationDialog("删除题库？", isPresented: $isConfirmingDelete) {
            Button("删除", role: .destructive) {
                PracticeDraftStore.delete(bankID: bank.id)
                if appState.activePracticeBank?.id == bank.id {
                    appState.activePracticeBank = nil
                }
                modelContext.delete(bank)
                try? modelContext.save()
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("题库、题目和未完成练习进度都会被删除。")
        }
    }
}
