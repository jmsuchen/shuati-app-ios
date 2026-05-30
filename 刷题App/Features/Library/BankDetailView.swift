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
                HStack(alignment: .top, spacing: 12) {
                    DetailIcon(systemImage: "doc.text.magnifyingglass", color: .blue)
                    VStack(alignment: .leading, spacing: 12) {
                        Label(bank.sourceFileName, systemImage: "paperclip")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(bank.sourcePreview)
                            .font(.body)
                            .lineLimit(8)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("原文预览")
            }

            Section {
                Text(markdownPreview)
                    .font(.body)
                    .textSelection(.enabled)
            } header: {
                Label("Markdown 显示", systemImage: "text.page")
            }

            Section {
                ForEach(bank.questions) { question in
                    HStack(alignment: .top, spacing: 12) {
                        DetailIcon(systemImage: "text.badge.checkmark", color: .green)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(question.sourceText)
                                .font(.body)
                            HStack(spacing: 12) {
                                Label("练习时生成题型", systemImage: "wand.and.stars")
                                if !question.knowledgeTags.isEmpty {
                                    Label(question.knowledgeTags.joined(separator: " / "), systemImage: "tag")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
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

    private var markdownPreview: AttributedString {
        let markdown = bank.sourceMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = markdown.isEmpty ? bank.sourcePreview : markdown
        return (try? AttributedString(markdown: source)) ?? AttributedString(source)
    }
}

private struct DetailIcon: View {
    let systemImage: String
    let color: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.headline)
            .foregroundStyle(color)
            .frame(width: 34, height: 34)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}
