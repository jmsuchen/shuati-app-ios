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
                    StatRow(title: "题库数量", value: "\(banks.count)", systemImage: "books.vertical.fill", color: .blue)
                    StatRow(title: "练习次数", value: "\(sessions.count)", systemImage: "play.circle.fill", color: .green)
                    StatRow(title: "错题数量", value: "\(mistakes.count)", systemImage: "exclamationmark.triangle.fill", color: .red)
                    StatRow(title: "平均分", value: averageScoreText, systemImage: "chart.line.uptrend.xyaxis", color: .orange)
                }

                if !sessions.isEmpty {
                    Section("最近练习") {
                        ForEach(sessions) { session in
                            HStack(spacing: 12) {
                                IconBubble(systemImage: "doc.text.fill", color: .indigo)
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(session.bankTitle)
                                            .font(.headline)
                                        Spacer()
                                        Label("\(Int(session.score.rounded()))", systemImage: "star.fill")
                                            .font(.title3.weight(.bold))
                                            .foregroundStyle(.orange)
                                    }
                                    HStack(spacing: 12) {
                                        Label {
                                            Text(session.startedAt, style: .date)
                                        } icon: {
                                            Image(systemName: "calendar")
                                        }
                                        Label("正确 \(session.correctCount)", systemImage: "checkmark.circle")
                                        Label("错误 \(session.wrongCount)", systemImage: "xmark.circle")
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
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
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            IconBubble(systemImage: systemImage, color: color)
            Text(title)
            Spacer()
            Text(value)
                .font(.headline)
        }
    }
}

private struct IconBubble: View {
    let systemImage: String
    let color: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.headline)
            .foregroundStyle(color)
            .frame(width: 34, height: 34)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}
