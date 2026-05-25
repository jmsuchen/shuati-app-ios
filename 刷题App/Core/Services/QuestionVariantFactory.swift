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
        let filtered = bank.questions.filter { kindFilter.includes($0.questionKind) }
        let source = Array(filtered.prefix(count))
        let distractors = bank.questions.flatMap(\.answers)
        return source.enumerated().map { index, question in
            switch mode {
            case .same:
                return makeSame(question)
            case .newBlanks(let seed):
                return makeVariant(question, index: index + seed, distractors: distractors)
            }
        }
    }

    private func makeSame(_ question: PracticeQuestion) -> SessionQuestion {
        SessionQuestion(
            sourceQuestion: question,
            stem: question.stem,
            answers: question.answers,
            options: question.options,
            kind: question.questionKind,
            sourceText: question.sourceText,
            explanation: question.explanation,
            difficulty: question.difficulty,
            knowledgeTags: question.knowledgeTags
        )
    }

    private func makeVariant(_ question: PracticeQuestion, index: Int, distractors: [String]) -> SessionQuestion {
        guard question.questionKind == .fillBlank || question.questionKind == .singleChoice else {
            return makeSame(question)
        }

        let candidates = blankCandidates(in: question.sourceText)
            .filter { candidate in
                !question.answers.contains { normalize($0) == normalize(candidate) }
            }
        guard let answer = candidates.dropFirst(index % max(1, candidates.count)).first ?? candidates.first else {
            return makeSame(question)
        }

        let kind = question.questionKind == .singleChoice ? PracticeQuestionKind.singleChoice : PracticeQuestionKind.fillBlank
        let stem = question.sourceText.replacingOccurrences(
            of: answer,
            with: kind == .singleChoice ? "哪一项" : "____",
            options: [],
            range: question.sourceText.range(of: answer)
        )
        let options = kind == .singleChoice ? makeOptions(answer: answer, distractors: distractors + candidates) : []
        return SessionQuestion(
            sourceQuestion: question,
            stem: stem,
            answers: [answer],
            options: options,
            kind: options.count == 4 ? kind : .fillBlank,
            sourceText: question.sourceText,
            explanation: "本次改挖空为：\(answer)。",
            difficulty: question.difficulty,
            knowledgeTags: question.knowledgeTags
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
        return values.count == 4 ? values.shuffled() : []
    }

    private func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

enum PracticeBuildMode {
    case same
    case newBlanks(seed: Int)
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
