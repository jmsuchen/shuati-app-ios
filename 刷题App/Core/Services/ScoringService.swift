import Foundation

struct SessionScore {
    let score: Double
    let correctCount: Int
    let wrongCount: Int
    let accuracy: Double
    let averageSeconds: Double
    let longestStreak: Int
}

struct ScoringService {
    func score(records: [AnswerRecord]) -> SessionScore {
        guard !records.isEmpty else {
            return SessionScore(score: 0, correctCount: 0, wrongCount: 0, accuracy: 0, averageSeconds: 0, longestStreak: 0)
        }

        let correctCount = records.filter(\.isCorrect).count
        let accuracy = Double(correctCount) / Double(records.count)
        let averageSeconds = records.map(\.elapsedSeconds).reduce(0, +) / Double(records.count)

        var currentStreak = 0
        var longestStreak = 0
        for record in records {
            if record.isCorrect {
                currentStreak += 1
                longestStreak = max(longestStreak, currentStreak)
            } else {
                currentStreak = 0
            }
        }

        return SessionScore(
            score: min(100, max(0, accuracy * 100)),
            correctCount: correctCount,
            wrongCount: records.count - correctCount,
            accuracy: accuracy,
            averageSeconds: averageSeconds,
            longestStreak: longestStreak
        )
    }
}
