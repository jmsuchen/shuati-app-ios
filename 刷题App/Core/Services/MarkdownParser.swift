import Foundation

struct ParsedDocument {
    let title: String
    let markdownText: String
    let plainText: String
    let preview: String
    let sections: [String]
}

struct MarkdownParser {
    func parse(markdown: String, fallbackTitle: String) -> ParsedDocument {
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        let title = lines.first { $0.trimmingCharacters(in: .whitespaces).hasPrefix("#") }?
            .replacingOccurrences(of: "#", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty ?? fallbackTitle

        let plain = lines
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("```") }
            .map(cleanMarkdownLine)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return ParsedDocument(
            title: title,
            markdownText: normalized.trimmingCharacters(in: .whitespacesAndNewlines),
            plainText: plain,
            preview: String(plain.prefix(800)),
            sections: splitSections(from: normalized)
        )
    }

    private func cleanMarkdownLine(_ line: String) -> String {
        line
            .replacingOccurrences(of: #"^#{1,6}\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^\s*[-*+]\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^\s*\d+\.\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    private func splitSections(from text: String) -> [String] {
        let questionBlocks = splitQuestionBlocks(from: text)
        if questionBlocks.count > 1 {
            return questionBlocks
        }

        let paragraphs = text
            .components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 12 }

        var sections: [String] = []
        var current = ""
        for paragraph in paragraphs {
            if current.count + paragraph.count > 1_800 {
                sections.append(current)
                current = paragraph
            } else {
                current += current.isEmpty ? paragraph : "\n\(paragraph)"
            }
        }
        if !current.isEmpty {
            sections.append(current)
        }
        return sections.isEmpty ? [text] : sections
    }

    private func splitQuestionBlocks(from text: String) -> [String] {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let hasQuestionTypeHeading = lines.contains { line in
            isMarkdownHeading(line) && isSupportedQuestionHeading(line)
        }

        var blocks: [String] = []
        var current: [String] = []
        var isInSupportedQuestionSection = !hasQuestionTypeHeading
        for line in lines where !line.isEmpty {
            if isMarkdownHeading(line) {
                if !current.isEmpty {
                    blocks.append(current.joined(separator: "\n"))
                    current = []
                }
                isInSupportedQuestionSection = !hasQuestionTypeHeading || isSupportedQuestionHeading(line)
                continue
            }
            guard isInSupportedQuestionSection else { continue }
            if isQuestionNumberLine(line), !current.isEmpty {
                blocks.append(current.joined(separator: "\n"))
                current = [line]
            } else {
                current.append(line)
            }
        }
        if !current.isEmpty {
            blocks.append(current.joined(separator: "\n"))
        }
        return blocks.filter { $0.count >= 8 }
    }

    private func isQuestionNumberLine(_ line: String) -> Bool {
        line.range(
            of: #"^\s*(?:\d{1,4}[\.、．\)]|[一二三四五六七八九十]{1,4}[、\.．])\s*.+"#,
            options: .regularExpression
        ) != nil
    }

    private func isMarkdownHeading(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).hasPrefix("#")
    }

    private func isSupportedQuestionHeading(_ line: String) -> Bool {
        line.contains("填空题") || line.contains("判断题") || line.contains("选择题")
    }
}

struct OriginalQuestionParser {
    func parse(document: ParsedDocument) -> [PracticeQuestion] {
        document.sections.compactMap(parseBlock)
    }

    private func parseBlock(_ block: String) -> PracticeQuestion? {
        let cleanedBlock = block.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedBlock.isEmpty else { return nil }

        let options = parseOptions(from: cleanedBlock)
        let answerTokens = parseAnswerTokens(from: cleanedBlock)
        let normalizedAnswerTokens = answerTokens.map(normalizeAnswerToken)

        if let judgementAnswer = judgementAnswer(from: normalizedAnswerTokens) {
            return PracticeQuestion(
                stem: removeAnswerMarkers(from: cleanedBlock),
                answers: [judgementAnswer],
                sourceText: cleanedBlock,
                explanation: "答案来自原题括号中的标记：\(judgementAnswer)。",
                difficulty: .medium,
                knowledgeTags: ["原题导入"],
                kind: .trueFalse,
                options: ["正确", "错误"]
            )
        }

        if !options.isEmpty {
            let answer = choiceAnswer(from: normalizedAnswerTokens, options: options)
            guard let answer else { return nil }
            return PracticeQuestion(
                stem: removeAnswerMarkers(from: cleanedBlock),
                answers: [answer],
                sourceText: cleanedBlock,
                explanation: "正确选项来自原题括号中的答案。",
                difficulty: .medium,
                knowledgeTags: ["原题导入"],
                kind: .singleChoice,
                options: options.map(\.text)
            )
        }

        guard !answerTokens.isEmpty else { return nil }
        return PracticeQuestion(
            stem: replaceAnswerMarkersWithBlanks(in: cleanedBlock),
            answers: answerTokens,
            sourceText: cleanedBlock,
            explanation: "填空答案来自原题括号内文字。",
            difficulty: .medium,
            knowledgeTags: ["原题导入"],
            kind: .fillBlank
        )
    }

    private func parseOptions(from block: String) -> [OriginalQuestionOption] {
        block
            .components(separatedBy: .newlines)
            .compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let match = trimmed.firstMatch(
                    pattern: #"^([A-Ha-h])[\.\、．\)]\s*(.+)$"#,
                    groupCount: 2
                ) else {
                    return nil
                }
                return OriginalQuestionOption(letter: match[0].uppercased(), text: match[1])
            }
    }

    private func parseAnswerTokens(from block: String) -> [String] {
        let patterns = [
            #"（([^（）]{1,40})）"#,
            #"\(([^()]{1,40})\)"#
        ]
        return patterns.flatMap { pattern in
            block.matches(pattern: pattern).flatMap { value in
                value
                    .components(separatedBy: CharacterSet(charactersIn: "、,/，;；"))
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        }
    }

    private func judgementAnswer(from tokens: [String]) -> String? {
        for token in tokens {
            switch token {
            case "正确", "对", "√", "yes", "true", "t":
                return "正确"
            case "错误", "错", "×", "x", "false", "f", "no":
                return "错误"
            default:
                continue
            }
        }
        return nil
    }

    private func choiceAnswer(from tokens: [String], options: [OriginalQuestionOption]) -> String? {
        for token in tokens {
            if let option = options.first(where: { $0.letter == token.uppercased() }) {
                return option.text
            }
            if let option = options.first(where: { normalizeAnswerToken($0.text) == token }) {
                return option.text
            }
        }
        return nil
    }

    private func removeAnswerMarkers(from text: String) -> String {
        text
            .replacingOccurrences(of: #"（[^（）]{1,40}）"#, with: "（ ）", options: .regularExpression)
            .replacingOccurrences(of: #"\([^()]{1,40}\)"#, with: "( )", options: .regularExpression)
    }

    private func replaceAnswerMarkersWithBlanks(in text: String) -> String {
        text
            .replacingOccurrences(of: #"（[^（）]{1,40}）"#, with: "____", options: .regularExpression)
            .replacingOccurrences(of: #"\([^()]{1,40}\)"#, with: "____", options: .regularExpression)
    }

    private func normalizeAnswerToken(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "$", with: "")
            .lowercased()
    }
}

private struct OriginalQuestionOption {
    let letter: String
    let text: String
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }

    func firstMatch(pattern: String, groupCount: Int) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(startIndex..., in: self)
        guard let match = regex.firstMatch(in: self, range: range), match.numberOfRanges > groupCount else {
            return nil
        }
        return (1...groupCount).compactMap { index in
            guard let swiftRange = Range(match.range(at: index), in: self) else { return nil }
            return String(self[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    func matches(pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(startIndex..., in: self)
        return regex.matches(in: self, range: range).compactMap { match in
            guard match.numberOfRanges > 1,
                  let swiftRange = Range(match.range(at: 1), in: self) else {
                return nil
            }
            return String(self[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
