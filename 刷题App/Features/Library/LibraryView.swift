import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \QuestionBank.createdAt, order: .reverse) private var banks: [QuestionBank]

    @State private var isImporting = false
    @State private var isGenerating = false
    @State private var isShowingManualEntry = false
    @State private var importError: String?

    private let importService = DocumentImportService()
    private let markdownParser = MarkdownParser()

    var body: some View {
        NavigationStack {
            Group {
                if banks.isEmpty {
                    ContentUnavailableView(
                        "还没有题库",
                        systemImage: "tray.and.arrow.down",
                        description: Text("导入文档或手动录入材料后即可识别内容。")
                    )
                } else {
                    List {
                        ForEach(banks) { bank in
                            NavigationLink {
                                BankDetailView(bank: bank)
                            } label: {
                                BankRow(bank: bank)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    deleteBank(bank)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete(perform: deleteBanks)
                    }
                }
            }
            .navigationTitle("题库")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isShowingManualEntry = true
                    } label: {
                        Label("手动录入", systemImage: "square.and.pencil")
                    }
                    .disabled(isGenerating)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isImporting = true
                    } label: {
                        Label("导入", systemImage: "doc.badge.plus")
                    }
                    .disabled(isGenerating)
                }
            }
            .overlay {
                if isGenerating {
                    ProgressView("正在识别材料")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: allowedTypes,
                allowsMultipleSelection: false
            ) { result in
                handleImportResult(result)
            }
            .sheet(isPresented: $isShowingManualEntry) {
                ManualQuestionEntryView { title, text in
                    isShowingManualEntry = false
                    Task {
                        await importManualText(title: title, text: text)
                    }
                }
            }
            .alert("导入失败", isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("好") {
                    importError = nil
                }
            } message: {
                Text(importError ?? "")
            }
        }
    }

    private var allowedTypes: [UTType] {
        [
            .plainText,
            UTType(filenameExtension: "md") ?? .plainText,
            UTType(filenameExtension: "markdown") ?? .plainText,
            UTType(filenameExtension: "docx") ?? .data
        ]
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else {
            if case .failure(let error) = result {
                importError = error.localizedDescription
            }
            return
        }

        Task {
            await importAndGenerate(from: url)
        }
    }

    @MainActor
    private func importAndGenerate(from url: URL) async {
        isGenerating = true
        defer { isGenerating = false }

        do {
            let document = try importService.importDocument(from: url)
            try await saveRecognizedBank(document: document, sourceFileName: url.lastPathComponent)
        } catch {
            importError = error.localizedDescription
        }
    }

    @MainActor
    private func importManualText(title: String, text: String) async {
        isGenerating = true
        defer { isGenerating = false }

        do {
            let document = markdownParser.parse(markdown: text, fallbackTitle: title)
            try await saveRecognizedBank(document: document, sourceFileName: "手动录入")
        } catch {
            importError = error.localizedDescription
        }
    }

    @MainActor
    private func saveRecognizedBank(document: ParsedDocument, sourceFileName: String) async throws {
        let generator = QuestionGenerationService(
            apiKey: appState.effectiveAPIKey,
            preferRemote: appState.useRemoteGeneration
        )
        let generated = try await generator.generateAllRecognizableQuestions(from: document)
        guard !generated.isEmpty else {
            importError = "未能从材料中识别可练习内容，请换一份内容更完整的题库。"
            return
        }

        let bank = QuestionBank(
            title: document.title,
            sourceFileName: sourceFileName,
            sourcePreview: document.preview,
            questions: generated.map { $0.makeModel() }
        )
        modelContext.insert(bank)
        try modelContext.save()
    }

    private func deleteBanks(at offsets: IndexSet) {
        for offset in offsets {
            deleteBank(banks[offset])
        }
        try? modelContext.save()
    }

    private func deleteBank(_ bank: QuestionBank) {
        PracticeDraftStore.delete(bankID: bank.id)
        if appState.activePracticeBank?.id == bank.id {
            appState.activePracticeBank = nil
        }
        modelContext.delete(bank)
        try? modelContext.save()
    }
}

private struct ManualQuestionEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var content = ""

    let save: (String, String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("题库标题", text: $title)
                }

                Section {
                    TextEditor(text: $content)
                        .frame(minHeight: 240)
                } header: {
                    Text("材料内容")
                } footer: {
                    Text("可以粘贴知识点、题干、笔记或完整段落，系统会先保存材料，进入练习后再按所选题型出题。")
                }
            }
            .navigationTitle("手动录入")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save(titleOrFallback, content)
                    }
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).count < 12)
                }
            }
        }
    }

    private var titleOrFallback: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "手动题库" : trimmed
    }
}

private struct BankRow: View {
    let bank: QuestionBank

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "books.vertical.fill")
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 6) {
                Text(bank.title)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 12) {
                    Label("\(bank.questions.count) 条材料", systemImage: "text.page")
                    Label {
                        Text(bank.createdAt, style: .date)
                    } icon: {
                        Image(systemName: "calendar")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
