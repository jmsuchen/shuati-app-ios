import Foundation
import SwiftData

enum QuestionDifficulty: String, Codable, CaseIterable {
    case easy
    case medium
    case hard

    var title: String {
        switch self {
        case .easy: "简单"
        case .medium: "中等"
        case .hard: "困难"
        }
    }
}

enum PracticeQuestionKind: String, Codable, CaseIterable {
    case fillBlank
    case singleChoice
    case trueFalse

    var title: String {
        switch self {
        case .fillBlank: "填空"
        case .singleChoice: "选择"
        case .trueFalse: "判断"
        }
    }
}

enum PracticeQuestionKindFilter: String, Codable, CaseIterable, Identifiable {
    case mixed
    case fillBlank
    case singleChoice
    case trueFalse

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mixed: "混合"
        case .fillBlank: "填空"
        case .singleChoice: "选择"
        case .trueFalse: "判断"
        }
    }

    func includes(_ kind: PracticeQuestionKind) -> Bool {
        switch self {
        case .mixed: true
        case .fillBlank: kind == .fillBlank
        case .singleChoice: kind == .singleChoice
        case .trueFalse: kind == .trueFalse
        }
    }
}

@Model
final class QuestionBank {
    @Attribute(.unique) var id: UUID
    var title: String
    var sourceFileName: String
    var sourcePreview: String
    var sourceMarkdown: String = ""
    var createdAt: Date
    var lastPracticedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \PracticeQuestion.bank)
    var questions: [PracticeQuestion]

    init(
        id: UUID = UUID(),
        title: String,
        sourceFileName: String,
        sourcePreview: String,
        sourceMarkdown: String = "",
        createdAt: Date = .now,
        questions: [PracticeQuestion] = []
    ) {
        self.id = id
        self.title = title
        self.sourceFileName = sourceFileName
        self.sourcePreview = sourcePreview
        self.sourceMarkdown = sourceMarkdown
        self.createdAt = createdAt
        self.questions = questions
    }
}

@Model
final class PracticeQuestion {
    @Attribute(.unique) var id: UUID
    var stem: String
    var answerText: String
    var sourceText: String
    var explanation: String
    var difficulty: String
    var tagText: String
    var kind: String = PracticeQuestionKind.fillBlank.rawValue
    var optionText: String = "[]"
    var sourceLocation: String
    var createdAt: Date
    var bank: QuestionBank?

    var answers: [String] {
        get { answerText.linesOrJSONList }
        set { answerText = newValue.jsonListString }
    }

    var knowledgeTags: [String] {
        get { tagText.linesOrJSONList }
        set { tagText = newValue.jsonListString }
    }

    var options: [String] {
        get { optionText.linesOrJSONList }
        set { optionText = newValue.jsonListString }
    }

    var questionKind: PracticeQuestionKind {
        get { PracticeQuestionKind(rawValue: kind) ?? .fillBlank }
        set { kind = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        stem: String,
        answers: [String],
        sourceText: String,
        explanation: String,
        difficulty: QuestionDifficulty = .medium,
        knowledgeTags: [String] = [],
        kind: PracticeQuestionKind = .fillBlank,
        options: [String] = [],
        sourceLocation: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.stem = stem
        self.answerText = answers.jsonListString
        self.sourceText = sourceText
        self.explanation = explanation
        self.difficulty = difficulty.rawValue
        self.tagText = knowledgeTags.jsonListString
        self.kind = kind.rawValue
        self.optionText = options.jsonListString
        self.sourceLocation = sourceLocation
        self.createdAt = createdAt
    }
}

@Model
final class PracticeSession {
    @Attribute(.unique) var id: UUID
    var bankID: UUID
    var bankTitle: String
    var startedAt: Date
    var finishedAt: Date?
    var score: Double

    @Relationship(deleteRule: .cascade, inverse: \AnswerRecord.session)
    var answers: [AnswerRecord]

    init(
        id: UUID = UUID(),
        bankID: UUID,
        bankTitle: String,
        startedAt: Date = .now,
        finishedAt: Date? = nil,
        score: Double = 0,
        answers: [AnswerRecord] = []
    ) {
        self.id = id
        self.bankID = bankID
        self.bankTitle = bankTitle
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.score = score
        self.answers = answers
    }

    var correctCount: Int {
        answers.filter(\.isCorrect).count
    }

    var wrongCount: Int {
        answers.count - correctCount
    }
}

@Model
final class AnswerRecord {
    @Attribute(.unique) var id: UUID
    var questionID: UUID
    var stem: String
    var correctAnswerText: String
    var userAnswerText: String
    var sourceText: String
    var explanation: String
    var isCorrect: Bool
    var elapsedSeconds: Double
    var answeredAt: Date
    var session: PracticeSession?

    var correctAnswers: [String] {
        correctAnswerText.linesOrJSONList
    }

    var userAnswers: [String] {
        userAnswerText.linesOrJSONList
    }

    init(
        id: UUID = UUID(),
        questionID: UUID,
        stem: String,
        correctAnswers: [String],
        userAnswers: [String],
        sourceText: String,
        explanation: String,
        isCorrect: Bool,
        elapsedSeconds: Double,
        answeredAt: Date = .now
    ) {
        self.id = id
        self.questionID = questionID
        self.stem = stem
        self.correctAnswerText = correctAnswers.jsonListString
        self.userAnswerText = userAnswers.jsonListString
        self.sourceText = sourceText
        self.explanation = explanation
        self.isCorrect = isCorrect
        self.elapsedSeconds = elapsedSeconds
        self.answeredAt = answeredAt
    }
}

private extension Array where Element == String {
    var jsonListString: String {
        guard let data = try? JSONEncoder().encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return joined(separator: "\n")
        }
        return string
    }
}

private extension String {
    var linesOrJSONList: [String] {
        if let data = data(using: .utf8),
           let values = try? JSONDecoder().decode([String].self, from: data) {
            return values
        }
        return split(separator: "\n").map(String.init)
    }
}
