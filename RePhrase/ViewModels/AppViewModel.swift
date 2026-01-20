import Foundation
import SwiftUI

// MARK: - App State
enum AppScreen {
    case home
    case translate
    case feedback
    case vocabBank
}

// MARK: - App ViewModel
@MainActor
class AppViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var currentScreen: AppScreen = .home
    @Published var selectedTopic: Topic?
    @Published var targetBand: TargetBand = TargetBand.all[3] // Default 6.5
    @Published var currentSentence: Sentence?
    @Published var userTranslation: String = ""
    @Published var feedback: Feedback?
    @Published var vocabBank: [VocabItem] = []
    @Published var stats: UserStats = .empty
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    // MARK: - Services
    private let openAI = OpenAIService.shared
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Keys
    private let vocabBankKey = "vocabBank"
    private let statsKey = "userStats"
    
    // MARK: - Init
    init() {
        loadData()
        updateStreak()
    }
    
    // MARK: - Navigation
    func goHome() {
        userTranslation = ""
        feedback = nil
        currentScreen = .home
    }
    
    func goToVocabBank() {
        currentScreen = .vocabBank
    }
    
    // MARK: - Generate Sentence
    func generateSentence(for topic: Topic) async {
        selectedTopic = topic
        isLoading = true
        errorMessage = nil

        do {
            let sentence = try await openAI.generateSentence(
                topic: topic.id,
                targetBand: targetBand.label
            )
            currentSentence = sentence
            currentScreen = .translate
        } catch {
            handleError(error)
            // Use varied fallback sentence based on topic
            currentSentence = getFallbackSentence(for: topic)
            currentScreen = .translate
        }

        isLoading = false
    }

    // Track used fallback indices to avoid repetition
    private var usedFallbackIndices: [String: Set<Int>] = [:]

    private func getFallbackSentence(for topic: Topic) -> Sentence {
        let fallbacks = fallbackSentences[topic.id] ?? fallbackSentences["daily_life"]!

        // Get unused index
        var usedIndices = usedFallbackIndices[topic.id] ?? []
        if usedIndices.count >= fallbacks.count {
            usedIndices.removeAll() // Reset when all used
        }

        var randomIndex: Int
        repeat {
            randomIndex = Int.random(in: 0..<fallbacks.count)
        } while usedIndices.contains(randomIndex) && usedIndices.count < fallbacks.count

        usedIndices.insert(randomIndex)
        usedFallbackIndices[topic.id] = usedIndices

        let (vietnamese, hint, structures) = fallbacks[randomIndex]
        return Sentence(
            vietnamese: vietnamese,
            topic: topic.id,
            targetBand: targetBand.label,
            hint: hint,
            keyStructures: structures
        )
    }

    // Varied fallback sentences by topic
    private let fallbackSentences: [String: [(String, String, [String])]] = [
        "work_career": [
            ("Sau một ngày làm việc căng thẳng, tôi chỉ muốn về nhà nghỉ ngơi và thư giãn.", "Sử dụng các phrasal verbs và từ vựng nâng cao", ["After + V-ing", "compound sentence"]),
            ("Sếp tôi vừa thông báo rằng công ty sẽ tuyển thêm nhân viên mới vào tháng tới.", "Sử dụng reported speech và future tense", ["reported speech", "future plans"]),
            ("Tôi đang cân nhắc chuyển sang một công việc mới vì muốn có nhiều cơ hội phát triển hơn.", "Sử dụng present continuous cho kế hoạch tương lai", ["present continuous", "reason clause"]),
            ("Dự án này đòi hỏi sự phối hợp chặt chẽ giữa các phòng ban khác nhau.", "Sử dụng passive voice và formal vocabulary", ["passive voice", "require + noun"]),
            ("Làm việc từ xa có nhiều ưu điểm nhưng đôi khi tôi cảm thấy thiếu sự kết nối với đồng nghiệp.", "Sử dụng contrast clause và expressing feelings", ["although/but", "feel + adjective"])
        ],
        "health_wellness": [
            ("Bác sĩ khuyên tôi nên tập thể dục đều đặn và ăn uống lành mạnh hơn.", "Sử dụng reported speech và modal verbs", ["advise + to-infinitive", "comparative"]),
            ("Mỗi sáng tôi đều dành 30 phút để thiền định và cảm thấy tâm trạng tốt hơn nhiều.", "Sử dụng time expressions và result clause", ["every + time", "feel + comparative"]),
            ("Căng thẳng kéo dài có thể ảnh hưởng nghiêm trọng đến sức khỏe tinh thần và thể chất.", "Sử dụng modal verbs và formal vocabulary", ["can + verb", "affect + noun"]),
            ("Tôi đã bỏ thói quen thức khuya và giờ ngủ đủ 8 tiếng mỗi đêm.", "Sử dụng present perfect và habits", ["have/has + past participle", "time duration"]),
            ("Yoga giúp tôi giảm stress và cải thiện sự linh hoạt của cơ thể đáng kể.", "Sử dụng verb + object + infinitive", ["help + infinitive", "improve + noun"])
        ],
        "relationships": [
            ("Mối quan hệ giữa tôi và gia đình ngày càng gắn bó hơn kể từ khi chúng tôi bắt đầu ăn tối cùng nhau mỗi ngày.", "Sử dụng comparatives và time clauses", ["more and more", "since + clause"]),
            ("Bạn thân của tôi luôn ở bên cạnh và ủng hộ tôi trong những lúc khó khăn.", "Sử dụng present simple và prepositions", ["always + verb", "support + in"]),
            ("Đôi khi việc giao tiếp hiệu quả còn quan trọng hơn cả việc có cùng quan điểm.", "Sử dụng comparatives và abstract nouns", ["more important than", "effective + noun"]),
            ("Chúng tôi đã quen nhau hơn 10 năm và vẫn giữ liên lạc thường xuyên.", "Sử dụng present perfect continuous", ["have known", "keep in touch"]),
            ("Sự tin tưởng là nền tảng quan trọng nhất trong bất kỳ mối quan hệ nào.", "Sử dụng superlatives và abstract concepts", ["the most important", "foundation of"])
        ],
        "travel": [
            ("Chuyến du lịch Đà Nẵng năm ngoái là một trong những trải nghiệm đáng nhớ nhất của tôi.", "Sử dụng superlatives và past tense", ["one of the most", "past simple"]),
            ("Tôi thích khám phá văn hóa địa phương hơn là chỉ tham quan các điểm du lịch nổi tiếng.", "Sử dụng prefer và comparisons", ["prefer + V-ing", "rather than"]),
            ("Nếu có cơ hội, tôi muốn đi du lịch vòng quanh châu Âu trong vài tháng.", "Sử dụng conditional và wishes", ["if + clause", "would like to"]),
            ("Việc lên kế hoạch trước giúp chuyến đi của chúng tôi suôn sẻ và tiết kiệm hơn.", "Sử dụng gerund as subject và comparatives", ["V-ing as subject", "more + adjective"]),
            ("Tôi luôn mang theo máy ảnh để ghi lại những khoảnh khắc đẹp trong mỗi chuyến đi.", "Sử dụng purpose clause và present simple habits", ["to + infinitive", "in order to"])
        ],
        "daily_life": [
            ("Mỗi buổi sáng tôi thức dậy lúc 6 giờ để có đủ thời gian chuẩn bị trước khi đi làm.", "Sử dụng time expressions và purpose clause", ["every morning", "in order to"]),
            ("Cuối tuần tôi thường dành thời gian dọn dẹp nhà cửa và nấu những món ăn ngon.", "Sử dụng frequency adverbs và parallel structure", ["usually", "and + V-ing"]),
            ("Gần đây tôi đang cố gắng giảm thời gian sử dụng điện thoại và đọc sách nhiều hơn.", "Sử dụng present continuous và try to", ["recently", "try to + verb"]),
            ("Việc đi làm về muộn khiến tôi không có nhiều thời gian cho bản thân.", "Sử dụng gerund as subject và make/let", ["V-ing makes", "have time for"]),
            ("Tôi đã tập được thói quen đọc sách trước khi đi ngủ và thấy ngủ ngon hơn nhiều.", "Sử dụng present perfect và result", ["have developed", "find + adjective"])
        ]
    ]
    
    // MARK: - Submit Translation
    func submitTranslation() async {
        guard !userTranslation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let sentence = currentSentence else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await openAI.getFeedback(
                vietnamese: sentence.vietnamese,
                translation: userTranslation,
                targetBand: targetBand.label
            )
            feedback = result
            
            // Update stats
            stats.totalScore += result.overallBand
            stats.sentenceCount += 1
            updateStreak()
            
            currentScreen = .feedback
        } catch {
            handleError(error)
            // Use fallback feedback
            feedback = createFallbackFeedback()
            currentScreen = .feedback
        }
        
        isLoading = false
    }
    
    // MARK: - Next Sentence
    func nextSentence() async {
        guard let topic = selectedTopic else { return }
        userTranslation = ""
        feedback = nil
        await generateSentence(for: topic)
    }
    
    // MARK: - Vocab Bank
    func addToVocabBank(upgrade: Upgrade) {
        for alternative in upgrade.alternatives {
            let item = VocabItem(
                from: alternative,
                original: upgrade.original,
                context: upgrade.context
            )
            
            // Avoid duplicates
            if !vocabBank.contains(where: { $0.word == item.word }) {
                vocabBank.append(item)
            }
        }
        saveVocabBank()
    }
    
    func removeFromVocabBank(at offsets: IndexSet) {
        vocabBank.remove(atOffsets: offsets)
        saveVocabBank()
    }
    
    // MARK: - Spaced Repetition
    func updateVocabReview(id: UUID, correct: Bool) {
        guard let index = vocabBank.firstIndex(where: { $0.id == id }) else { return }
        
        var item = vocabBank[index]
        
        if correct {
            // Increase interval: 1 day -> 3 days -> 7 days -> 14 days -> 30 days
            let currentInterval = item.nextReview.timeIntervalSince(item.addedAt)
            let dayInSeconds: TimeInterval = 24 * 60 * 60
            
            let newInterval: TimeInterval
            switch currentInterval {
            case ..<(2 * dayInSeconds):
                newInterval = 3 * dayInSeconds
            case ..<(4 * dayInSeconds):
                newInterval = 7 * dayInSeconds
            case ..<(10 * dayInSeconds):
                newInterval = 14 * dayInSeconds
            case ..<(20 * dayInSeconds):
                newInterval = 30 * dayInSeconds
            default:
                newInterval = 60 * dayInSeconds
                item.mastered = true
            }
            
            item.nextReview = Date().addingTimeInterval(newInterval)
        } else {
            // Reset to 1 day
            item.nextReview = Date().addingTimeInterval(24 * 60 * 60)
            item.mastered = false
        }
        
        vocabBank[index] = item
        saveVocabBank()
    }
    
    var dueForReviewCount: Int {
        vocabBank.filter { $0.nextReview <= Date() }.count
    }
    
    var masteredCount: Int {
        vocabBank.filter { $0.mastered }.count
    }
    
    var sortedVocabBank: [VocabItem] {
        vocabBank.sorted { item1, item2 in
            let band1 = Double(item1.bandLevel.replacingOccurrences(of: "+", with: "")) ?? 6.0
            let band2 = Double(item2.bandLevel.replacingOccurrences(of: "+", with: "")) ?? 6.0
            return band1 > band2
        }
    }
    
    // MARK: - Persistence
    private func loadData() {
        // Load vocab bank
        if let data = userDefaults.data(forKey: vocabBankKey),
           let decoded = try? JSONDecoder().decode([VocabItem].self, from: data) {
            vocabBank = decoded
        }
        
        // Load stats
        if let data = userDefaults.data(forKey: statsKey),
           let decoded = try? JSONDecoder().decode(UserStats.self, from: data) {
            stats = decoded
        }
    }
    
    private func saveVocabBank() {
        if let encoded = try? JSONEncoder().encode(vocabBank) {
            userDefaults.set(encoded, forKey: vocabBankKey)
        }
    }
    
    private func saveStats() {
        if let encoded = try? JSONEncoder().encode(stats) {
            userDefaults.set(encoded, forKey: statsKey)
        }
    }
    
    private func updateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let lastActive = stats.lastActiveDate else {
            // First time user - start streak at 1
            stats.streak = 1
            stats.lastActiveDate = Date()
            saveStats()
            return
        }

        let lastActiveDay = calendar.startOfDay(for: lastActive)
        let daysSinceLastActive = calendar.dateComponents([.day], from: lastActiveDay, to: today).day ?? 0

        if daysSinceLastActive == 0 {
            // Same day - keep streak unchanged, but ensure it's at least 1
            if stats.streak == 0 {
                stats.streak = 1
            }
        } else if daysSinceLastActive == 1 {
            // Consecutive day - increment streak
            stats.streak += 1
        } else {
            // Missed days - reset streak to 1 (starting fresh today)
            stats.streak = 1
        }

        stats.lastActiveDate = Date()
        saveStats()
    }
    
    // MARK: - Error Handling
    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
        print("Error: \(error)")
    }
    
    // MARK: - Fallback
    private func createFallbackFeedback() -> Feedback {
        Feedback(
            overallBand: 6.0,
            criteria: CriteriaScores(
                lexicalResource: CriteriaScore(band: 5.5, comment: "Basic vocabulary, lacks variety"),
                grammaticalRange: CriteriaScore(band: 6.0, comment: "Correct but simple structures"),
                coherence: CriteriaScore(band: 6.5, comment: "Clear and logical flow"),
                taskAchievement: CriteriaScore(band: 6.0, comment: "Meaning conveyed but could be more precise")
            ),
            goodPoints: ["Correct basic grammar", "Clear meaning"],
            issues: [Issue(word: "tired", criterion: "lexicalResource", reason: "Basic vocabulary")],
            upgrades: [
                Upgrade(
                    original: "tired",
                    context: "feel tired",
                    alternatives: [
                        Alternative(word: "drained", pos: "adj", meaning: "extremely tired", example: "I feel drained", meaningVi: "kiệt sức", bandLevel: "7.0+"),
                        Alternative(word: "exhausted", pos: "adj", meaning: "very tired", example: "I'm exhausted", meaningVi: "kiệt lực", bandLevel: "6.5+")
                    ]
                )
            ],
            improvedSentence: "After a hectic day at work, I simply yearn to return home and unwind.",
            explanation: "Sử dụng từ vựng nâng cao và cấu trúc câu phức tạp hơn để đạt band cao."
        )
    }
}

// MARK: - Helpers
extension AppViewModel {
    static func bandColor(for band: Double) -> Color {
        switch band {
        case 8.0...: return Color(hex: "10B981")
        case 7.0..<8.0: return Color(hex: "3B82F6")
        case 6.0..<7.0: return Color(hex: "F59E0B")
        case 5.0..<6.0: return Color(hex: "F97316")
        default: return Color(hex: "EF4444")
        }
    }
    
    static func bandLabel(for band: Double) -> String {
        switch band {
        case 8.5...: return "Expert User"
        case 8.0..<8.5: return "Very Good User"
        case 7.0..<8.0: return "Good User"
        case 6.0..<7.0: return "Competent User"
        case 5.0..<6.0: return "Modest User"
        default: return "Limited User"
        }
    }
}
