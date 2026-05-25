import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            LibraryView()
                .tabItem {
                    Label("题库", systemImage: "books.vertical")
                }

            PracticeHomeView()
                .tabItem {
                    Label("练习", systemImage: "pencil.and.list.clipboard")
                }

            MistakesView()
                .tabItem {
                    Label("错题", systemImage: "exclamationmark.triangle")
                }

            StatsView()
                .tabItem {
                    Label("统计", systemImage: "chart.bar.xaxis")
                }

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
        }
    }
}
