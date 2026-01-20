import Foundation

// MARK: - OpenAI Service
class OpenAIService {
    static let shared = OpenAIService()

    private let baseURL = "https://api.openai.com/v1/chat/completions"

    // MARK: - Optimized URLSession (HTTP/2, Connection Pooling, Keep-Alive)
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default

        // Connection pooling & keep-alive
        config.httpMaximumConnectionsPerHost = 4
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60

        // Enable HTTP/2 and pipelining
        config.httpShouldUsePipelining = true

        // Caching policy (tắt cache mặc định của URLSession vì ta tự quản lý)
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil

        // Tối ưu cho network
        config.waitsForConnectivity = true
        config.httpAdditionalHeaders = [
            "Connection": "keep-alive",
            "Accept-Encoding": "gzip, deflate"
        ]

        return URLSession(configuration: config)
    }()

    // MARK: - Response Cache (In-memory)
    private let responseCache = NSCache<NSString, CachedResponse>()
    private let cacheTTL: TimeInterval = 300 // 5 phút

    // MARK: - Prefetch Queue
    private var prefetchTask: Task<Sentence, Error>?
    private var prefetchedSentence: Sentence?
    private var prefetchKey: String?

    // MARK: - Sentence History (avoid repetition)
    private var recentSentences: [String] = []
    private let maxHistorySize = 10

    // MARK: - Debug Mode (for testing error handling)
    #if DEBUG
    enum DebugErrorType {
        case none
        case missingAPIKey
        case networkError
        case rateLimited
        case invalidResponse
        case serverError
    }

    /// Set this to simulate specific API errors for testing
    var debugSimulateError: DebugErrorType = .none

    /// Force use fallback sentences (bypass API completely)
    var debugForceFallback: Bool = false
    #endif

    // Đọc API key từ Info.plist (được inject từ xcconfig)
    private var apiKey: String {
        guard let key = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String,
              !key.isEmpty,
              key != "$(OPENAI_API_KEY)" else {
            print("⚠️ OPENAI_API_KEY not found in Info.plist")
            return ""
        }
        return key
    }

    private init() {
        responseCache.countLimit = 50 // Giới hạn 50 cached responses
    }

    // MARK: - Generate Vietnamese Sentence
    func generateSentence(topic: String, targetBand: String) async throws -> Sentence {
        let key = "sentence_\(topic)_\(targetBand)"

        // Check prefetched sentence
        if let prefetched = prefetchedSentence, prefetchKey == key {
            prefetchedSentence = nil
            prefetchKey = nil
            addToHistory(prefetched.vietnamese)
            return prefetched
        }

        // Cancel any pending prefetch
        prefetchTask?.cancel()

        let sentence = try await fetchSentence(topic: topic, targetBand: targetBand)
        addToHistory(sentence.vietnamese)
        return sentence
    }

    // MARK: - Prefetch Next Sentence (gọi khi user đang dịch câu hiện tại)
    func prefetchNextSentence(topic: String, targetBand: String) {
        let key = "sentence_\(topic)_\(targetBand)"

        // Đã prefetch rồi thì bỏ qua
        if prefetchKey == key && prefetchedSentence != nil { return }

        prefetchTask?.cancel()
        prefetchTask = Task {
            let sentence = try await fetchSentence(topic: topic, targetBand: targetBand)
            if !Task.isCancelled {
                prefetchedSentence = sentence
                prefetchKey = key
            }
            return sentence
        }
    }

    /// Add sentence to history, maintaining max size
    private func addToHistory(_ sentence: String) {
        recentSentences.append(sentence)
        if recentSentences.count > maxHistorySize {
            recentSentences.removeFirst()
        }
    }

    private func fetchSentence(topic: String, targetBand: String) async throws -> Sentence {
        // Build history exclusion list
        let historySection: String
        if recentSentences.isEmpty {
            historySection = ""
        } else {
            let historyList = recentSentences.map { "- \($0)" }.joined(separator: "\n")
            historySection = """

        IMPORTANT - Do NOT generate any of these previously used sentences:
        \(historyList)

        Generate a COMPLETELY DIFFERENT sentence with different vocabulary and structure.
        """
        }

        let prompt = """
        Generate a Vietnamese sentence for English translation practice.

        Topic: \(topic)
        Target IELTS Band: \(targetBand)

        Requirements:
        - Natural Vietnamese sentence that a native speaker would say
        - Complexity appropriate for someone aiming for Band \(targetBand)
        - Should allow for interesting vocabulary upgrades when translated
        - Include some idiomatic expressions or common phrases
        - Be creative and varied in sentence structure\(historySection)

        Return ONLY valid JSON (no markdown, no backticks):
        {
          "vietnamese": "...",
          "topic": "\(topic)",
          "targetBand": "\(targetBand)",
          "hint": "brief grammar or vocabulary hint in Vietnamese",
          "keyStructures": ["structure1", "structure2"]
        }
        """

        let response: String = try await sendRequest(prompt: prompt, config: .lessonContent)

        guard let data = response.data(using: .utf8) else {
            throw OpenAIError.invalidResponse
        }

        let decoder = JSONDecoder()
        let sentenceResponse = try decoder.decode(SentenceResponse.self, from: data)

        return Sentence(
            vietnamese: sentenceResponse.vietnamese,
            topic: sentenceResponse.topic,
            targetBand: sentenceResponse.targetBand,
            hint: sentenceResponse.hint,
            keyStructures: sentenceResponse.keyStructures
        )
    }

    // MARK: - Get Feedback
    func getFeedback(vietnamese: String, translation: String, targetBand: String) async throws -> Feedback {
        let prompt = """
        You are an IELTS examiner. Evaluate this Vietnamese-to-English translation using official IELTS Writing Task criteria.

        Vietnamese original: "\(vietnamese)"
        User's translation: "\(translation)"
        Target Band: \(targetBand)

        Score using IELTS band descriptors (0-9 scale, use .0 or .5 only):
        - Band 5.0-5.5: Limited - basic vocabulary, frequent errors, simple sentences
        - Band 6.0-6.5: Competent - adequate vocabulary, some errors, mix of simple/complex
        - Band 7.0-7.5: Good - wide vocabulary, good control, varied structures
        - Band 8.0-8.5: Very Good - wide range, rare errors, sophisticated structures
        - Band 9.0: Expert - full flexibility, complete accuracy, natural expression

        Return ONLY valid JSON (no markdown, no backticks):
        {
          "overallBand": 6.5,
          "criteria": {
            "lexicalResource": {
              "band": 6.0,
              "comment": "Brief comment on vocabulary range and accuracy"
            },
            "grammaticalRange": {
              "band": 6.5,
              "comment": "Brief comment on grammar variety and accuracy"
            },
            "coherence": {
              "band": 7.0,
              "comment": "Brief comment on flow and logical connection"
            },
            "taskAchievement": {
              "band": 6.5,
              "comment": "Brief comment on meaning preservation and completeness"
            }
          },
          "goodPoints": ["point 1", "point 2"],
          "issues": [
            {"word": "tired", "criterion": "lexicalResource", "reason": "too basic for band 7+, consider more sophisticated alternatives"}
          ],
          "upgrades": [
            {
              "original": "tired",
              "context": "I feel tired",
              "alternatives": [
                {"word": "drained", "pos": "adj", "meaning": "extremely tired, depleted of energy", "example": "I feel completely drained after the meeting", "meaningVi": "kiệt sức", "bandLevel": "7.0+"},
                {"word": "exhausted", "pos": "adj", "meaning": "very tired", "example": "She was exhausted from work", "meaningVi": "kiệt lực", "bandLevel": "6.5+"}
              ]
            }
          ],
          "improvedSentence": "Band 7.5+ version preserving the original meaning",
          "explanation": "Brief explanation in Vietnamese focusing on key improvements needed to reach higher band"
        }

        Be strict and accurate to IELTS standards. Focus on vocabulary and grammar upgrades.
        """

        let response: String = try await sendRequest(prompt: prompt, config: .examinerFeedback)

        guard let data = response.data(using: .utf8) else {
            throw OpenAIError.invalidResponse
        }

        let decoder = JSONDecoder()
        return try decoder.decode(Feedback.self, from: data)
    }

    // MARK: - Request Configuration
    struct RequestConfig {
        let model: String
        let temperature: Double
        let systemMessage: String?
        let maxTokens: Int
        let stopSequences: [String]?

        // Preset cho Lesson content (generateSentence)
        static let lessonContent = RequestConfig(
            model: "gpt-4.1",
            temperature: 0.4,
            systemMessage: "You are a strict JSON generator. If output is not valid JSON, it is considered a failure. Return ONLY valid JSON without any markdown formatting or explanation.",
            maxTokens: 1000,
            stopSequences: ["\n\n"]
        )

        // Preset cho Examiner feedback (getFeedback)
        static let examinerFeedback = RequestConfig(
            model: "gpt-4.1",
            temperature: 0.2,
            systemMessage: "You are a strict IELTS examiner and JSON generator. Score accurately according to IELTS rubric without encouraging bias. If output is not valid JSON, it is considered a failure. Return ONLY valid JSON without any markdown formatting or explanation.",
            maxTokens: 2000,
            stopSequences: ["\n\n"]
        )

        // Preset cho Interactive/Chat (speaking practice, tutor)
        static let interactiveChat = RequestConfig(
            model: "gpt-4o",
            temperature: 0.7,
            systemMessage: nil,
            maxTokens: 2000,
            stopSequences: nil
        )
    }

    // MARK: - Send Request (with retry for JSON and caching)
    private func sendRequest(prompt: String, config: RequestConfig, maxRetries: Int = 2, useCache: Bool = false) async throws -> String {
        // Debug: Simulate errors for testing
        #if DEBUG
        if debugForceFallback {
            print("🧪 DEBUG: Force fallback enabled, throwing error")
            throw OpenAIError.httpError(statusCode: 500, detail: "Debug: Force fallback enabled")
        }

        switch debugSimulateError {
        case .none:
            break
        case .missingAPIKey:
            print("🧪 DEBUG: Simulating missing API key error")
            throw OpenAIError.missingAPIKey
        case .networkError:
            print("🧪 DEBUG: Simulating network error")
            throw URLError(.notConnectedToInternet)
        case .rateLimited:
            print("🧪 DEBUG: Simulating rate limit error (429)")
            throw OpenAIError.httpError(statusCode: 429, detail: "Debug: Rate limit exceeded")
        case .invalidResponse:
            print("🧪 DEBUG: Simulating invalid response")
            throw OpenAIError.parsingError(raw: "Debug: Invalid JSON response")
        case .serverError:
            print("🧪 DEBUG: Simulating server error (500)")
            throw OpenAIError.httpError(statusCode: 500, detail: "Debug: Internal server error")
        }
        #endif

        // Check cache (chỉ dùng cho những request có thể cache)
        let cacheKey = "\(config.model)_\(prompt.hashValue)" as NSString
        if useCache, let cached = responseCache.object(forKey: cacheKey) {
            if Date().timeIntervalSince(cached.timestamp) < cacheTTL {
                return cached.response
            }
            responseCache.removeObject(forKey: cacheKey)
        }

        var lastError: Error?

        for attempt in 0...maxRetries {
            do {
                let retryPrompt = attempt > 0
                    ? "Your previous response was invalid JSON. Regenerate strictly.\n\n\(prompt)"
                    : prompt

                let response = try await sendSingleRequest(prompt: retryPrompt, config: config)

                // Validate JSON
                if let data = response.data(using: .utf8),
                   let _ = try? JSONSerialization.jsonObject(with: data) {
                    // Cache response nếu cần
                    if useCache {
                        responseCache.setObject(CachedResponse(response: response), forKey: cacheKey)
                    }
                    return response
                }

                lastError = OpenAIError.invalidJSON
            } catch {
                lastError = error
            }
        }

        throw lastError ?? OpenAIError.invalidResponse
    }

    private func sendSingleRequest(prompt: String, config: RequestConfig) async throws -> String {
        guard !apiKey.isEmpty else {
            throw OpenAIError.missingAPIKey
        }

        guard let url = URL(string: baseURL) else {
            throw OpenAIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build messages array
        var messages: [[String: String]] = []
        if let systemMessage = config.systemMessage {
            messages.append(["role": "system", "content": systemMessage])
        }
        messages.append(["role": "user", "content": prompt])

        var body: [String: Any] = [
            "model": config.model,
            "messages": messages,
            "max_tokens": config.maxTokens,
            "temperature": config.temperature
        ]

        if let stopSequences = config.stopSequences {
            body["stop"] = stopSequences
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Sử dụng optimized session thay vì URLSession.shared
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            // Try to extract error details from response body
            var errorDetail: String?
            if let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                errorDetail = errorResponse.error.message
            }
            throw OpenAIError.httpError(statusCode: httpResponse.statusCode, detail: errorDetail)
        }

        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)

        guard let content = openAIResponse.choices.first?.message.content else {
            throw OpenAIError.noContent
        }

        // Clean response (remove markdown code blocks if present)
        let cleanedContent = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleanedContent
    }

    // MARK: - Streaming Request (cho Interactive Chat - hiện UX realtime)
    func sendStreamingRequest(
        prompt: String,
        config: RequestConfig = .interactiveChat,
        onChunk: @escaping (String) -> Void
    ) async throws -> String {
        guard !apiKey.isEmpty else {
            throw OpenAIError.missingAPIKey
        }

        guard let url = URL(string: baseURL) else {
            throw OpenAIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        var messages: [[String: String]] = []
        if let systemMessage = config.systemMessage {
            messages.append(["role": "system", "content": systemMessage])
        }
        messages.append(["role": "user", "content": prompt])

        let body: [String: Any] = [
            "model": config.model,
            "messages": messages,
            "max_tokens": config.maxTokens,
            "temperature": config.temperature,
            "stream": true
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw OpenAIError.invalidResponse
        }

        var fullContent = ""

        for try await line in bytes.lines {
            // SSE format: data: {...}
            guard line.hasPrefix("data: ") else { continue }
            let jsonString = String(line.dropFirst(6))

            if jsonString == "[DONE]" { break }

            guard let jsonData = jsonString.data(using: .utf8),
                  let chunk = try? JSONDecoder().decode(StreamChunk.self, from: jsonData),
                  let content = chunk.choices.first?.delta.content else {
                continue
            }

            fullContent += content
            onChunk(content)
        }

        return fullContent
    }

    // MARK: - Clear Cache
    func clearCache() {
        responseCache.removeAllObjects()
        prefetchedSentence = nil
        prefetchKey = nil
        prefetchTask?.cancel()
        recentSentences.removeAll()
    }
}

// MARK: - Response Models
private struct SentenceResponse: Codable {
    let vietnamese: String
    let topic: String
    let targetBand: String
    let hint: String
    let keyStructures: [String]
}

private struct OpenAIResponse: Codable {
    let choices: [Choice]

    struct Choice: Codable {
        let message: Message
    }

    struct Message: Codable {
        let content: String
    }
}

private struct OpenAIErrorResponse: Codable {
    let error: OpenAIAPIError

    struct OpenAIAPIError: Codable {
        let message: String
        let type: String?
        let code: String?
    }
}

// MARK: - Streaming Response Model
private struct StreamChunk: Codable {
    let choices: [StreamChoice]

    struct StreamChoice: Codable {
        let delta: Delta
    }

    struct Delta: Codable {
        let content: String?
    }
}

// MARK: - Cache Model
private class CachedResponse {
    let response: String
    let timestamp: Date

    init(response: String) {
        self.response = response
        self.timestamp = Date()
    }
}

// MARK: - Errors
enum OpenAIError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case invalidJSON
    case httpError(statusCode: Int, detail: String?)
    case noContent
    case parsingError(raw: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API key is missing. Please check Secrets.xcconfig setup."
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from API"
        case .invalidJSON:
            return "Invalid JSON response after multiple retries"
        case .httpError(let statusCode, let detail):
            let baseMessage = httpErrorMessage(for: statusCode)
            if let detail = detail {
                return "\(baseMessage): \(detail)"
            }
            return baseMessage
        case .noContent:
            return "No content in response"
        case .parsingError(let raw):
            print("⚠️ Failed to parse response: \(raw.prefix(500))")
            return "Failed to parse API response. Please try again."
        }
    }

    private func httpErrorMessage(for statusCode: Int) -> String {
        switch statusCode {
        case 400: return "Bad request - please check your input"
        case 401: return "Invalid API key - please check your configuration"
        case 403: return "Access forbidden - API key may lack permissions"
        case 404: return "API endpoint not found"
        case 429: return "Rate limit exceeded - please wait and try again"
        case 500: return "OpenAI server error - please try again later"
        case 502, 503, 504: return "OpenAI service temporarily unavailable"
        default: return "HTTP Error \(statusCode)"
        }
    }
}
