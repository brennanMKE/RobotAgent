// Nebius SF Robotics Hackathon 2026
// RobotAgentApp.swift

import SwiftUI

// Environment Values are used to pass values down the SwiftUI view hierarchy

private struct RobotAgentClientKey: EnvironmentKey {
    // This is the default client used if none is provided via .environment()
    static let defaultValue: RobotAgentClient = RobotAgentClient()
}

extension EnvironmentValues {
    var robotAgentClient: RobotAgentClient {
        get { self[RobotAgentClientKey.self] }
        set { self[RobotAgentClientKey.self] = newValue }
    }
}

#if DEBUG
private let isTesting = false // can be true or false during development
#else
private let isTesting = false
#endif

private var client: RobotAgentClient {
    isTesting ? .mock : .default
}

@main
struct RobotAgentApp: App {
    @State private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.robotAgentClient, client)
                .environment(appViewModel)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Tab") {
                    appViewModel.addSession()
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("New Chat") {
                    appViewModel.addSession()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Clear Chat") {
                    appViewModel.selectedSession.chatViewModel.clearHistory()
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
        }
    }
}

#Preview {
    ContentView()
        .environment(\.robotAgentClient, client)
        .environment(AppViewModel())
}
