import SwiftUI

struct HomeView: View {
    @EnvironmentObject var viewModel: AppViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Logo Section
                VStack(spacing: 8) {
                    Text("RePhrase")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "667eea"), Color(hex: "764ba2"), Color(hex: "f093fb")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("Transform your English, one sentence at a time")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .padding(.top, 20)
                
                // Stats Row
                StatsRow(stats: viewModel.stats, vocabCount: viewModel.vocabBank.count)
                    .onTapGesture {
                        viewModel.goToVocabBank()
                    }
                
                // Band Selector
                BandSelector(selectedBand: $viewModel.targetBand)
                
                // Topics
                VStack(alignment: .leading, spacing: 14) {
                    Text("Choose a Topic")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(Topic.all) { topic in
                            TopicCard(topic: topic) {
                                Task {
                                    await viewModel.generateSentence(for: topic)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Stats Row
struct StatsRow: View {
    let stats: UserStats
    let vocabCount: Int
    
    var body: some View {
        HStack(spacing: 10) {
            StatCard(icon: "🔥", value: "\(stats.streak)", label: "Day Streak")
            StatCard(icon: "📝", value: "\(stats.sentenceCount)", label: "Sentences")
            StatCard(icon: "⭐", value: stats.sentenceCount > 0 ? String(format: "%.1f", stats.averageBand) : "—", label: "Avg Band")
            
            // Vocab Bank Card (highlighted)
            VStack(spacing: 4) {
                Text("📚")
                    .font(.title3)
                Text("\(vocabCount)")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text("Vocab Bank")
                    .font(.system(size: 9))
                    .textCase(.uppercase)
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.primaryGradient)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(icon)
                .font(.title3)
            Text(value)
                .font(.title2.bold())
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 9))
                .textCase(.uppercase)
                .foregroundColor(AppTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .cardStyle()
    }
}

// MARK: - Band Selector
struct BandSelector: View {
    @Binding var selectedBand: TargetBand
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TARGET BAND")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textMuted)
                .tracking(0.5)
            
            HStack(spacing: 8) {
                ForEach(TargetBand.all) { band in
                    BandButton(
                        band: band,
                        isSelected: selectedBand.id == band.id
                    ) {
                        selectedBand = band
                    }
                }
            }
        }
    }
}

// MARK: - Band Button
struct BandButton: View {
    let band: TargetBand
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(band.label)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text(band.desc)
                    .font(.system(size: 9))
                    .textCase(.uppercase)
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isSelected ? AppTheme.primaryGradient : LinearGradient(colors: [AppTheme.cardBackground], startPoint: .top, endPoint: .bottom)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : AppTheme.cardBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Topic Card
struct TopicCard: View {
    let topic: Topic
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(topic.icon)
                    .font(.system(size: 32))
                Text(topic.label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.horizontal, 16)
            .background(AppTheme.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(AppTheme.cardBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(hex: topic.color))
                    .frame(height: 3)
                    .opacity(0.7)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView()
        .environmentObject(AppViewModel())
        .background(AppTheme.background)
}
