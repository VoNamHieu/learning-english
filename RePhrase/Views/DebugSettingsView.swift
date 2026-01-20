#if DEBUG
import SwiftUI

struct DebugSettingsView: View {
    @State private var apiKeyStatus: String = "Chưa kiểm tra"
    @State private var apiKeyColor: Color = .secondary
    @State private var isTestingAPI: Bool = false
    @State private var testResult: String = ""
    @State private var testResultColor: Color = .secondary
    @State private var rawResponse: String = ""
    @State private var showRawResponse: Bool = false

    // Error simulation (optional)
    @State private var forceFallback: Bool = false

    var body: some View {
        NavigationView {
            List {
                // MARK: - API Status Check
                Section("🔑 API Key Status") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(apiKeyStatus)
                            .foregroundColor(apiKeyColor)
                            .fontWeight(.medium)
                    }

                    Button("Kiểm tra API Key") {
                        checkAPIKey()
                    }
                }

                // MARK: - Test Real API
                Section("🌐 Test API thật") {
                    Button(action: testRealAPI) {
                        HStack {
                            Text("Gọi API tạo câu")
                            Spacer()
                            if isTestingAPI {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isTestingAPI)

                    if !testResult.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Kết quả:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(testResult)
                                .font(.body)
                                .foregroundColor(testResultColor)
                        }
                        .padding(.vertical, 4)
                    }

                    if !rawResponse.isEmpty {
                        Toggle("Xem raw response", isOn: $showRawResponse)

                        if showRawResponse {
                            ScrollView {
                                Text(rawResponse)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .textSelection(.enabled)
                            }
                            .frame(maxHeight: 200)
                        }
                    }
                }

                // MARK: - Test Feedback API
                Section("📝 Test Feedback API") {
                    Button(action: testFeedbackAPI) {
                        HStack {
                            Text("Gọi API chấm điểm")
                            Spacer()
                            if isTestingAPI {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isTestingAPI)
                }

                // MARK: - Force Fallback (for offline testing)
                Section("🔧 Chế độ Offline") {
                    Toggle("Dùng câu fallback (không gọi API)", isOn: $forceFallback)
                        .onChange(of: forceFallback) { _, newValue in
                            OpenAIService.shared.debugForceFallback = newValue
                        }

                    Text("Bật để test app khi không có mạng hoặc API key")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // MARK: - Clear Cache
                Section("🗑️ Cache") {
                    Button("Xóa cache & history") {
                        OpenAIService.shared.clearCache()
                        testResult = "✅ Đã xóa cache"
                        testResultColor = .green
                    }
                }
            }
            .navigationTitle("🧪 Debug API")
            .onAppear {
                checkAPIKey()
                forceFallback = OpenAIService.shared.debugForceFallback
            }
        }
    }

    // MARK: - Check API Key
    private func checkAPIKey() {
        if let key = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String,
           !key.isEmpty,
           key != "$(OPENAI_API_KEY)" {
            let maskedKey = String(key.prefix(8)) + "..." + String(key.suffix(4))
            apiKeyStatus = "✅ Có key: \(maskedKey)"
            apiKeyColor = .green
        } else {
            apiKeyStatus = "❌ Chưa có API key"
            apiKeyColor = .red
        }
    }

    // MARK: - Test Real API (Generate Sentence)
    private func testRealAPI() {
        isTestingAPI = true
        testResult = "Đang gọi API..."
        testResultColor = .secondary
        rawResponse = ""

        Task {
            do {
                let startTime = Date()
                let sentence = try await OpenAIService.shared.generateSentence(
                    topic: "daily_life",
                    targetBand: "6.5"
                )
                let duration = Date().timeIntervalSince(startTime)

                await MainActor.run {
                    testResult = "✅ Thành công! (\(String(format: "%.2f", duration))s)\n\n\"\(sentence.vietnamese)\""
                    testResultColor = .green
                    rawResponse = """
                    Topic: \(sentence.topic)
                    Band: \(sentence.targetBand)
                    Hint: \(sentence.hint)
                    Structures: \(sentence.keyStructures.joined(separator: ", "))
                    """
                    isTestingAPI = false
                }
            } catch {
                await MainActor.run {
                    testResult = "❌ Lỗi: \(error.localizedDescription)"
                    testResultColor = .red
                    rawResponse = "Error details:\n\(error)"
                    isTestingAPI = false
                }
            }
        }
    }

    // MARK: - Test Feedback API
    private func testFeedbackAPI() {
        isTestingAPI = true
        testResult = "Đang gọi API chấm điểm..."
        testResultColor = .secondary
        rawResponse = ""

        Task {
            do {
                let startTime = Date()
                let feedback = try await OpenAIService.shared.getFeedback(
                    vietnamese: "Tôi rất mệt sau một ngày làm việc.",
                    translation: "I am very tired after a working day.",
                    targetBand: "6.5"
                )
                let duration = Date().timeIntervalSince(startTime)

                await MainActor.run {
                    testResult = """
                    ✅ Thành công! (\(String(format: "%.2f", duration))s)

                    Overall Band: \(feedback.overallBand)
                    - Lexical: \(feedback.criteria.lexicalResource.band)
                    - Grammar: \(feedback.criteria.grammaticalRange.band)
                    - Coherence: \(feedback.criteria.coherence.band)
                    - Task: \(feedback.criteria.taskAchievement.band)
                    """
                    testResultColor = .green
                    rawResponse = """
                    Good points: \(feedback.goodPoints.joined(separator: ", "))

                    Improved: \(feedback.improvedSentence)

                    Explanation: \(feedback.explanation)
                    """
                    isTestingAPI = false
                }
            } catch {
                await MainActor.run {
                    testResult = "❌ Lỗi: \(error.localizedDescription)"
                    testResultColor = .red
                    rawResponse = "Error details:\n\(error)"
                    isTestingAPI = false
                }
            }
        }
    }
}

#Preview {
    DebugSettingsView()
}
#endif
