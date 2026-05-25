import Compression
import Foundation

enum DocxTextExtractorError: LocalizedError {
    case missingDocumentXML
    case invalidArchive
    case decompressionFailed

    var errorDescription: String? {
        switch self {
        case .missingDocumentXML: "docx 中没有找到正文 document.xml"
        case .invalidArchive: "docx 文件结构无法识别"
        case .decompressionFailed: "docx 正文解压失败"
        }
    }
}

struct DocxTextExtractor {
    func extractText(from url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        guard let entry = ZipReader(data: data).entry(named: "word/document.xml") else {
            throw DocxTextExtractorError.missingDocumentXML
        }
        guard let xml = String(data: entry, encoding: .utf8) else {
            throw DocxTextExtractorError.invalidArchive
        }
        return xml
            .replacingOccurrences(of: "</w:p>", with: "\n")
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .xmlDecoded
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct ZipReader {
    let data: Data

    func entry(named name: String) -> Data? {
        guard let directoryOffset = endOfCentralDirectoryOffset() else { return nil }
        var offset = directoryOffset

        while offset + 46 <= data.count {
            guard data.uint32(at: offset) == 0x02014b50 else { break }
            let compressionMethod = data.uint16(at: offset + 10)
            let compressedSize = Int(data.uint32(at: offset + 20))
            let uncompressedSize = Int(data.uint32(at: offset + 24))
            let fileNameLength = Int(data.uint16(at: offset + 28))
            let extraLength = Int(data.uint16(at: offset + 30))
            let commentLength = Int(data.uint16(at: offset + 32))
            let localHeaderOffset = Int(data.uint32(at: offset + 42))
            let nameStart = offset + 46
            let nameEnd = nameStart + fileNameLength
            let nextOffset = nameEnd + extraLength + commentLength

            guard fileNameLength >= 0,
                  extraLength >= 0,
                  commentLength >= 0,
                  localHeaderOffset >= 0,
                  nameEnd <= data.count,
                  nextOffset <= data.count,
                  let entryName = String(data: Data(data[nameStart..<nameEnd]), encoding: .utf8) else {
                return nil
            }

            if entryName == name {
                return readLocalEntry(
                    at: localHeaderOffset,
                    compressionMethod: compressionMethod,
                    compressedSize: compressedSize,
                    uncompressedSize: uncompressedSize
                )
            }

            offset = nextOffset
        }
        return nil
    }

    private func readLocalEntry(
        at offset: Int,
        compressionMethod: UInt16,
        compressedSize: Int,
        uncompressedSize: Int
    ) -> Data? {
        guard offset + 30 < data.count,
              data.uint32(at: offset) == 0x04034b50 else { return nil }

        let fileNameLength = Int(data.uint16(at: offset + 26))
        let extraLength = Int(data.uint16(at: offset + 28))
        let start = offset + 30 + fileNameLength + extraLength
        let end = start + compressedSize
        guard fileNameLength >= 0,
              extraLength >= 0,
              compressedSize >= 0,
              uncompressedSize >= 0,
              start >= 0,
              end <= data.count else { return nil }

        let payload = data[start..<end]
        if compressionMethod == 0 {
            return Data(payload)
        }
        if compressionMethod == 8 {
            return inflate(Data(payload), uncompressedSize: uncompressedSize)
        }
        return nil
    }

    private func endOfCentralDirectoryOffset() -> Int? {
        guard data.count >= 22 else { return nil }
        let lowerBound = max(0, data.count - 65_557)
        for offset in stride(from: data.count - 22, through: lowerBound, by: -1) {
            if data.uint32(at: offset) == 0x06054b50 {
                return Int(data.uint32(at: offset + 16))
            }
        }
        return nil
    }

    private func inflate(_ compressedData: Data, uncompressedSize: Int) -> Data? {
        var destination = Data(count: uncompressedSize)
        let decodedCount = destination.withUnsafeMutableBytes { destinationBuffer in
            compressedData.withUnsafeBytes { sourceBuffer in
                compression_decode_buffer(
                    destinationBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    uncompressedSize,
                    sourceBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    compressedData.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        guard decodedCount > 0 else { return nil }
        destination.count = decodedCount
        return destination
    }
}

private extension Data {
    func uint16(at offset: Int) -> UInt16 {
        guard offset >= 0, offset + 1 < count else { return 0 }
        return UInt16(self[offset])
            | UInt16(self[offset + 1]) << 8
    }

    func uint32(at offset: Int) -> UInt32 {
        guard offset >= 0, offset + 3 < count else { return 0 }
        return UInt32(self[offset])
            | UInt32(self[offset + 1]) << 8
            | UInt32(self[offset + 2]) << 16
            | UInt32(self[offset + 3]) << 24
    }
}

private extension String {
    var xmlDecoded: String {
        replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
    }
}
