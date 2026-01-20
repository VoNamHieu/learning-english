#if DEBUG
import SwiftUI

struct DebugSettingsView: View {
    @State private var selectedError: OpenAIService.DebugErrorType = .none
    @State private var forceFallback: Bool = false

    var body: some View {
        NavigationView {
            List {
                Section("API Error Simulation") {
                    Toggle("Force Fallback (bypass API)", isOn: $forceFallback)
                        .onChange(of: forceFallback) { _, newValue in
                            OpenAIService.shared.debugForceFallback = newValue
                        }

                    Picker("Simulate Error Type", selection: $selectedError) {
                        Text("None (Normal)").tag(OpenAIService.DebugErrorType.none)
                        Text("Missing API Key").tag(OpenAIService.DebugErrorType.missingAPIKey)
                        Text("Network Error").tag(OpenAIService.DebugErrorType.networkError)
                        Text("Rate Limited (429)").tag(OpenAIService.DebugErrorType.rateLimited)
                        Text("Invalid Response").tag(OpenAIService.DebugErrorType.invalidResponse)
                        Text("Server Error (500)").tag(OpenAIService.DebugErrorType.serverError)
                    }
                    .onChange(of: selectedError) { _, newValue in
                        OpenAIService.shared.debugSimulateError = newValue
                    }
                }

                Section("Current Settings") {
                    HStack {
                        Text("Force Fallback")
                        Spacer()
                        Text(forceFallback ? "ON" : "OFF")
                            .foregroundColor(forceFallback ? .red : .green)
                    }
                    HStack {
                        Text("Error Type")
                        Spacer()
                        Text(errorTypeLabel(selectedError))
                            .foregroundColor(selectedError == .none ? .green : .orange)
                    }
                }

                Section("Instructions") {
                    Text("1. Enable 'Force Fallback' to test fallback sentences")
                    Text("2. Select an error type to test specific error handling")
                    Text("3. Go back and try generating a sentence")
                    Text("4. Check console for debug logs (🧪)")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .navigationTitle("🧪 Debug Settings")
            .onAppear {
                // Sync with current state
                forceFallback = OpenAIService.shared.debugForceFallback
                selectedError = OpenAIService.shared.debugSimulateError
            }
        }
    }

    private func errorTypeLabel(_ type: OpenAIService.DebugErrorType) -> String {
        switch type {
        case .none: return "None"
        case .missingAPIKey: return "Missing API Key"
        case .networkError: return "Network Error"
        case .rateLimited: return "Rate Limited"
        case .invalidResponse: return "Invalid Response"
        case .serverError: return "Server Error"
        }
    }
}

#Preview {
    DebugSettingsView()
}
#endif
