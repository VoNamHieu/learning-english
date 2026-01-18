import SwiftUI

struct VocabBankView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var showReview = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    viewModel.goHome()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textMuted)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            // Title
            VStack(alignment: .leading, spacing: 8) {
                Text("📚 Vocabulary Bank")
                    .font(.title.bold())
                    .foregroundColor(.white)
                
                Text("\(viewModel.vocabBank.count) words collected • \(viewModel.masteredCount) mastered")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            // Review Button
            if !viewModel.vocabBank.isEmpty {
                ReviewButtonCard(
                    dueCount: viewModel.dueForReviewCount,
                    totalCount: viewModel.vocabBank.count,
                    onTap: { showReview = true }
                )
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
            
            // Content
            if viewModel.vocabBank.isEmpty {
                EmptyVocabView()
            } else {
                VocabList(
                    items: viewModel.sortedVocabBank,
                    onDelete: { offsets in
                        viewModel.removeFromVocabBank(at: offsets)
                    }
                )
                .padding(.top, 8)
            }
        }
        .fullScreenCover(isPresented: $showReview) {
            VocabReviewView()
                .environmentObject(viewModel)
        }
    }
}

// MARK: - Review Button Card
struct ReviewButtonCard: View {
    let dueCount: Int
    let totalCount: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(AppTheme.primaryGradient)
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "brain.head.profile")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start Review Session")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if dueCount > 0 {
                        Text("\(dueCount) words due for review")
                            .font(.caption)
                            .foregroundColor(AppTheme.warning)
                    } else {
                        Text("Practice all \(totalCount) words")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .foregroundColor(AppTheme.textMuted)
                
                // Badge
                if dueCount > 0 {
                    Text("\(dueCount)")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.warning)
                        .clipShape(Capsule())
                }
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [Color(hex: "667eea").opacity(0.15), Color(hex: "764ba2").opacity(0.15)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: "667eea").opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty State
struct EmptyVocabView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Text("📖")
                .font(.system(size: 48))
            
            Text("No vocabulary yet!")
                .font(.headline)
                .foregroundColor(AppTheme.textSecondary)
            
            Text("Complete translations and add words to build your collection.")
                .font(.subheadline)
                .foregroundColor(AppTheme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }
}

// MARK: - Vocab List
struct VocabList: View {
    let items: [VocabItem]
    let onDelete: (IndexSet) -> Void
    
    var body: some View {
        List {
            ForEach(items) { item in
                VocabItemCard(item: item)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 24, bottom: 6, trailing: 24))
            }
            .onDelete(perform: onDelete)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Vocab Item Card
struct VocabItemCard: View {
    let item: VocabItem
    
    private var reviewStatus: (text: String, color: Color) {
        if item.mastered {
            return ("Mastered ✓", AppTheme.success)
        } else if item.nextReview <= Date() {
            return ("Due for review", AppTheme.warning)
        } else {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: item.nextReview).day ?? 0
            return ("Review in \(days)d", AppTheme.textMuted)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Text(item.word)
                    .font(.title3.bold())
                    .foregroundColor(AppTheme.info)
                
                Text(item.pos)
                    .font(.system(size: 10))
                    .textCase(.uppercase)
                    .foregroundColor(AppTheme.textMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                
                Spacer()
                
                Text("Band \(item.bandLevel)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppViewModel.bandColor(for: Double(item.bandLevel.replacingOccurrences(of: "+", with: "")) ?? 6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppViewModel.bandColor(for: Double(item.bandLevel.replacingOccurrences(of: "+", with: "")) ?? 6).opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            
            // Meaning
            Text(item.meaningVi.isEmpty ? item.meaning : item.meaningVi)
                .font(.subheadline)
                .foregroundColor(AppTheme.textPrimary)
            
            // Example
            Text("\"\(item.example)\"")
                .font(.caption)
                .foregroundColor(AppTheme.textMuted)
                .italic()
            
            // Meta
            HStack {
                HStack(spacing: 4) {
                    Text("Replaces:")
                        .foregroundColor(AppTheme.textMuted)
                    
                    Text(item.original)
                        .font(.caption.monospaced())
                        .foregroundColor(AppTheme.warning)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.warning.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                
                Spacer()
                
                // Review status
                Text(reviewStatus.text)
                    .font(.caption)
                    .foregroundColor(reviewStatus.color)
            }
            .font(.caption)
            .padding(.top, 4)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 1)
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(item.mastered ? AppTheme.success.opacity(0.3) : AppTheme.cardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    VocabBankView()
        .environmentObject({
            let vm = AppViewModel()
            vm.vocabBank = [
                VocabItem(
                    from: Alternative(
                        word: "drained",
                        pos: "adj",
                        meaning: "extremely tired",
                        example: "I feel completely drained",
                        meaningVi: "kiệt sức",
                        bandLevel: "7.0+"
                    ),
                    original: "tired",
                    context: "feel tired"
                ),
                VocabItem(
                    from: Alternative(
                        word: "exhausted",
                        pos: "adj",
                        meaning: "very tired",
                        example: "She was exhausted from work",
                        meaningVi: "kiệt lực",
                        bandLevel: "6.5+"
                    ),
                    original: "tired",
                    context: "feel tired"
                )
            ]
            return vm
        }())
        .background(AppTheme.background)
}
