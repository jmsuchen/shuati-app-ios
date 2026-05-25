import Foundation
import UniformTypeIdentifiers

enum DocumentImportError: LocalizedError {
    case unsupportedFormat
    case emptyDocument

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat: "暂不支持该文件格式"
        case .emptyDocument: "文件中没有可解析的正文"
        }
    }
}

struct DocumentImportService {
    private let markdownParser = MarkdownParser()
    private let docxExtractor = DocxTextExtractor()

    func importDocument(from url: URL) throws -> ParsedDocument {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let fileName = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension.lowercased()
        let text: String

        switch ext {
        case "md", "markdown", "txt":
            text = try String(contentsOf: url, encoding: .utf8)
        case "docx":
            text = try docxExtractor.extractText(from: url)
        default:
            throw DocumentImportError.unsupportedFormat
        }

        let parsed = markdownParser.parse(markdown: text, fallbackTitle: fileName)
        guard !parsed.plainText.isEmpty else {
            throw DocumentImportError.emptyDocument
        }
        return parsed
    }
}
