import Foundation

enum DeepSeekClientError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: "请先在设置中配置 DeepSeek API Key"
        case .invalidResponse: "DeepSeek 返回格式无法识别"
        case .apiError(let message): message
        }
    }
}

struct DeepSeekClient {
    var apiKey: String
    var model: String = "deepseek-v4-flash"
    var baseURL = URL(string: "https://api.deepseek.com/chat/completions")!

    func generateQuestions(from section: String, count: Int) async throws -> [GeneratedQuestionDTO] {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DeepSeekClientError.missingAPIKey
        }

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ChatRequest(
            model: model,
            messages: [
                .init(role: "system", content: Self.systemPrompt),
                .init(role: "user", content: Self.userPrompt(section: section, count: count))
            ],
            temperature: 0.4,
            responseFormat: .init(type: "json_object")
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeepSeekClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw DeepSeekClientError.apiError(body)
        }

        let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = chatResponse.choices.first?.message.content,
              let jsonData = content.data(using: .utf8) else {
            throw DeepSeekClientError.invalidResponse
        }
        return try JSONDecoder().decode(GeneratedQuestionResponse.self, from: jsonData).questions
    }

    private static let systemPrompt = """
    你是一个严谨的刷题 App 出题引擎。只返回 JSON，不要 Markdown，不要解释。
    JSON 结构必须是：
    {"questions":[{"questionType":"fillBlank|singleChoice|trueFalse","stem":"题干","answers":["答案"],"options":["A","B","C","D"],"sourceText":"原文","explanation":"简短解析","difficulty":"easy|medium|hard","knowledgeTags":["标签"]}]}
    自动判断适合题型：定义、术语、流程可做填空；有明确概念辨析时做四选一；可直接判定真假的陈述做判断题。
    fillBlank 的题干必须包含至少一个 ____。singleChoice 必须给 4 个选项且 answers[0] 等于其中一个选项。trueFalse 的 answers[0] 只能是“正确”或“错误”。
    """

    private static func userPrompt(section: String, count: Int) -> String {
        """
        请从以下材料生成 \(count) 道填空题。优先挖空关键概念、术语、定义、结论和步骤。

        材料：
        \(section)
        """
    }
}

private struct ChatRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let responseFormat: ResponseFormat

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case responseFormat = "response_format"
    }
}

private struct ChatMessage: Codable {
    let role: String
    let content: String
}

private struct ResponseFormat: Encodable {
    let type: String
}

private struct ChatResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: ChatMessage
    }
}
