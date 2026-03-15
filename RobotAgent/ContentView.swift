// Nebius SF Robotics Hackathon 2026
// ContentView.swift

import SwiftUI

struct ContentView: View {
    @Environment(AppViewModel.self) private var appViewModel

    var body: some View {
        VStack(spacing: 0) {
            TabBarView(appViewModel: appViewModel)
            ChatView(session: appViewModel.selectedSession)
                .id(appViewModel.selectedSessionID)
                .padding()
        }
    }
}

#Preview {
    ContentView()
        .environment(\.robotAgentClient, .mock)
        .environment(AppViewModel())
}
