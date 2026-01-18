import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        ZStack {
            // Background
            AppTheme.background
                .ignoresSafeArea()

            // Content
            Group {
                switch viewModel.currentScreen {
                case .home:
                    HomeView()
                case .translate:
                    TranslateView()
                case .feedback:
                    FeedbackView()
                case .vocabBank:
                    VocabBankView()
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.currentScreen)

            // Loading overlay
            if viewModel.isLoading {
                LoadingOverlay()
            }
        }
        .environmentObject(viewModel)
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
    }
}

// MARK: - Loading Overlay
struct LoadingOverlay: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Color(hex: "1a1a2e").opacity(0.9)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
                
                Text("AI is thinking...")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textMuted)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    ContentView(viewModel: AppViewModel())
}
