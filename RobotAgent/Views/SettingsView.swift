// Nebius SF Robotics Hackathon 2026
// SettingsView.swift

import SwiftUI

struct SettingsView: View {
    @AppStorage("openai_base_url") private var baseURL: String = "https://api.openai.com/v1 "
    @AppStorage("openai_api_key") private var apiKey: String = ""
    @AppStorage("selected_model") private var selectedModel: String = ""
    @AppStorage("system_prompt") private var systemPrompt: String = ""

    @Environment(\.robotAgentClient) private var client
    @State private var validationStatus: ValidationStatus = .unknown
    @State private var availableModels: [String] = []

    enum ValidationStatus: Equatable {
        case unknown
        case validating
        case valid
        case invalid(String)

        var color: Color {
            switch self {
            case .unknown: return .gray
            case .validating: return .blue
            case .valid: return .green
            case .invalid: return .red
            }
        }
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    TextField("Base URL", text: $baseURL)
                        .textFieldStyle(.roundedBorder)
                        #if os(macOS)
                        .help("The OpenAI compatible API endpoint (e.g., https://api.openai.com)")
                        #endif

                    Button {
                        Task { await validate() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(validationStatus == .validating)
                    #if os(macOS)
                    .help(validationMessage)
                    #endif

                    Circle()
                        .fill(validationStatus.color)
                        .frame(width: 10, height: 10)
                        #if os(macOS)
                        .help(validationMessage)
                        #endif
                }

                SecureField("API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    #if os(macOS)
                    .help("Your OpenAI or LM Studio API Key")
                    #endif

                if availableModels.isEmpty {
                    HStack {
                        Text("Model")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(selectedModel.isEmpty ? "Validate connection to load models" : selectedModel)
                            .foregroundStyle(.tertiary)
                            .font(.subheadline)
                    }
                } else {
                    Picker("Model", selection: $selectedModel) {
                        ForEach(availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                }
            } header: {
                Text("API Configuration")
                    .font(.headline)
            }
            Section {
                TextEditor(text: $systemPrompt)
                    .font(.body)
                    .frame(minHeight: 120)
                    #if os(macOS)
                    .help("Sent as the system message at the start of every conversation.")
                    #endif
            } header: {
                Text("System Prompt")
                    .font(.headline)
            }
        }
        .padding(20)
        #if os(macOS)
        .frame(width: 450)
        #endif
        .task(id: baseURL) {
            // Debounce for URL typing
            try? await Task.sleep(for: .seconds(0.5))
            await validate()
        }
        .task(id: apiKey) {
            // Debounce for API Key typing
            try? await Task.sleep(for: .seconds(0.5))
            await validate()
        }
    }

    private var validationMessage: String {
        switch validationStatus {
        case .unknown: return "Not validated"
        case .validating: return "Validating..."
        case .valid: return "Connection successful"
        case .invalid(let error): return "Validation failed: \(error)"
        }
    }

    private func validate() async {
        guard !baseURL.isEmpty else {
            validationStatus = .invalid("Base URL is empty")
            return
        }

        validationStatus = .validating
        availableModels = []

        do {
            let response = try await client.fetchModels()
            let ids = response.data.map(\.id).sorted()
            availableModels = ids
            validationStatus = .valid

            if ids.count == 1 {
                selectedModel = ids[0]
            } else if selectedModel.isEmpty || !ids.contains(selectedModel) {
                selectedModel = ids.first ?? ""
            }
        } catch {
            validationStatus = .invalid(error.localizedDescription)
        }
    }
}

#Preview {
    SettingsView()
        .environment(\.robotAgentClient, .mock)
}
