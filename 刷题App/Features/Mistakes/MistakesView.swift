import SwiftData
import SwiftUI

struct MistakesView: View {
    @Environment(AppState.self) private var appState
    @Query(filter: #Predicate<AnswerRecord> { !$0.isCorrect }, sort: \AnswerRecord.answeredAt, order: .reverse)
    private var mistakes: [AnswerRecord]
    @State private var isPracticing = false

    var body: some View {
        NavigationStack {
            if isPracticing {
                MistakePracticeView(
                    mistakes: uniqueMistakes,
                    autoDeleteThreshold: appState.mistakeAutoDeleteThreshold
                ) {
                    isPracticing = false
                }
            } else {
                Group {
                    if uniqueMistakes.isEmpty {
                        ContentUnavailableView(
                            "暂无错题",
                            systemImage: "checkmark.seal",
                            description: Text("练习中的错误答案会自动进入这里。")
                        )
                    } else {
                        List(uniqueMistakes) { mistake in
                            NavigationLink {
                                SingleMistakePracticeView(
                                    record: mistake,
                                    relatedMistakes: mistakes,
                                    autoDeleteThreshold: appState.mistakeAutoDeleteThreshold
                                )
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(mistake.stem)
                                        .lineLimit(2)
                                    HStack {
                                        Text(mistake.correctAnswers.joined(separator: " / "))
                                        Text("连对 \(MistakeProgressStore.streak(for: mistake.questionID))")
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .navigationTitle("错题")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isPracticing = true
                        } label: {
                            Label("练习错题", systemImage: "arrow.clockwise.circle")
                        }
                        .disabled(mistakes.isEmpty)
                    }
                }
            }
        }
    }

    private var uniqueMistakes: [AnswerRecord] {
        var seen = Set<UUID>()
        return mistakes.filter { mistake in
            seen.insert(mistake.questionID).inserted
        }
    }
}

private struct MistakePracticeView: View {
    @Environment(\.modelContext) private var modelContext

    let mistakes: [AnswerRecord]
    let autoDeleteThreshold: Int
    let close: () -> Void

    @State private var currentIndex = 0
    @State private var answer = ""
    @State private var feedback: String?

    private let evaluator = AnswerEvaluator()

    var body: some View {
        Group {
            if mistakes.isEmpty {
                ContentUnavailableView("错题已清空", systemImage: "checkmark.seal")
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    ProgressView(value: Double(currentIndex + 1), total: Double(mistakes.count))
                    Text("第 \(currentIndex + 1) / \(mistakes.count) 题")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(current.stem)
                        .font(.title3.weight(.semibold))
                        .lineSpacing(6)

                    TextField("填写答案", text: $answer)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    if let feedback {
                        Text(feedback)
                            .font(.callout)
                            .foregroundStyle(feedback.hasPrefix("正确") ? .green : .red)
                    }

                    Button {
                        submit()
                    } label: {
                        Label("提交", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Spacer()
                }
                .padding()
            }
        }
        .navigationTitle("错题复练")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("退出", action: close)
            }
        }
    }

    private var current: AnswerRecord {
        mistakes[min(currentIndex, mistakes.count - 1)]
    }

    private func submit() {
        let evaluation = evaluator.evaluate(userAnswers: [answer], correctAnswers: current.correctAnswers)
        if evaluation.isCorrect {
            let streak = MistakeProgressStore.recordCorrect(questionID: current.questionID)
            feedback = "正确，已连对 \(streak) 次"
            if streak >= autoDeleteThreshold {
                deleteMistakes(for: current.questionID)
                MistakeProgressStore.reset(questionID: current.questionID)
                feedback = "正确，已从错题本移除"
            }
            goNext()
        } else {
            MistakeProgressStore.reset(questionID: current.questionID)
            feedback = "错误，正确答案：\(current.correctAnswers.joined(separator: " / "))"
        }
    }

    private func goNext() {
        answer = ""
        if currentIndex + 1 >= mistakes.count {
            close()
        } else {
            currentIndex += 1
        }
    }

    private func deleteMistakes(for questionID: UUID) {
        for mistake in mistakes where mistake.questionID == questionID {
            modelContext.delete(mistake)
        }
        try? modelContext.save()
    }
}

private struct SingleMistakePracticeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let record: AnswerRecord
    let relatedMistakes: [AnswerRecord]
    let autoDeleteThreshold: Int

    @State private var sourceQuestion: PracticeQuestion?
    @State private var answer = ""
    @State private var selectedAnswer: String?
    @State private var feedback: String?
    @State private var isShowingAnswer = false
    @State private var isConfirmingDelete = false

    private let evaluator = AnswerEvaluator()

    var body: some View {
        List {
            Section("题目") {
                Text(record.stem)
                    .font(.headline)
            }

            Section("作答") {
                answerControl

                Button {
                    submit()
                } label: {
                    Label("提交本题", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(currentAnswer.isEmpty)

                if let feedback {
                    Text(feedback)
                        .foregroundStyle(feedback.hasPrefix("正确") ? .green : .red)
                }
            }

            Section {
                Button {
                    isShowingAnswer.toggle()
                } label: {
                    Label(isShowingAnswer ? "隐藏答案和解析" : "显示答案和解析", systemImage: "text.magnifyingglass")
                }

                if isShowingAnswer {
                    LabeledContent("正确答案") {
                        Text(record.correctAnswers.joined(separator: " / "))
                    }
                    LabeledContent("你的答案") {
                        Text(record.userAnswers.joined(separator: " / "))
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("解析")
                            .font(.subheadline.weight(.semibold))
                        Text(record.explanation)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("原文")
                            .font(.subheadline.weight(.semibold))
                        Text(record.sourceText)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Label("删除这道错题", systemImage: "trash")
                }
            }
        }
        .navigationTitle("单题练习")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            loadSourceQuestion()
        }
        .confirmationDialog("删除这道错题？", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                deleteRelatedMistakes()
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("会从错题本移除这道题的全部错误记录。")
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private var answerControl: some View {
        if let sourceQuestion,
           sourceQuestion.questionKind == .singleChoice || sourceQuestion.questionKind == .trueFalse,
           !choiceOptions(for: sourceQuestion).isEmpty {
            VStack(spacing: 10) {
                ForEach(choiceOptions(for: sourceQuestion), id: \.self) { option in
                    Button {
                        selectedAnswer = option
                    } label: {
                        HStack {
                            Text(option)
                            Spacer()
                            if selectedAnswer == option {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.vertical, 4)
        } else {
            TextField("填写答案", text: $answer)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
        }
    }

    private var currentAnswer: String {
        let value = selectedAnswer ?? answer
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func choiceOptions(for question: PracticeQuestion) -> [String] {
        if question.questionKind == .trueFalse {
            return question.options.isEmpty ? ["正确", "错误"] : question.options
        }
        return question.options
    }

    private func loadSourceQuestion() {
        guard sourceQuestion == nil else { return }
        let questionID = record.questionID
        let descriptor = FetchDescriptor<PracticeQuestion>(
            predicate: #Predicate { question in
                question.id == questionID
            }
        )
        sourceQuestion = try? modelContext.fetch(descriptor).first
    }

    private func submit() {
        let evaluation = evaluator.evaluate(userAnswers: [currentAnswer], correctAnswers: record.correctAnswers)
        if evaluation.isCorrect {
            let streak = MistakeProgressStore.recordCorrect(questionID: record.questionID)
            if streak >= autoDeleteThreshold {
                deleteRelatedMistakes()
                MistakeProgressStore.reset(questionID: record.questionID)
                dismiss()
            } else {
                feedback = "正确，已连对 \(streak) 次"
                answer = ""
                selectedAnswer = nil
            }
        } else {
            MistakeProgressStore.reset(questionID: record.questionID)
            feedback = "错误，可点“显示答案和解析”查看。"
            isShowingAnswer = true
        }
    }

    private func deleteRelatedMistakes() {
        for mistake in relatedMistakes where mistake.questionID == record.questionID {
            modelContext.delete(mistake)
        }
        MistakeProgressStore.reset(questionID: record.questionID)
        try? modelContext.save()
    }
}
