import SwiftData
import SwiftUI

struct PracticeHomeView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \QuestionBank.createdAt, order: .reverse) private var banks: [QuestionBank]
    @State private var selectedQuestionCount = 10
    @State private var selectedKindFilter = PracticeQuestionKindFilter.mixed
    @State private var pendingResumeBank: QuestionBank?
    @State private var isShowingResumeChoice = false

    var body: some View {
        NavigationStack {
            if let bank = appState.activePracticeBank {
                PracticeSessionView(
                    bank: bank,
                    requestedQuestionCount: appState.activePracticeQuestionCount,
                    requestedKindFilter: appState.activePracticeKindFilter,
                    shouldResume: appState.shouldResumePractice
                )
            } else if banks.isEmpty {
                ContentUnavailableView(
                    "暂无可练习题库",
                    systemImage: "pencil.slash",
                    description: Text("先在题库页导入文件并识别材料。")
                )
                .navigationTitle("练习")
            } else {
                List(banks) { bank in
                    VStack(alignment: .leading, spacing: 12) {
                        Button {
                            start(bank)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(bank.title)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text("\(bank.questions.count) 条材料")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "play.circle.fill")
                                    .font(.title2)
                            }
                        }

                        Picker("题量", selection: $selectedQuestionCount) {
                            Text("5").tag(5)
                            Text("10").tag(10)
                            Text("20").tag(20)
                            Text("全部").tag(Int.max)
                        }
                        .pickerStyle(.segmented)

                        Picker("题型", selection: $selectedKindFilter) {
                            ForEach(PracticeQuestionKindFilter.allCases) { filter in
                                Text(filter.title).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 4)
                }
                .navigationTitle("练习")
            }
        }
        .confirmationDialog("发现未完成练习", isPresented: $isShowingResumeChoice) {
            Button("继续上次练习") {
                if let pendingResumeBank {
                    start(pendingResumeBank, resume: true)
                }
            }
            Button("重新开始", role: .destructive) {
                if let pendingResumeBank {
                    PracticeDraftStore.delete(bankID: pendingResumeBank.id)
                    start(pendingResumeBank, resume: false)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("是否继续上次进度？")
        }
    }

    private func start(_ bank: QuestionBank, resume: Bool = false) {
        if !resume, PracticeDraftStore.load(bankID: bank.id) != nil {
            pendingResumeBank = bank
            isShowingResumeChoice = true
            return
        }
        if resume, let draft = PracticeDraftStore.load(bankID: bank.id) {
            appState.activePracticeQuestionCount = draft.questionCount
            appState.activePracticeKindFilter = draft.kindFilter
        } else {
            appState.activePracticeQuestionCount = selectedQuestionCount
            appState.activePracticeKindFilter = selectedKindFilter
        }
        appState.shouldResumePractice = resume
        appState.activePracticeBank = bank
    }
}

struct PracticeSessionView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    let bank: QuestionBank
    let requestedQuestionCount: Int
    let requestedKindFilter: PracticeQuestionKindFilter
    let shouldResume: Bool

    @State private var currentIndex = 0
    @State private var answers: [String] = [""]
    @State private var records: [AnswerRecord] = []
    @State private var sessionQuestions: [SessionQuestion] = []
    @State private var variantRound = 0
    @State private var startedAt = Date()
    @State private var questionStartedAt = Date()
    @State private var feedback: AnswerRecord?
    @State private var result: SessionScore?
    @State private var didInitialize = false

    private let evaluator = AnswerEvaluator()
    private let scoringService = ScoringService()
    private let variantFactory = QuestionVariantFactory()

    var body: some View {
        Group {
            if let result {
                PracticeResultView(bank: bank, result: result, records: records) {
                    retrySame()
                } regenerate: {
                    regenerate()
                } close: {
                    appState.activePracticeBank = nil
                }
            } else if sessionQuestions.isEmpty {
                ContentUnavailableView("题库没有可练习内容", systemImage: "questionmark.folder")
            } else {
                questionView
            }
        }
        .navigationTitle(bank.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    saveDraft()
                    appState.activePracticeBank = nil
                } label: {
                    Label("退出", systemImage: "xmark")
                }
            }
        }
        .onAppear {
            initializeSessionIfNeeded()
        }
        .sheet(item: $feedback) { record in
            FeedbackView(record: record) {
                goNext()
            }
        }
    }

    private var question: SessionQuestion {
        sessionQuestions[currentIndex]
    }

    private var questionView: some View {
        VStack(alignment: .leading, spacing: 20) {
            ProgressView(value: Double(currentIndex + 1), total: Double(sessionQuestions.count))

            HStack {
                Text("第 \(currentIndex + 1) / \(sessionQuestions.count) 题")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(question.kind.title)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule())
                Text((QuestionDifficulty(rawValue: question.difficulty) ?? .medium).title)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule())
            }

            Text(question.stem)
                .font(.title3.weight(.semibold))
                .lineSpacing(6)

            answerInput

            Button {
                submit()
            } label: {
                Label("提交答案", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSubmit)

            if !question.knowledgeTags.isEmpty {
                Text(question.knowledgeTags.joined(separator: " / "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
    }

    @ViewBuilder
    private var answerInput: some View {
        switch question.kind {
        case .fillBlank:
            VStack(spacing: 12) {
                ForEach(question.answers.indices, id: \.self) { index in
                    TextField("填写第 \(index + 1) 个空", text: binding(for: index))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                }
            }
        case .singleChoice:
            VStack(spacing: 10) {
                ForEach(question.options, id: \.self) { option in
                    optionButton(option)
                }
            }
        case .trueFalse:
            HStack(spacing: 12) {
                optionButton("正确")
                optionButton("错误")
            }
        }
    }

    private func optionButton(_ option: String) -> some View {
        Button {
            answers = [option]
        } label: {
            HStack {
                Text(option)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer()
                if answers.first == option {
                    Image(systemName: "checkmark.circle.fill")
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, 12)
            .background(
                answers.first == option ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.10),
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
    }

    private var canSubmit: Bool {
        !answers.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func binding(for index: Int) -> Binding<String> {
        Binding {
            answers.indices.contains(index) ? answers[index] : ""
        } set: { value in
            while answers.count <= index {
                answers.append("")
            }
            answers[index] = value
        }
    }

    private func prepareQuestion() {
        guard !sessionQuestions.isEmpty else { return }
        answers = Array(repeating: "", count: max(1, question.answers.count))
        questionStartedAt = .now
    }

    private func submit() {
        let evaluation = evaluator.evaluate(userAnswers: answers, correctAnswers: question.answers)
        let record = AnswerRecord(
            questionID: question.sourceQuestion.id,
            stem: question.stem,
            correctAnswers: question.answers,
            userAnswers: answers,
            sourceText: question.sourceText,
            explanation: question.explanation,
            isCorrect: evaluation.isCorrect,
            elapsedSeconds: Date().timeIntervalSince(questionStartedAt)
        )
        records.append(record)

        if evaluation.isCorrect {
            goNext()
        } else {
            saveDraft()
            feedback = record
        }
    }

    private func goNext() {
        feedback = nil
        if currentIndex + 1 >= sessionQuestions.count {
            finish()
        } else {
            currentIndex += 1
            prepareQuestion()
            saveDraft()
        }
    }

    private func finish() {
        let score = scoringService.score(records: records)
        result = score
        bank.lastPracticedAt = .now

        let session = PracticeSession(
            bankID: bank.id,
            bankTitle: bank.title,
            startedAt: startedAt,
            finishedAt: .now,
            score: score.score,
            answers: records
        )
        modelContext.insert(session)
        try? modelContext.save()
        PracticeDraftStore.delete(bankID: bank.id)
    }

    private var effectiveQuestionCount: Int {
        let availableCount = bank.questions.count
        return requestedQuestionCount == Int.max ? availableCount : min(requestedQuestionCount, availableCount)
    }

    private func buildQuestions(mode: PracticeBuildMode) {
        sessionQuestions = variantFactory.makeSessionQuestions(
            from: bank,
            count: effectiveQuestionCount,
            kindFilter: requestedKindFilter,
            mode: mode
        )
        currentIndex = 0
        records = []
        result = nil
        startedAt = .now
        prepareQuestion()
        saveDraft()
    }

    private func initializeSessionIfNeeded() {
        guard !didInitialize else { return }
        didInitialize = true
        if shouldResume, let draft = PracticeDraftStore.load(bankID: bank.id) {
            restore(draft)
        } else {
            buildQuestions(mode: .same)
        }
    }

    private func restore(_ draft: PracticeDraft) {
        sessionQuestions = variantFactory.makeSessionQuestions(
            from: bank,
            count: draft.questionCount == Int.max ? bank.questions.count : min(draft.questionCount, bank.questions.count),
            kindFilter: draft.kindFilter,
            mode: .same
        )
        records = draft.records.map { $0.makeRecord() }
        currentIndex = min(draft.currentIndex, max(0, sessionQuestions.count - 1))
        startedAt = draft.startedAt
        result = nil
        prepareQuestion()
    }

    private func saveDraft() {
        guard result == nil, !sessionQuestions.isEmpty else { return }
        PracticeDraftStore.save(PracticeDraft(
            bankID: bank.id,
            questionCount: effectiveQuestionCount,
            kindFilter: requestedKindFilter,
            currentIndex: currentIndex,
            startedAt: startedAt,
            records: records.map(AnswerRecordDraft.init(record:))
        ))
    }

    private func retrySame() {
        currentIndex = 0
        records = []
        result = nil
        startedAt = .now
        prepareQuestion()
        saveDraft()
    }

    private func regenerate() {
        variantRound += 1
        buildQuestions(mode: .newBlanks(seed: variantRound))
    }
}

private struct FeedbackView: View {
    let record: AnswerRecord
    let continueAction: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("正确答案") {
                    Text(record.correctAnswers.joined(separator: " / "))
                        .font(.headline)
                }
                Section("你的答案") {
                    Text(record.userAnswers.joined(separator: " / "))
                        .foregroundStyle(.secondary)
                }
                Section("原文") {
                    Text(record.sourceText)
                }
                Section("解析") {
                    Text(record.explanation)
                }
            }
            .navigationTitle("答错了")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("继续", action: continueAction)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct PracticeResultView: View {
    let bank: QuestionBank
    let result: SessionScore
    let records: [AnswerRecord]
    let retrySame: () -> Void
    let regenerate: () -> Void
    let close: () -> Void

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(Int(result.score.rounded()))")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                    Text("正确率 \(Int((result.accuracy * 100).rounded()))%")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            }

            Section("本轮表现") {
                LabeledContent("正确题数", value: "\(result.correctCount)")
                LabeledContent("错误题数", value: "\(result.wrongCount)")
                LabeledContent("平均用时", value: "\(Int(result.averageSeconds.rounded())) 秒")
                LabeledContent("最长连对", value: "\(result.longestStreak)")
            }

            let wrongRecords = records.filter { !$0.isCorrect }
            if !wrongRecords.isEmpty {
                Section("错题") {
                    ForEach(wrongRecords) { record in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(record.stem)
                            Text(record.correctAnswers.joined(separator: " / "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                Button {
                    retrySame()
                } label: {
                    Label("重做一遍", systemImage: "arrow.counterclockwise")
                }
                Button {
                    regenerate()
                } label: {
                    Label("重新出卷", systemImage: "shuffle")
                }
                Button {
                    close()
                } label: {
                    Label("完成", systemImage: "checkmark")
                }
            }
        }
        .navigationTitle("练习结果")
    }
}
