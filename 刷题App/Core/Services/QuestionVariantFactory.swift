import Foundation

struct SessionQuestion: Identifiable {
    let id = UUID()
    let sourceQuestion: PracticeQuestion
    let stem: String
    let answers: [String]
    let options: [String]
    let kind: PracticeQuestionKind
    let sourceText: String
    let explanation: String
    let difficulty: String
    let knowledgeTags: [String]
}

struct QuestionVariantFactory {
    func makeSessionQuestions(
        from bank: QuestionBank,
        count: Int,
        kindFilter: PracticeQuestionKindFilter,
        mode: PracticeBuildMode
    ) -> [SessionQuestion] {
        let source = Array(bank.questions.prefix(count))
        let distractors = bank.questions.flatMap(\.answers)
        return source.enumerated().map { index, question in
            let seed = mode.seed + index
            let kind = practiceKind(for: kindFilter, index: seed)
            return makeQuestion(question, kind: kind, index: seed, distractors: distractors)
        }
    }

    private func practiceKind(for filter: PracticeQuestionKindFilter, index: Int) -> PracticeQuestionKind {
        switch filter {
        case .mixed:
            return PracticeQuestionKind.allCases[index % PracticeQuestionKind.allCases.count]
        case .fillBlank:
            return .fillBlank
        case .singleChoice:
            return .singleChoice
        case .trueFalse:
            return .trueFalse
        }
    }

    private func makeQuestion(
        _ question: PracticeQuestion,
        kind requestedKind: PracticeQuestionKind,
        index: Int,
        distractors: [String]
    ) -> SessionQuestion {
        let candidates = blankCandidates(in: question.sourceText)
        let fallbackAnswers = question.answers.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let answer = candidates.dropFirst(index % max(1, candidates.count)).first
            ?? candidates.first
            ?? fallbackAnswers.first
            ?? question.sourceText

        switch requestedKind {
        case .fillBlank:
            return makeFillBlank(question, answer: answer)
        case .singleChoice:
            let options = makeOptions(answer: answer, distractors: distractors + candidates)
            return SessionQuestion(
                sourceQuestion: question,
                stem: replacementStem(sourceText: question.sourceText, answer: answer, blank: "哪一项"),
                answers: [answer],
                options: options,
                kind: .singleChoice,
                sourceText: question.sourceText,
                explanation: "正确选项来自原文中的关键表达：\(answer)。",
                difficulty: question.difficulty,
                knowledgeTags: question.knowledgeTags
            )
        case .trueFalse:
            return makeTrueFalse(question, answer: answer, index: index, distractors: distractors + candidates)
        }
    }

    private func makeFillBlank(_ question: PracticeQuestion, answer: String) -> SessionQuestion {
        SessionQuestion(
            sourceQuestion: question,
            stem: replacementStem(sourceText: question.sourceText, answer: answer, blank: "____"),
            answers: [answer],
            options: [],
            kind: .fillBlank,
            sourceText: question.sourceText,
            explanation: "答案来自原文中的关键表达：\(answer)。",
            difficulty: question.difficulty,
            knowledgeTags: question.knowledgeTags
        )
    }

    private func makeTrueFalse(
        _ question: PracticeQuestion,
        answer: String,
        index: Int,
        distractors: [String]
    ) -> SessionQuestion {
        let shouldBeFalse = !index.isMultiple(of: 2)
        let replacement = distractors.first { normalize($0) != normalize(answer) && question.sourceText.contains(answer) }
        let statement: String
        let correctAnswer: String
        if shouldBeFalse, let replacement {
            statement = replacementStem(sourceText: question.sourceText, answer: answer, blank: replacement)
            correctAnswer = "错误"
        } else {
            statement = question.sourceText
            correctAnswer = "正确"
        }
        return SessionQuestion(
            sourceQuestion: question,
            stem: "判断：\(statement)",
            answers: [correctAnswer],
            options: ["正确", "错误"],
            kind: .trueFalse,
            sourceText: question.sourceText,
            explanation: correctAnswer == "正确" ? "该判断与原文一致。" : "原文中的关键表达应为：\(answer)。",
            difficulty: question.difficulty,
            knowledgeTags: question.knowledgeTags
        )
    }

    private func replacementStem(sourceText: String, answer: String, blank: String) -> String {
        sourceText.replacingOccurrences(
            of: answer,
            with: blank,
            options: [],
            range: sourceText.range(of: answer)
        )
    }

    private func blankCandidates(in text: String) -> [String] {
        let separators = CharacterSet(charactersIn: "：:，,、 是为指即的了和与及或在中")
        return text
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 2 && $0.count <= 12 }
            .uniqued()
    }

    private func makeOptions(answer: String, distractors: [String]) -> [String] {
        var values = [answer]
        for distractor in distractors where normalize(distractor) != normalize(answer) && !values.contains(distractor) {
            values.append(distractor)
            if values.count == 4 {
                break
            }
        }
        for fallback in fallbackOptions(for: answer) where !values.contains(fallback) {
            values.append(fallback)
            if values.count == 4 {
                break
            }
        }
        return Array(values.prefix(4)).shuffled()
    }

    private func fallbackOptions(for answer: String) -> [String] {
        if let number = Double(answer) {
            return [
                String(format: "%.0f", number + 1),
                String(format: "%.0f", max(0, number - 1)),
                "\(answer)0"
            ]
        }
        return [
            "\(answer)相关概念",
            "\(answer)相反表述",
            "以上都不正确"
        ]
    }

    private func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

enum PracticeBuildMode {
    case same
    case newBlanks(seed: Int)

    var seed: Int {
        switch self {
        case .same: 0
        case .newBlanks(let seed): seed
        }
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
