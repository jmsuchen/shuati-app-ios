import Foundation

struct PracticeDraft: Codable {
    let bankID: UUID
    let questionCount: Int
    let kindFilter: PracticeQuestionKindFilter
    let currentIndex: Int
    let startedAt: Date
    let records: [AnswerRecordDraft]
}

struct AnswerRecordDraft: Codable {
    let questionID: UUID
    let stem: String
    let correctAnswers: [String]
    let userAnswers: [String]
    let sourceText: String
    let explanation: String
    let isCorrect: Bool
    let elapsedSeconds: Double
    let answeredAt: Date

    init(record: AnswerRecord) {
        self.questionID = record.questionID
        self.stem = record.stem
        self.correctAnswers = record.correctAnswers
        self.userAnswers = record.userAnswers
        self.sourceText = record.sourceText
        self.explanation = record.explanation
        self.isCorrect = record.isCorrect
        self.elapsedSeconds = record.elapsedSeconds
        self.answeredAt = record.answeredAt
    }

    func makeRecord() -> AnswerRecord {
        AnswerRecord(
            questionID: questionID,
            stem: stem,
            correctAnswers: correctAnswers,
            userAnswers: userAnswers,
            sourceText: sourceText,
            explanation: explanation,
            isCorrect: isCorrect,
            elapsedSeconds: elapsedSeconds,
            answeredAt: answeredAt
        )
    }
}

enum PracticeDraftStore {
    private static let prefix = "practice-draft-"

    static func load(bankID: UUID) -> PracticeDraft? {
        guard let data = UserDefaults.standard.data(forKey: key(bankID)) else { return nil }
        return try? JSONDecoder().decode(PracticeDraft.self, from: data)
    }

    static func save(_ draft: PracticeDraft) {
        guard let data = try? JSONEncoder().encode(draft) else { return }
        UserDefaults.standard.set(data, forKey: key(draft.bankID))
    }

    static func delete(bankID: UUID) {
        UserDefaults.standard.removeObject(forKey: key(bankID))
    }

    private static func key(_ bankID: UUID) -> String {
        "\(prefix)\(bankID.uuidString)"
    }
}
