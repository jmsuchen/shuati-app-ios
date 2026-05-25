import SwiftData
import SwiftUI

@main
struct PracticeBuilderApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
        }
        .modelContainer(for: [
            QuestionBank.self,
            PracticeQuestion.self,
            PracticeSession.self,
            AnswerRecord.self
        ])
    }
}
