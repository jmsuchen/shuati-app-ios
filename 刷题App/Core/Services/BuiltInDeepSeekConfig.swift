import Foundation

enum BuiltInDeepSeekConfig {
    static var apiKey: String {
        Bundle.main.object(forInfoDictionaryKey: "DEEPSEEK_API_KEY") as? String ?? ""
    }
}
