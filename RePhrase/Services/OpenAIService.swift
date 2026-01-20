import Foundation

// MARK: - OpenAI Service
class OpenAIService {
    static let shared = OpenAIService()

    private let baseURL = "https://api.openai.com/v1/chat/completions"

    // Track recent sentences to avoid repetition
    private var recentSentences: [String] = []
    private let maxHistorySize = 10

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

    private init() {}
    
    // MARK: - Generate Vietnamese Sentence
    func generateSentence(topic: String, targetBand: String) async throws -> Sentence {
        // Build history exclusion list
        let historySection: String
        if recentSentences.isEmpty {
            historySection = ""
        } else {
            let historyList = recentSentences.enumerated()
                .map { "- \($0.element)" }
                .joined(separator: "\n")
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

        let response: String = try await sendRequest(prompt: prompt)

        guard let data = response.data(using: .utf8) else {
            throw OpenAIError.invalidResponse
        }

        let decoder = JSONDecoder()
        let sentenceResponse = try decoder.decode(SentenceResponse.self, from: data)

        // Add to history to avoid repetition
        addToHistory(sentenceResponse.vietnamese)

        return Sentence(
            vietnamese: sentenceResponse.vietnamese,
            topic: sentenceResponse.topic,
            targetBand: sentenceResponse.targetBand,
            hint: sentenceResponse.hint,
            keyStructures: sentenceResponse.keyStructures
        )
    }

    /// Add sentence to history, maintaining max size
    private func addToHistory(_ sentence: String) {
        recentSentences.append(sentence)
        if recentSentences.count > maxHistorySize {
            recentSentences.removeFirst()
        }
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

        Be encouraging but accurate to IELTS standards. Focus on vocabulary and grammar upgrades.
        """
        
        let response: String = try await sendRequest(prompt: prompt)
        
        guard let data = response.data(using: .utf8) else {
            throw OpenAIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(Feedback.self, from: data)
    }
    
    // MARK: - Send Request
    private func sendRequest(prompt: String) async throws -> String {
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
        
        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 2000,
            "temperature": 0.7
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
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
        let cleanedContent = cleanJSONResponse(content)

        // Validate that it's valid JSON before returning
        guard let jsonData = cleanedContent.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: jsonData)) != nil else {
            throw OpenAIError.parsingError(raw: content)
        }

        return cleanedContent
    }

    /// Cleans OpenAI response by removing markdown formatting and extracting JSON
    private func cleanJSONResponse(_ content: String) -> String {
        var result = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove various markdown code block formats
        let codeBlockPatterns = [
            "```json\\s*\\n?",   // ```json with optional newline
            "```\\s*\\n?",       // ``` with optional newline
            "\\n?```$",          // ending ```
        ]

        for pattern in codeBlockPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: ""
                )
            }
        }

        // Try to extract JSON if it's wrapped in other text
        if let jsonStart = result.firstIndex(of: "{"),
           let jsonEnd = result.lastIndex(of: "}") {
            result = String(result[jsonStart...jsonEnd])
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
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

// MARK: - Errors
enum OpenAIError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
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
