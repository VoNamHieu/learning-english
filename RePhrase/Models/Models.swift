import Foundation

// MARK: - Topic
struct Topic: Identifiable, Hashable {
    let id: String
    let label: String
    let icon: String
    let color: String
    
    static let all: [Topic] = [
        // Core IELTS Topics
        Topic(id: "work", label: "Work & Career", icon: "💼", color: "FF6B35"),
        Topic(id: "education", label: "Education", icon: "🎓", color: "6C5CE7"),
        Topic(id: "technology", label: "Technology", icon: "💻", color: "00B894"),
        Topic(id: "environment", label: "Environment", icon: "🌍", color: "00CEC9"),
        Topic(id: "health", label: "Health & Wellness", icon: "🌿", color: "2EC4B6"),

        // Social & Lifestyle
        Topic(id: "relationships", label: "Relationships", icon: "💬", color: "E63946"),
        Topic(id: "travel", label: "Travel & Adventure", icon: "✈️", color: "457B9D"),
        Topic(id: "daily", label: "Daily Life", icon: "☀️", color: "F4A261"),
        Topic(id: "food", label: "Food & Cuisine", icon: "🍜", color: "FDCB6E"),
        Topic(id: "sports", label: "Sports & Fitness", icon: "⚽", color: "E17055"),

        // Culture & Society
        Topic(id: "culture", label: "Culture & Traditions", icon: "🎭", color: "A29BFE"),
        Topic(id: "media", label: "Media & Entertainment", icon: "📺", color: "FD79A8"),
        Topic(id: "social", label: "Social Issues", icon: "🤝", color: "636E72"),
        Topic(id: "urbanization", label: "Cities & Urbanization", icon: "🏙️", color: "74B9FF"),

        // Science & Economy
        Topic(id: "science", label: "Science & Innovation", icon: "🔬", color: "0984E3"),
        Topic(id: "economy", label: "Economy & Business", icon: "📈", color: "00B894"),
        Topic(id: "transport", label: "Transport & Traffic", icon: "🚗", color: "B2BEC3"),

        // Personal Development
        Topic(id: "hobbies", label: "Hobbies & Interests", icon: "🎨", color: "E84393"),
        Topic(id: "family", label: "Family & Home", icon: "🏠", color: "FFEAA7"),
        Topic(id: "shopping", label: "Shopping & Consumerism", icon: "🛒", color: "81ECEC")
    ]
}

// MARK: - Target Band
struct TargetBand: Identifiable, Hashable {
    let id: String
    let value: Double
    let label: String
    let desc: String
    
    static let all: [TargetBand] = [
        TargetBand(id: "5.0", value: 5.0, label: "5.0", desc: "Modest"),
        TargetBand(id: "5.5", value: 5.5, label: "5.5", desc: "Modest+"),
        TargetBand(id: "6.0", value: 6.0, label: "6.0", desc: "Competent"),
        TargetBand(id: "6.5", value: 6.5, label: "6.5", desc: "Competent+"),
        TargetBand(id: "7.0", value: 7.0, label: "7.0", desc: "Good"),
        TargetBand(id: "7.5", value: 7.5, label: "7.5", desc: "Good+")
    ]
}

// MARK: - Sentence
struct Sentence: Codable, Identifiable {
    let id: UUID
    let vietnamese: String
    let topic: String
    let targetBand: String
    let hint: String
    let keyStructures: [String]
    
    init(vietnamese: String, topic: String, targetBand: String, hint: String, keyStructures: [String]) {
        self.id = UUID()
        self.vietnamese = vietnamese
        self.topic = topic
        self.targetBand = targetBand
        self.hint = hint
        self.keyStructures = keyStructures
    }
}

// MARK: - Feedback
struct Feedback: Codable {
    let overallBand: Double
    let criteria: CriteriaScores
    let goodPoints: [String]
    let issues: [Issue]
    let upgrades: [Upgrade]
    let improvedSentence: String
    let explanation: String
}

struct CriteriaScores: Codable {
    let lexicalResource: CriteriaScore
    let grammaticalRange: CriteriaScore
    let coherence: CriteriaScore
    let taskAchievement: CriteriaScore
}

struct CriteriaScore: Codable {
    let band: Double
    let comment: String
}

struct Issue: Codable, Identifiable {
    var id: String { word + criterion }
    let word: String
    let criterion: String
    let reason: String
}

struct Upgrade: Codable, Identifiable {
    var id: String { original }
    let original: String
    let context: String
    let alternatives: [Alternative]
}

struct Alternative: Codable, Identifiable {
    var id: String { word }
    let word: String
    let pos: String
    let meaning: String
    let example: String
    let meaningVi: String
    let bandLevel: String
}

// MARK: - Vocabulary Item
struct VocabItem: Codable, Identifiable {
    let id: UUID
    let word: String
    let pos: String
    let meaning: String
    let meaningVi: String
    let example: String
    let original: String
    let context: String
    let bandLevel: String
    let addedAt: Date
    var nextReview: Date
    var mastered: Bool
    
    init(from alternative: Alternative, original: String, context: String) {
        self.id = UUID()
        self.word = alternative.word
        self.pos = alternative.pos
        self.meaning = alternative.meaning
        self.meaningVi = alternative.meaningVi
        self.example = alternative.example
        self.original = original
        self.context = context
        self.bandLevel = alternative.bandLevel
        self.addedAt = Date()
        self.nextReview = Date().addingTimeInterval(24 * 60 * 60)
        self.mastered = false
    }
}

// MARK: - User Stats
struct UserStats: Codable {
    var streak: Int
    var totalScore: Double
    var sentenceCount: Int
    var lastActiveDate: Date?
    
    var averageBand: Double {
        sentenceCount > 0 ? totalScore / Double(sentenceCount) : 0
    }
    
    static let empty = UserStats(streak: 0, totalScore: 0, sentenceCount: 0, lastActiveDate: nil)
}

// MARK: - Criteria Labels
struct CriteriaLabel {
    let label: String
    let icon: String
    let desc: String
    
    static let all: [String: CriteriaLabel] = [
        "lexicalResource": CriteriaLabel(label: "Lexical Resource", icon: "📚", desc: "Vocabulary range & accuracy"),
        "grammaticalRange": CriteriaLabel(label: "Grammatical Range", icon: "✏️", desc: "Grammar variety & accuracy"),
        "coherence": CriteriaLabel(label: "Coherence & Cohesion", icon: "🔗", desc: "Flow & logical connection"),
        "taskAchievement": CriteriaLabel(label: "Task Achievement", icon: "🎯", desc: "Meaning & completeness")
    ]
}
