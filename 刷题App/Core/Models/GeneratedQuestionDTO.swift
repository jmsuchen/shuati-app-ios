import Foundation

struct GeneratedQuestionResponse: Decodable {
    let questions: [GeneratedQuestionDTO]
}

struct GeneratedQuestionDTO: Decodable, Identifiable {
    var id = UUID()
    let stem: String
    let answers: [String]
    let sourceText: String
    let explanation: String
    let difficulty: String
    let knowledgeTags: [String]
    let questionType: String?
    let options: [String]?

    enum CodingKeys: CodingKey {
        case stem
        case answers
        case sourceText
        case explanation
        case difficulty
        case knowledgeTags
        case questionType
        case options
    }

    func makeModel() -> PracticeQuestion {
        PracticeQuestion(
            stem: stem,
            answers: answers,
            sourceText: sourceText,
            explanation: explanation,
            difficulty: QuestionDifficulty(rawValue: difficulty) ?? .medium,
            knowledgeTags: knowledgeTags,
            kind: normalizedKind,
            options: normalizedOptions
        )
    }

    private var normalizedOptions: [String] {
        let values = options ?? []
        return values.count == 4 ? values : []
    }

    private var normalizedKind: PracticeQuestionKind {
        let explicit = PracticeQuestionKind(rawValue: questionType ?? "") ?? inferredKind
        if explicit == .singleChoice, normalizedOptions.count != 4 {
            return .fillBlank
        }
        return explicit
    }

    private var inferredKind: PracticeQuestionKind {
        if let options, options.count >= 2 {
            return .singleChoice
        }
        if answers.first == "正确" || answers.first == "错误" {
            return .trueFalse
        }
        return .fillBlank
    }
}
