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
            // Use fallback sentence
            currentSentence = Sentence(
                vietnamese: "Sau một ngày làm việc căng thẳng, tôi chỉ muốn về nhà nghỉ ngơi và thư giãn.",
                topic: topic.id,
                targetBand: targetBand.label,
                hint: "Sử dụng các phrasal verbs và từ vựng nâng cao",
                keyStructures: ["After + V-ing", "compound sentence"]
            )
            currentScreen = .translate
        }
        
        isLoading = false
    }
    
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
            stats.lastActiveDate = Date()
            saveStats()
            
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

    func removeFromVocabBank(id: UUID) {
        vocabBank.removeAll { $0.id == id }
        saveVocabBank()
    }
    
    func updateVocabReview(id: UUID, correct: Bool) {
        guard let index = vocabBank.firstIndex(where: { $0.id == id }) else { return }

        var item = vocabBank[index]
        let dayInSeconds: TimeInterval = 24 * 60 * 60

        if correct {
            // Increase interval: 1 day -> 3 days -> 7 days -> 14 days -> 30 days -> 60 days (mastered)
            let newInterval: TimeInterval
            switch item.reviewInterval {
            case ..<(2 * dayInSeconds):
                newInterval = 3 * dayInSeconds
            case ..<(5 * dayInSeconds):
                newInterval = 7 * dayInSeconds
            case ..<(10 * dayInSeconds):
                newInterval = 14 * dayInSeconds
            case ..<(20 * dayInSeconds):
                newInterval = 30 * dayInSeconds
            default:
                newInterval = 60 * dayInSeconds
                item.mastered = true
            }

            item.reviewInterval = newInterval
            item.nextReview = Date().addingTimeInterval(newInterval)
        } else {
            // Reset to 1 day
            item.reviewInterval = dayInSeconds
            item.nextReview = Date().addingTimeInterval(dayInSeconds)
            item.mastered = false
        }

        item.lastReviewedAt = Date()
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
        guard let lastActive = stats.lastActiveDate else {
            // First time practicing - start streak at 1
            stats.streak = 1
            return
        }

        let calendar = Calendar.current
        let daysSinceLastActive = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastActive), to: calendar.startOfDay(for: Date())).day ?? 0

        if daysSinceLastActive > 1 {
            // Missed a day - reset streak to 1 (today counts)
            stats.streak = 1
        } else if daysSinceLastActive == 1 {
            // Consecutive day - increment streak
            stats.streak += 1
        }
        // daysSinceLastActive == 0 means same day - keep streak unchanged
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
