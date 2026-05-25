import SwiftData
import SwiftUI

struct StatsView: View {
    @Query(sort: \PracticeSession.startedAt, order: .reverse) private var sessions: [PracticeSession]
    @Query private var banks: [QuestionBank]
    @Query(filter: #Predicate<AnswerRecord> { !$0.isCorrect }) private var mistakes: [AnswerRecord]

    var body: some View {
        NavigationStack {
            List {
                Section("概览") {
                    StatRow(title: "题库数量", value: "\(banks.count)", systemImage: "books.vertical")
                    StatRow(title: "练习次数", value: "\(sessions.count)", systemImage: "play.circle")
                    StatRow(title: "错题数量", value: "\(mistakes.count)", systemImage: "exclamationmark.triangle")
                    StatRow(title: "平均分", value: averageScoreText, systemImage: "chart.line.uptrend.xyaxis")
                }

                if !sessions.isEmpty {
                    Section("最近练习") {
                        ForEach(sessions) { session in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(session.bankTitle)
                                        .font(.headline)
                                    Spacer()
                                    Text("\(Int(session.score.rounded()))")
                                        .font(.title3.weight(.bold))
                                }
                                HStack {
                                    Text(session.startedAt, style: .date)
                                    Text("正确 \(session.correctCount)")
                                    Text("错误 \(session.wrongCount)")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("统计")
        }
    }

    private var averageScoreText: String {
        guard !sessions.isEmpty else { return "0" }
        let average = sessions.map(\.score).reduce(0, +) / Double(sessions.count)
        return "\(Int(average.rounded()))"
    }
}

private struct StatRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Text(value)
                .font(.headline)
        }
    }
}
