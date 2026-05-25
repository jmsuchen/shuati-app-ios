import Foundation

struct AnswerEvaluation {
    let isCorrect: Bool
    let perBlank: [Bool]
}

struct AnswerEvaluator {
    func evaluate(userAnswers: [String], correctAnswers: [String]) -> AnswerEvaluation {
        let result = correctAnswers.enumerated().map { index, correct in
            guard userAnswers.indices.contains(index) else { return false }
            return normalize(userAnswers[index]) == normalize(correct)
        }
        return AnswerEvaluation(isCorrect: result.allSatisfy { $0 }, perBlank: result)
    }

    private func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .widthInsensitive], locale: .current)
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "。", with: ".")
            .replacingOccurrences(of: "；", with: ";")
            .replacingOccurrences(of: "：", with: ":")
            .replacingOccurrences(of: "（", with: "(")
            .replacingOccurrences(of: "）", with: ")")
            .replacingOccurrences(of: "、", with: ",")
    }
}
