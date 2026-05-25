import Foundation
import Observation

@Observable
final class AppState {
    static let apiKeyKey = "deepseek-api-key"
    static let mistakeAutoDeleteThresholdKey = "mistake-auto-delete-threshold"

    var apiKey: String {
        didSet {
            if apiKey.isEmpty {
                KeychainStore.delete(key: Self.apiKeyKey)
            } else {
                try? KeychainStore.save(apiKey, for: Self.apiKeyKey)
            }
        }
    }

    var useRemoteGeneration: Bool
    var activePracticeBank: QuestionBank?
    var activePracticeQuestionCount: Int
    var activePracticeKindFilter: PracticeQuestionKindFilter
    var shouldResumePractice: Bool
    var mistakeAutoDeleteThreshold: Int {
        didSet {
            UserDefaults.standard.set(mistakeAutoDeleteThreshold, forKey: Self.mistakeAutoDeleteThresholdKey)
        }
    }

    var effectiveAPIKey: String {
        if !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return apiKey
        }
        return BuiltInDeepSeekConfig.apiKey
    }

    var hasBuiltInAPIKey: Bool {
        !BuiltInDeepSeekConfig.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init() {
        let storedAPIKey = KeychainStore.load(key: Self.apiKeyKey)
        self.apiKey = storedAPIKey
        self.useRemoteGeneration = !storedAPIKey.isEmpty || !BuiltInDeepSeekConfig.apiKey.isEmpty
        self.activePracticeQuestionCount = 10
        self.activePracticeKindFilter = .mixed
        self.shouldResumePractice = false
        let threshold = UserDefaults.standard.integer(forKey: Self.mistakeAutoDeleteThresholdKey)
        self.mistakeAutoDeleteThreshold = threshold == 0 ? 3 : threshold
    }
}
