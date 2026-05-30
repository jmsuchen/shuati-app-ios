import Foundation

struct LocalQuestionGenerator {
    func recognizeItems(from document: ParsedDocument, count: Int) -> [GeneratedQuestionDTO] {
        let sentences = sourceSentences(from: document)
        let items = sentences.enumerated().compactMap { index, sentence in
            makeRecognizedItem(from: sentence, index: index)
        }
        return Array(items.prefix(count))
    }

    func generate(from document: ParsedDocument, count: Int) -> [GeneratedQuestionDTO] {
        let sentences = sourceSentences(from: document)

        let answers = sentences.compactMap { chooseAnswer(in: $0) }
        let candidates = sentences.enumerated().compactMap { index, sentence in
            makeQuestion(from: sentence, index: index, distractors: answers)
        }
        return Array(candidates.prefix(count))
    }

    private func sourceSentences(from document: ParsedDocument) -> [String] {
        if document.sections.count > 1 {
            return document.sections
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.count >= 12 }
                .uniqued()
        }

        return document.plainText
            .components(separatedBy: CharacterSet(charactersIn: "。！？.!?\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 12 }
            .uniqued()
    }

    private func makeRecognizedItem(from sentence: String, index: Int) -> GeneratedQuestionDTO? {
        guard let answer = chooseAnswer(in: sentence), answer.count >= 2 else {
            return nil
        }
        return GeneratedQuestionDTO(
            stem: sentence,
            answers: [answer],
            sourceText: sentence,
            explanation: "答案来自原文中的关键表达：\(answer)。",
            difficulty: answer.count > 6 ? "medium" : "easy",
            knowledgeTags: ["识别材料"],
            questionType: nil,
            options: nil
        )
    }

    private func makeQuestion(from sentence: String, index: Int, distractors: [String]) -> GeneratedQuestionDTO? {
        guard let answer = chooseAnswer(in: sentence), answer.count >= 2 else {
            return nil
        }
        if index.isMultiple(of: 5) {
            return makeTrueFalseQuestion(from: sentence, answer: answer)
        }
        if index.isMultiple(of: 3) {
            let options = makeOptions(answer: answer, distractors: distractors)
            if options.count == 4 {
                return GeneratedQuestionDTO(
                    stem: sentence.replacingOccurrences(of: answer, with: "哪一项", options: [], range: sentence.range(of: answer)),
                    answers: [answer],
                    sourceText: sentence,
                    explanation: "正确选项来自原文中的关键表达：\(answer)。",
                    difficulty: "medium",
                    knowledgeTags: ["本地生成"],
                    questionType: PracticeQuestionKind.singleChoice.rawValue,
                    options: options
                )
            }
        }
        let stem = sentence.replacingOccurrences(of: answer, with: "____", options: [], range: sentence.range(of: answer))
        return GeneratedQuestionDTO(
            stem: stem,
            answers: [answer],
            sourceText: sentence,
            explanation: "答案来自原文中的关键表达：\(answer)。",
            difficulty: answer.count > 6 ? "medium" : "easy",
            knowledgeTags: ["本地生成"],
            questionType: PracticeQuestionKind.fillBlank.rawValue,
            options: nil
        )
    }

    private func makeTrueFalseQuestion(from sentence: String, answer: String) -> GeneratedQuestionDTO {
        GeneratedQuestionDTO(
            stem: "判断：\(sentence)",
            answers: ["正确"],
            sourceText: sentence,
            explanation: "该判断与原文一致。",
            difficulty: "easy",
            knowledgeTags: ["本地生成"],
            questionType: PracticeQuestionKind.trueFalse.rawValue,
            options: ["正确", "错误"]
        )
    }

    private func makeOptions(answer: String, distractors: [String]) -> [String] {
        var values = [answer]
        for distractor in distractors where normalize(distractor) != normalize(answer) && !values.contains(distractor) {
            values.append(distractor)
            if values.count == 4 {
                break
            }
        }
        guard values.count == 4 else { return [] }
        return values.shuffled()
    }

    private func chooseAnswer(in sentence: String) -> String? {
        let quotedPatterns = [
            #"“([^”]{2,18})”"#,
            #""([^"]{2,18})""#,
            #"`([^`]{2,18})`"#
        ]

        for pattern in quotedPatterns {
            if let match = sentence.firstMatch(pattern: pattern) {
                return match
            }
        }

        let separators = CharacterSet(charactersIn: "：:，,、 是为指即")
        let words = sentence
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 2 && $0.count <= 12 }

        return words.max { lhs, rhs in
            score(lhs) < score(rhs)
        }
    }

    private func score(_ value: String) -> Int {
        var result = value.count
        if value.range(of: #"[A-Za-z0-9]"#, options: .regularExpression) != nil {
            result += 4
        }
        if value.contains("UI") || value.contains("API") {
            result += 3
        }
        return result
    }

    private func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

private extension String {
    func firstMatch(pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(startIndex..., in: self)
        guard let match = regex.firstMatch(in: self, range: range),
              match.numberOfRanges > 1,
              let swiftRange = Range(match.range(at: 1), in: self) else {
            return nil
        }
        return String(self[swiftRange])
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
