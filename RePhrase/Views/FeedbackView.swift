import SwiftUI

struct FeedbackView: View {
    @EnvironmentObject var viewModel: AppViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Score Section
                if let feedback = viewModel.feedback {
                    ScoreSection(band: feedback.overallBand)
                    
                    // Criteria Breakdown
                    CriteriaSection(criteria: feedback.criteria)
                    
                    // Your Translation
                    YourTranslationSection(translation: viewModel.userTranslation)
                    
                    // Good Points
                    if !feedback.goodPoints.isEmpty {
                        GoodPointsSection(points: feedback.goodPoints)
                    }
                    
                    // Issues
                    if !feedback.issues.isEmpty {
                        IssuesSection(issues: feedback.issues)
                    }
                    
                    // Upgrades
                    if !feedback.upgrades.isEmpty {
                        UpgradesSection(upgrades: feedback.upgrades) { upgrade in
                            viewModel.addToVocabBank(upgrade: upgrade)
                        }
                    }
                    
                    // Improved Sentence
                    ImprovedSection(
                        sentence: feedback.improvedSentence,
                        explanation: feedback.explanation
                    )
                    
                    // Action Buttons
                    ActionButtons(
                        onNext: {
                            Task {
                                await viewModel.nextSentence()
                            }
                        },
                        onHome: {
                            viewModel.goHome()
                        }
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
    }
}

// MARK: - Score Section
struct ScoreSection: View {
    let band: Double
    
    var body: some View {
        VStack(spacing: 16) {
            // Score Circle
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppViewModel.bandColor(for: band), AppViewModel.bandColor(for: band).opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 130, height: 130)
                    .shadow(color: AppViewModel.bandColor(for: band).opacity(0.3), radius: 20, y: 10)
                
                VStack(spacing: 2) {
                    Text(String(format: "%.1f", band))
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(.white)
                    Text("IELTS Band")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .textCase(.uppercase)
                        .tracking(2)
                }
            }
            
            // Band Label
            Text(AppViewModel.bandLabel(for: band))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppViewModel.bandColor(for: band))
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(AppViewModel.bandColor(for: band).opacity(0.15))
                .clipShape(Capsule())
        }
    }
}

// MARK: - Criteria Section
struct CriteriaSection: View {
    let criteria: CriteriaScores
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "📊", title: "Band Breakdown")
            
            VStack(spacing: 12) {
                CriteriaCard(key: "lexicalResource", score: criteria.lexicalResource)
                CriteriaCard(key: "grammaticalRange", score: criteria.grammaticalRange)
                CriteriaCard(key: "coherence", score: criteria.coherence)
                CriteriaCard(key: "taskAchievement", score: criteria.taskAchievement)
            }
        }
    }
}

// MARK: - Criteria Card
struct CriteriaCard: View {
    let key: String
    let score: CriteriaScore
    
    private var label: CriteriaLabel? {
        CriteriaLabel.all[key]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text(label?.icon ?? "📝")
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(label?.label ?? key)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    Text(label?.desc ?? "")
                        .font(.caption)
                        .foregroundColor(AppTheme.textMuted)
                }
                
                Spacer()
                
                Text(String(format: "%.1f", score.band))
                    .font(.title3.weight(.bold))
                    .foregroundColor(AppViewModel.bandColor(for: score.band))
            }
            
            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(AppViewModel.bandColor(for: score.band))
                        .frame(width: geo.size.width * (score.band / 9), height: 6)
                }
            }
            .frame(height: 6)
            
            Text(score.comment)
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
                .italic()
        }
        .padding(16)
        .cardStyle()
    }
}

// MARK: - Your Translation Section
struct YourTranslationSection: View {
    let translation: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "📝", title: "Your Translation")
            
            Text(translation)
                .font(.body)
                .foregroundColor(AppTheme.textPrimary)
                .lineSpacing(4)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
        }
    }
}

// MARK: - Good Points Section
struct GoodPointsSection: View {
    let points: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "✓", title: "Strengths")
            
            VStack(spacing: 8) {
                ForEach(points, id: \.self) { point in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppTheme.success)
                            .font(.caption)
                        Text(point)
                            .font(.subheadline)
                            .foregroundColor(AppTheme.success)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(AppTheme.success.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppTheme.success.opacity(0.2), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

// MARK: - Issues Section
struct IssuesSection: View {
    let issues: [Issue]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "⚠", title: "Areas to Improve")
            
            VStack(spacing: 8) {
                ForEach(issues) { issue in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text(issue.word)
                                .font(.caption.monospaced())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            
                            if let label = CriteriaLabel.all[issue.criterion] {
                                Text(label.label)
                                    .font(.system(size: 10))
                                    .foregroundColor(AppTheme.textMuted)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                        
                        Text(issue.reason)
                            .font(.subheadline)
                    }
                    .foregroundColor(AppTheme.warning)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(AppTheme.warning.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppTheme.warning.opacity(0.2), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

// MARK: - Upgrades Section
struct UpgradesSection: View {
    let upgrades: [Upgrade]
    let onAdd: (Upgrade) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "🚀", title: "Vocabulary Upgrades")
            
            ForEach(upgrades) { upgrade in
                UpgradeCard(upgrade: upgrade) {
                    onAdd(upgrade)
                }
            }
        }
    }
}

// MARK: - Upgrade Card
struct UpgradeCard: View {
    let upgrade: Upgrade
    let onAdd: () -> Void
    @State private var added = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Original word
            HStack(spacing: 12) {
                Text(upgrade.original)
                    .font(.subheadline.monospaced())
                    .strikethrough()
                    .foregroundColor(AppTheme.warning)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(AppTheme.warning.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                Text("→")
                    .foregroundColor(AppTheme.textMuted)
            }
            
            // Alternatives
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(upgrade.alternatives) { alt in
                    AlternativeCard(alternative: alt)
                }
            }
            
            // Add button
            Button {
                onAdd()
                added = true
            } label: {
                HStack {
                    Image(systemName: added ? "checkmark" : "plus")
                    Text(added ? "Added to Vocab Bank" : "Add to Vocab Bank")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(added ? AppTheme.success : AppTheme.info)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(added)
        }
        .padding(16)
        .cardStyle()
    }
}

// MARK: - Alternative Card
struct AlternativeCard: View {
    let alternative: Alternative
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(alternative.word)
                    .font(.headline)
                    .foregroundColor(AppTheme.info)
                
                Spacer()
                
                Text(alternative.bandLevel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppViewModel.bandColor(for: Double(alternative.bandLevel.replacingOccurrences(of: "+", with: "")) ?? 6))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppViewModel.bandColor(for: Double(alternative.bandLevel.replacingOccurrences(of: "+", with: "")) ?? 6).opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            
            Text(alternative.pos)
                .font(.system(size: 10))
                .textCase(.uppercase)
                .foregroundColor(AppTheme.textMuted)
            
            Text(alternative.meaningVi)
                .font(.caption)
                .foregroundColor(AppTheme.textPrimary)
            
            Text("\"\(alternative.example)\"")
                .font(.caption)
                .foregroundColor(AppTheme.textMuted)
                .italic()
        }
        .padding(12)
        .background(AppTheme.info.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.info.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Improved Section
struct ImprovedSection: View {
    let sentence: String
    let explanation: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "✨", title: "Band 7.5+ Version")
            
            VStack(alignment: .leading, spacing: 12) {
                Text(sentence)
                    .font(.custom("Georgia", size: 18))
                    .italic()
                    .foregroundColor(.white)
                    .lineSpacing(4)
                
                if !explanation.isEmpty {
                    Text(explanation)
                        .font(.caption)
                        .foregroundColor(Color(hex: "a0b4ff"))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color(hex: "667eea").opacity(0.1), Color(hex: "764ba2").opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: "667eea").opacity(0.2), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Action Buttons
struct ActionButtons: View {
    let onNext: () -> Void
    let onHome: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onNext) {
                HStack {
                    Text("Next Sentence")
                    Image(systemName: "arrow.right")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppTheme.primaryGradient)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            Button(action: onHome) {
                Text("Back to Topics")
                    .font(.headline)
                    .foregroundColor(AppTheme.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.cardBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack(spacing: 6) {
            Text(icon)
            Text(title)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundColor(AppTheme.textSecondary)
        .textCase(.uppercase)
        .tracking(0.5)
    }
}

#Preview {
    FeedbackView()
        .environmentObject({
            let vm = AppViewModel()
            vm.userTranslation = "After a long day at work, I feel tired and want to go home."
            vm.feedback = Feedback(
                overallBand: 6.5,
                criteria: CriteriaScores(
                    lexicalResource: CriteriaScore(band: 6.0, comment: "Adequate vocabulary with some variety"),
                    grammaticalRange: CriteriaScore(band: 6.5, comment: "Good mix of simple and complex sentences"),
                    coherence: CriteriaScore(band: 7.0, comment: "Clear logical flow"),
                    taskAchievement: CriteriaScore(band: 6.5, comment: "Meaning well preserved")
                ),
                goodPoints: ["Correct grammar structure", "Clear meaning conveyed"],
                issues: [Issue(word: "tired", criterion: "lexicalResource", reason: "Too basic for band 7+")],
                upgrades: [
                    Upgrade(
                        original: "tired",
                        context: "feel tired",
                        alternatives: [
                            Alternative(word: "drained", pos: "adj", meaning: "extremely tired", example: "I feel completely drained", meaningVi: "kiệt sức", bandLevel: "7.0+"),
                            Alternative(word: "exhausted", pos: "adj", meaning: "very tired", example: "She was exhausted", meaningVi: "kiệt lực", bandLevel: "6.5+")
                        ]
                    )
                ],
                improvedSentence: "After a hectic day at work, I simply yearn to return home and unwind.",
                explanation: "Sử dụng từ vựng nâng cao hơn để đạt band cao."
            )
            return vm
        }())
        .background(AppTheme.background)
}
