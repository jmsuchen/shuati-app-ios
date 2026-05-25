import SwiftData
import SwiftUI

struct MistakesView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<AnswerRecord> { !$0.isCorrect }, sort: \AnswerRecord.answeredAt, order: .reverse)
    private var mistakes: [AnswerRecord]
    @State private var isPracticing = false

    var body: some View {
        NavigationStack {
            if isPracticing {
                MistakePracticeView(
                    mistakes: mistakes,
                    autoDeleteThreshold: appState.mistakeAutoDeleteThreshold
                ) {
                    isPracticing = false
                }
            } else {
                Group {
                    if mistakes.isEmpty {
                        ContentUnavailableView(
                            "暂无错题",
                            systemImage: "checkmark.seal",
                            description: Text("练习中的错误答案会自动进入这里。")
                        )
                    } else {
                        List(mistakes) { mistake in
                            NavigationLink {
                                MistakeDetailView(record: mistake)
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

private struct MistakeDetailView: View {
    let record: AnswerRecord

    var body: some View {
        List {
            Section("题目") {
                Text(record.stem)
            }
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
        .navigationTitle("错题详情")
    }
}
