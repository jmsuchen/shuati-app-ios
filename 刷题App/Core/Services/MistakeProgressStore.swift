import Foundation

enum MistakeProgressStore {
    private static let prefix = "mistake-correct-streak-"

    static func streak(for questionID: UUID) -> Int {
        UserDefaults.standard.integer(forKey: key(questionID))
    }

    static func recordCorrect(questionID: UUID) -> Int {
        let next = streak(for: questionID) + 1
        UserDefaults.standard.set(next, forKey: key(questionID))
        return next
    }

    static func reset(questionID: UUID) {
        UserDefaults.standard.removeObject(forKey: key(questionID))
    }

    private static func key(_ questionID: UUID) -> String {
        "\(prefix)\(questionID.uuidString)"
    }
}
