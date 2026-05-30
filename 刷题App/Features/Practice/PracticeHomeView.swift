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
                            HStack(spacing: 12) {
                                Image(systemName: "play.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.green)
                                    .frame(width: 42, height: 42)
                                    .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(bank.title)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Label("\(bank.questions.count) 条材料", systemImage: "text.page")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
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
                Label("第 \(currentIndex + 1) / \(sessionQuestions.count) 题", systemImage: "list.number")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                QuestionBadge(
                    title: question.kind.title,
                    systemImage: icon(for: question.kind),
                    color: color(for: question.kind)
                )
                QuestionBadge(
                    title: (QuestionDifficulty(rawValue: question.difficulty) ?? .medium).title,
                    systemImage: "gauge.with.dots.needle.50percent",
                    color: .orange
                )
            }

            MarkdownText(question.stem)
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
                Label(question.knowledgeTags.joined(separator: " / "), systemImage: "tag")
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
                Image(systemName: answers.first == option ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(answers.first == option ? Color.accentColor : Color.secondary)
                MarkdownText(option)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer()
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

    private func icon(for kind: PracticeQuestionKind) -> String {
        switch kind {
        case .fillBlank: "rectangle.and.pencil.and.ellipsis"
        case .singleChoice: "checklist"
        case .trueFalse: "checkmark.seal"
        }
    }

    private func color(for kind: PracticeQuestionKind) -> Color {
        switch kind {
        case .fillBlank: .blue
        case .singleChoice: .purple
        case .trueFalse: .green
        }
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
            feedback = record
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
        let availableQuestions = availablePracticeQuestions(in: bank, filter: requestedKindFilter)
        let availableCount = availableQuestions.count
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
            count: draft.questionCount == Int.max ? availablePracticeQuestions(in: bank, filter: draft.kindFilter).count : min(draft.questionCount, availablePracticeQuestions(in: bank, filter: draft.kindFilter).count),
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

    private func availablePracticeQuestions(in bank: QuestionBank, filter: PracticeQuestionKindFilter) -> [PracticeQuestion] {
        if bank.questions.contains(where: { $0.knowledgeTags.contains("原题导入") }) {
            return bank.questions.filter { filter.includes($0.questionKind) }
        }
        return bank.questions
    }
}

private struct QuestionBadge: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }
}

private struct MarkdownText: View {
    let value: String

    init(_ value: String) {
        self.value = value
    }

    var body: some View {
        Text(attributedValue)
    }

    private var attributedValue: AttributedString {
        let displayValue = value.markdownWithReadableMath
        return (try? AttributedString(markdown: displayValue)) ?? AttributedString(displayValue)
    }
}

private extension String {
    var markdownWithReadableMath: String {
        replacingInlineMath { math in
            math.readableFormula
        }
    }

    private func replacingInlineMath(_ transform: (String) -> String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\$([^$\n]+)\$"#) else {
            return self
        }

        var result = self
        let matches = regex.matches(in: self, range: NSRange(startIndex..., in: self))
        for match in matches.reversed() {
            guard let fullRange = Range(match.range(at: 0), in: result),
                  let mathRange = Range(match.range(at: 1), in: result) else {
                continue
            }
            result.replaceSubrange(fullRange, with: transform(String(result[mathRange])))
        }
        return result
    }

    private var readableFormula: String {
        var result = self
            .replacingOccurrences(of: #"\\mathrm\{([^}]+)\}"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"\\text\{([^}]+)\}"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: "\\cdot", with: "·")
            .replacingOccurrences(of: "\\times", with: "×")
            .replacingOccurrences(of: "\\omega", with: "ω")
            .replacingOccurrences(of: "\\Omega", with: "Ω")
            .replacingOccurrences(of: "\\alpha", with: "α")
            .replacingOccurrences(of: "\\beta", with: "β")
            .replacingOccurrences(of: "\\gamma", with: "γ")
            .replacingOccurrences(of: "\\Delta", with: "Δ")
            .replacingOccurrences(of: "\\leq", with: "≤")
            .replacingOccurrences(of: "\\geq", with: "≥")
            .replacingOccurrences(of: "\\neq", with: "≠")
            .replacingOccurrences(of: "\\", with: "")

        result = result.replacingScript(pattern: #"_\{([^}]+)\}"#, script: .lower)
        result = result.replacingScript(pattern: #"_(\w)"#, script: .lower)
        result = result.replacingScript(pattern: #"\^\{([^}]+)\}"#, script: .upper)
        result = result.replacingScript(pattern: #"\^(\w)"#, script: .upper)
        return result
    }

    private func replacingScript(pattern: String, script: FormulaScript) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return self
        }

        var result = self
        let matches = regex.matches(in: self, range: NSRange(startIndex..., in: self))
        for match in matches.reversed() {
            guard let fullRange = Range(match.range(at: 0), in: result),
                  let valueRange = Range(match.range(at: 1), in: result) else {
                continue
            }
            result.replaceSubrange(fullRange, with: String(result[valueRange]).scripted(as: script))
        }
        return result
    }

    private func scripted(as script: FormulaScript) -> String {
        map { character in
            script.characterMap[character] ?? character
        }
        .map(String.init)
        .joined()
    }
}

private enum FormulaScript {
    case lower
    case upper

    var characterMap: [Character: Character] {
        switch self {
        case .lower:
            return [
                "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄",
                "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉",
                "+": "₊", "-": "₋", "=": "₌", "(": "₍", ")": "₎",
                "a": "ₐ", "e": "ₑ", "h": "ₕ", "i": "ᵢ", "j": "ⱼ",
                "k": "ₖ", "l": "ₗ", "m": "ₘ", "n": "ₙ", "o": "ₒ",
                "p": "ₚ", "r": "ᵣ", "s": "ₛ", "t": "ₜ", "u": "ᵤ",
                "v": "ᵥ", "x": "ₓ"
            ]
        case .upper:
            return [
                "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
                "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹",
                "+": "⁺", "-": "⁻", "=": "⁼", "(": "⁽", ")": "⁾",
                "a": "ᵃ", "b": "ᵇ", "c": "ᶜ", "d": "ᵈ", "e": "ᵉ",
                "f": "ᶠ", "g": "ᵍ", "h": "ʰ", "i": "ⁱ", "j": "ʲ",
                "k": "ᵏ", "l": "ˡ", "m": "ᵐ", "n": "ⁿ", "o": "ᵒ",
                "p": "ᵖ", "r": "ʳ", "s": "ˢ", "t": "ᵗ", "u": "ᵘ",
                "v": "ᵛ", "w": "ʷ", "x": "ˣ", "y": "ʸ", "z": "ᶻ"
            ]
        }
    }
}

private struct FeedbackView: View {
    let record: AnswerRecord
    let continueAction: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label(record.isCorrect ? "正确" : "错误", systemImage: record.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(record.isCorrect ? .green : .red)
                }
                Section("正确答案") {
                    MarkdownText(record.correctAnswers.joined(separator: " / "))
                        .font(.headline)
                }
                Section("你的答案") {
                    MarkdownText(record.userAnswers.joined(separator: " / "))
                        .foregroundStyle(.secondary)
                }
                Section("原文") {
                    MarkdownText(record.sourceText)
                }
                Section("解析") {
                    MarkdownText(record.explanation)
                }
            }
            .navigationTitle(record.isCorrect ? "答对了" : "答错了")
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
                            MarkdownText(record.stem)
                            MarkdownText(record.correctAnswers.joined(separator: " / "))
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
