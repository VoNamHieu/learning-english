import SwiftUI

struct TranslateView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Back Button
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
                .padding(.bottom, 16)
                
                // Challenge Card
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        if let topic = viewModel.selectedTopic {
                            Text("\(topic.icon) \(topic.label)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(Color(hex: "a0b4ff"))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(hex: "667eea").opacity(0.2))
                                .clipShape(Capsule())
                        }
                        
                        Spacer()
                        
                        Text("Target: Band \(viewModel.targetBand.label)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(AppTheme.primaryGradient)
                            .clipShape(Capsule())
                    }
                    
                    // Title
                    Text("Translate this sentence")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Vietnamese Sentence
                    if let sentence = viewModel.currentSentence {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(sentence.vietnamese)
                                .font(.custom("Georgia", size: 18))
                                .italic()
                                .foregroundColor(.white)
                                .lineSpacing(4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
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
                        
                        // Hint
                        if !sentence.hint.isEmpty {
                            HStack(spacing: 8) {
                                Text("💡")
                                Text(sentence.hint)
                                    .font(.subheadline)
                                    .foregroundColor(Color(hex: "F4A261"))
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(hex: "F4A261").opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "F4A261").opacity(0.2), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    
                    // Translation Input
                    VStack(alignment: .leading, spacing: 8) {
                        TextEditor(text: $viewModel.userTranslation)
                            .scrollContentBackground(.hidden)
                            .font(.body)
                            .foregroundColor(.white)
                            .frame(minHeight: 120)
                            .padding(16)
                            .background(Color.black.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        isTextFieldFocused ? Color(hex: "667eea").opacity(0.5) : Color.white.opacity(0.1),
                                        lineWidth: 2
                                    )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .focused($isTextFieldFocused)
                            .overlay(alignment: .topLeading) {
                                if viewModel.userTranslation.isEmpty {
                                    Text("Type your English translation here...")
                                        .foregroundColor(AppTheme.textMuted)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 24)
                                        .allowsHitTesting(false)
                                }
                            }
                    }
                    
                    // Submit Button
                    Button {
                        isTextFieldFocused = false
                        Task {
                            await viewModel.submitTranslation()
                        }
                    } label: {
                        HStack {
                            Text(viewModel.isLoading ? "Analyzing..." : "Submit Translation")
                            if !viewModel.isLoading {
                                Image(systemName: "checkmark")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.primaryGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .opacity(viewModel.userTranslation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                    }
                    .disabled(viewModel.userTranslation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
                }
                .padding(24)
                .cardStyle()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
    }
}

#Preview {
    TranslateView()
        .environmentObject({
            let vm = AppViewModel()
            vm.selectedTopic = Topic.all[0]
            vm.currentSentence = Sentence(
                vietnamese: "Sau một ngày làm việc căng thẳng, tôi chỉ muốn về nhà nghỉ ngơi và thư giãn.",
                topic: "work",
                targetBand: "6.5",
                hint: "Sử dụng các phrasal verbs và từ vựng nâng cao",
                keyStructures: ["After + V-ing"]
            )
            return vm
        }())
        .background(AppTheme.background)
}
