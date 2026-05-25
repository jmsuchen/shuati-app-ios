import Foundation

struct ParsedDocument {
    let title: String
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
            plainText: plain,
            preview: String(plain.prefix(800)),
            sections: splitSections(from: plain)
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
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
