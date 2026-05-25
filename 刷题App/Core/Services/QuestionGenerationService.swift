import Foundation

struct QuestionGenerationService {
    var apiKey: String
    var preferRemote: Bool

    func generateAllRecognizableQuestions(from document: ParsedDocument) async throws -> [GeneratedQuestionDTO] {
        LocalQuestionGenerator().recognizeItems(from: document, count: estimatedQuestionCount(for: document))
    }

    func generateQuestions(from document: ParsedDocument, count: Int) async throws -> [GeneratedQuestionDTO] {
        if preferRemote, !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let client = DeepSeekClient(apiKey: apiKey)
            var generated: [GeneratedQuestionDTO] = []
            let sectionCount = max(1, document.sections.count)
            let perSection = max(1, Int(ceil(Double(count) / Double(sectionCount))))

            for section in document.sections {
                let questions = try await client.generateQuestions(from: section, count: perSection)
                generated.append(contentsOf: questions)
                if generated.count >= count {
                    break
                }
            }
            return Array(generated.prefix(count))
        }

        return LocalQuestionGenerator().generate(from: document, count: count)
    }

    private func estimatedQuestionCount(for document: ParsedDocument) -> Int {
        let sentenceCount = document.plainText
            .components(separatedBy: CharacterSet(charactersIn: "。！？.!?\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 12 }
            .count
        return min(max(sentenceCount, 10), 120)
    }
}
