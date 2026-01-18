import SwiftUI

// MARK: - Review Mode
enum ReviewMode: String, CaseIterable {
    case flashcard = "Flashcard"
    case fillBlank = "Fill Blank"
    case multipleChoice = "Multiple Choice"
    
    var icon: String {
        switch self {
        case .flashcard: return "rectangle.on.rectangle.angled"
        case .fillBlank: return "text.cursor"
        case .multipleChoice: return "list.bullet.circle"
        }
    }
}

// MARK: - Review Session State
struct ReviewSession {
    var currentIndex: Int = 0
    var correctCount: Int = 0
    var wrongCount: Int = 0
    var reviewedItems: Set<UUID> = []
    var isComplete: Bool = false
}

// MARK: - Vocab Review View
struct VocabReviewView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedMode: ReviewMode = .flashcard
    @State private var session = ReviewSession()
    @State private var itemsToReview: [VocabItem] = []
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                ReviewHeader(
                    onClose: { dismiss() },
                    progress: progress,
                    correctCount: session.correctCount,
                    totalCount: itemsToReview.count
                )
                
                if session.isComplete {
                    ReviewCompleteView(
                        correct: session.correctCount,
                        total: itemsToReview.count,
                        onRestart: restartReview,
                        onClose: { dismiss() }
                    )
                } else if itemsToReview.isEmpty {
                    EmptyReviewView(onClose: { dismiss() })
                } else {
                    // Mode Selector
                    ModePicker(selectedMode: $selectedMode)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                    
                    // Review Content
                    TabView(selection: $selectedMode) {
                        FlashcardReviewView(
                            item: currentItem,
                            onCorrect: markCorrect,
                            onWrong: markWrong
                        )
                        .tag(ReviewMode.flashcard)
                        
                        FillBlankReviewView(
                            item: currentItem,
                            onCorrect: markCorrect,
                            onWrong: markWrong
                        )
                        .tag(ReviewMode.fillBlank)
                        
                        MultipleChoiceReviewView(
                            item: currentItem,
                            allItems: itemsToReview,
                            onCorrect: markCorrect,
                            onWrong: markWrong
                        )
                        .tag(ReviewMode.multipleChoice)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
        }
        .onAppear {
            setupReview()
        }
    }
    
    // MARK: - Computed Properties
    private var currentItem: VocabItem {
        guard session.currentIndex < itemsToReview.count else {
            return itemsToReview.first ?? VocabItem(
                from: Alternative(word: "", pos: "", meaning: "", example: "", meaningVi: "", bandLevel: ""),
                original: "",
                context: ""
            )
        }
        return itemsToReview[session.currentIndex]
    }
    
    private var progress: Double {
        guard !itemsToReview.isEmpty else { return 0 }
        return Double(session.currentIndex) / Double(itemsToReview.count)
    }
    
    // MARK: - Methods
    private func setupReview() {
        // Get items due for review (or all if none due)
        let dueItems = viewModel.vocabBank.filter { $0.nextReview <= Date() }
        itemsToReview = dueItems.isEmpty ? Array(viewModel.vocabBank.prefix(10)) : Array(dueItems.prefix(20))
        itemsToReview.shuffle()
    }
    
    private func markCorrect() {
        session.correctCount += 1
        session.reviewedItems.insert(currentItem.id)
        viewModel.updateVocabReview(id: currentItem.id, correct: true)
        moveToNext()
    }
    
    private func markWrong() {
        session.wrongCount += 1
        session.reviewedItems.insert(currentItem.id)
        viewModel.updateVocabReview(id: currentItem.id, correct: false)
        moveToNext()
    }
    
    private func moveToNext() {
        if session.currentIndex + 1 >= itemsToReview.count {
            withAnimation {
                session.isComplete = true
            }
        } else {
            withAnimation {
                session.currentIndex += 1
            }
        }
    }
    
    private func restartReview() {
        session = ReviewSession()
        setupReview()
    }
}

// MARK: - Review Header
struct ReviewHeader: View {
    let onClose: () -> Void
    let progress: Double
    let correctCount: Int
    let totalCount: Int
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.title3)
                        .foregroundColor(AppTheme.textMuted)
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Label("\(correctCount)", systemImage: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.success)
                    
                    Text("\(Int(progress * Double(totalCount)))/\(totalCount)")
                        .foregroundColor(AppTheme.textSecondary)
                }
                .font(.subheadline.weight(.medium))
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppTheme.primaryGradient)
                        .frame(width: geo.size.width * progress)
                        .animation(.spring(response: 0.3), value: progress)
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }
}

// MARK: - Mode Picker
struct ModePicker: View {
    @Binding var selectedMode: ReviewMode
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(ReviewMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedMode = mode
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: mode.icon)
                            .font(.caption)
                        Text(mode.rawValue)
                            .font(.caption.weight(.medium))
                    }
                    .foregroundColor(selectedMode == mode ? .white : AppTheme.textMuted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        selectedMode == mode
                            ? AnyView(AppTheme.primaryGradient)
                            : AnyView(Color.white.opacity(0.05))
                    )
                    .clipShape(Capsule())
                }
            }
        }
    }
}

// MARK: - Flashcard Review
struct FlashcardReviewView: View {
    let item: VocabItem
    let onCorrect: () -> Void
    let onWrong: () -> Void
    
    @State private var isFlipped = false
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Flashcard
            ZStack {
                // Back (meaning)
                FlashcardBack(item: item)
                    .opacity(isFlipped ? 1 : 0)
                    .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
                
                // Front (word)
                FlashcardFront(item: item)
                    .opacity(isFlipped ? 0 : 1)
                    .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
            }
            .frame(height: 320)
            .padding(.horizontal, 24)
            .offset(dragOffset)
            .rotationEffect(.degrees(Double(dragOffset.width / 20)))
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        dragOffset = gesture.translation
                    }
                    .onEnded { gesture in
                        if gesture.translation.width > 100 {
                            // Swipe right - correct
                            withAnimation(.spring()) {
                                dragOffset = CGSize(width: 500, height: 0)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                resetCard()
                                onCorrect()
                            }
                        } else if gesture.translation.width < -100 {
                            // Swipe left - wrong
                            withAnimation(.spring()) {
                                dragOffset = CGSize(width: -500, height: 0)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                resetCard()
                                onWrong()
                            }
                        } else {
                            withAnimation(.spring()) {
                                dragOffset = .zero
                            }
                        }
                    }
            )
            .onTapGesture {
                withAnimation(.spring(response: 0.4)) {
                    isFlipped.toggle()
                }
            }
            
            // Hint
            Text(isFlipped ? "Swipe right if correct, left if wrong" : "Tap to reveal meaning")
                .font(.caption)
                .foregroundColor(AppTheme.textMuted)
            
            Spacer()
            
            // Buttons
            if isFlipped {
                HStack(spacing: 16) {
                    Button {
                        resetCard()
                        onWrong()
                    } label: {
                        HStack {
                            Image(systemName: "xmark")
                            Text("Still Learning")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.warning)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Button {
                        resetCard()
                        onCorrect()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark")
                            Text("Got It!")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.success)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 24)
            }
            
            Spacer()
        }
    }
    
    private func resetCard() {
        isFlipped = false
        dragOffset = .zero
    }
}

// MARK: - Flashcard Front
struct FlashcardFront: View {
    let item: VocabItem
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Text(item.word)
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)
            
            Text(item.pos)
                .font(.caption)
                .textCase(.uppercase)
                .foregroundColor(AppTheme.textMuted)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
            
            Text("Band \(item.bandLevel)")
                .font(.caption.weight(.semibold))
                .foregroundColor(AppViewModel.bandColor(for: Double(item.bandLevel.replacingOccurrences(of: "+", with: "")) ?? 6))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppViewModel.bandColor(for: Double(item.bandLevel.replacingOccurrences(of: "+", with: "")) ?? 6).opacity(0.15))
                .clipShape(Capsule())
            
            Spacer()
            
            Text("Tap to flip")
                .font(.caption)
                .foregroundColor(AppTheme.textMuted)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(hex: "1e1e3f"), Color(hex: "2d2d5a")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    }
}

// MARK: - Flashcard Back
struct FlashcardBack: View {
    let item: VocabItem
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Text(item.meaningVi.isEmpty ? item.meaning : item.meaningVi)
                .font(.title2.weight(.semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Text(item.meaning)
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Divider()
                .background(Color.white.opacity(0.2))
                .padding(.horizontal, 40)
                .padding(.vertical, 8)
            
            VStack(spacing: 8) {
                Text("Example:")
                    .font(.caption)
                    .foregroundColor(AppTheme.textMuted)
                
                Text("\"\(item.example)\"")
                    .font(.subheadline)
                    .italic()
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            Spacer()
            
            HStack {
                Text("Replaces:")
                    .foregroundColor(AppTheme.textMuted)
                Text(item.original)
                    .foregroundColor(AppTheme.warning)
                    .strikethrough()
            }
            .font(.caption)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(hex: "2d4a3e"), Color(hex: "1e3a2f")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(AppTheme.success.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    }
}

// MARK: - Fill Blank Review
struct FillBlankReviewView: View {
    let item: VocabItem
    let onCorrect: () -> Void
    let onWrong: () -> Void
    
    @State private var userInput = ""
    @State private var showResult: Bool? = nil
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Question
            VStack(spacing: 16) {
                Text("Fill in the blank:")
                    .font(.headline)
                    .foregroundColor(AppTheme.textSecondary)
                
                Text(item.meaningVi.isEmpty ? item.meaning : item.meaningVi)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                Text("(\(item.pos))")
                    .font(.caption)
                    .foregroundColor(AppTheme.textMuted)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .cardStyle()
            .padding(.horizontal, 24)
            
            // Input
            VStack(spacing: 12) {
                TextField("Type the word...", text: $userInput)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                showResult == true ? AppTheme.success :
                                showResult == false ? AppTheme.warning :
                                Color.white.opacity(0.1),
                                lineWidth: 2
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .focused($isFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                
                if let result = showResult {
                    HStack {
                        Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                        Text(result ? "Correct!" : "The answer is: \(item.word)")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(result ? AppTheme.success : AppTheme.warning)
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Submit Button
            if showResult == nil {
                Button {
                    checkAnswer()
                } label: {
                    Text("Check Answer")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.primaryGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 24)
                .disabled(userInput.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(userInput.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            } else {
                Button {
                    if showResult == true {
                        onCorrect()
                    } else {
                        onWrong()
                    }
                    resetState()
                } label: {
                    Text("Next Word")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(showResult == true ? AppTheme.success : AppTheme.warning)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 24)
            }
            
            Spacer()
        }
        .onAppear {
            isFocused = true
        }
        .onChange(of: item.id) { _, _ in
            resetState()
            isFocused = true
        }
    }

    private func checkAnswer() {
        let isCorrect = userInput.trimmingCharacters(in: .whitespaces).lowercased() == item.word.lowercased()
        withAnimation {
            showResult = isCorrect
        }
    }
    
    private func resetState() {
        userInput = ""
        showResult = nil
    }
}

// MARK: - Multiple Choice Review
struct MultipleChoiceReviewView: View {
    let item: VocabItem
    let allItems: [VocabItem]
    let onCorrect: () -> Void
    let onWrong: () -> Void
    
    @State private var options: [String] = []
    @State private var selectedAnswer: String? = nil
    @State private var showResult = false
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Question
            VStack(spacing: 16) {
                Text("What does this mean?")
                    .font(.headline)
                    .foregroundColor(AppTheme.textSecondary)
                
                Text(item.word)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                Text("(\(item.pos))")
                    .font(.caption)
                    .foregroundColor(AppTheme.textMuted)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .cardStyle()
            .padding(.horizontal, 24)
            
            // Options
            VStack(spacing: 12) {
                ForEach(options, id: \.self) { option in
                    OptionButton(
                        text: option,
                        isSelected: selectedAnswer == option,
                        isCorrect: showResult && option == (item.meaningVi.isEmpty ? item.meaning : item.meaningVi),
                        isWrong: showResult && selectedAnswer == option && option != (item.meaningVi.isEmpty ? item.meaning : item.meaningVi),
                        action: {
                            if !showResult {
                                selectedAnswer = option
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Submit/Next Button
            if !showResult {
                Button {
                    withAnimation {
                        showResult = true
                    }
                } label: {
                    Text("Check Answer")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.primaryGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 24)
                .disabled(selectedAnswer == nil)
                .opacity(selectedAnswer == nil ? 0.5 : 1)
            } else {
                let isCorrect = selectedAnswer == (item.meaningVi.isEmpty ? item.meaning : item.meaningVi)
                Button {
                    if isCorrect {
                        onCorrect()
                    } else {
                        onWrong()
                    }
                    resetState()
                } label: {
                    Text("Next Word")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isCorrect ? AppTheme.success : AppTheme.warning)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 24)
            }
            
            Spacer()
        }
        .onAppear {
            generateOptions()
        }
        .onChange(of: item.id) { _, _ in
            resetState()
            generateOptions()
        }
    }
    
    private func generateOptions() {
        let correctAnswer = item.meaningVi.isEmpty ? item.meaning : item.meaningVi
        var wrongOptions = allItems
            .filter { $0.id != item.id }
            .map { $0.meaningVi.isEmpty ? $0.meaning : $0.meaningVi }
            .shuffled()
            .prefix(3)
        
        // If not enough options, add some generic ones
        let genericOptions = ["to be very happy", "to feel anxious", "to work hard", "to rest peacefully", "to speak loudly"]
        while wrongOptions.count < 3 {
            if let generic = genericOptions.randomElement(), !wrongOptions.contains(generic) && generic != correctAnswer {
                wrongOptions.append(generic)
            }
        }
        
        options = ([correctAnswer] + wrongOptions).shuffled()
    }
    
    private func resetState() {
        selectedAnswer = nil
        showResult = false
    }
}

// MARK: - Option Button
struct OptionButton: View {
    let text: String
    let isSelected: Bool
    let isCorrect: Bool
    let isWrong: Bool
    let action: () -> Void
    
    var backgroundColor: Color {
        if isCorrect { return AppTheme.success }
        if isWrong { return AppTheme.warning }
        if isSelected { return Color(hex: "667eea").opacity(0.3) }
        return AppTheme.cardBackground
    }
    
    var borderColor: Color {
        if isCorrect { return AppTheme.success }
        if isWrong { return AppTheme.warning }
        if isSelected { return Color(hex: "667eea") }
        return AppTheme.cardBorder
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                if isCorrect {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                } else if isWrong {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding(16)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: isSelected || isCorrect || isWrong ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Review Complete View
struct ReviewCompleteView: View {
    let correct: Int
    let total: Int
    let onRestart: () -> Void
    let onClose: () -> Void
    
    private var percentage: Int {
        guard total > 0 else { return 0 }
        return Int(Double(correct) / Double(total) * 100)
    }
    
    private var message: String {
        switch percentage {
        case 90...100: return "Outstanding! 🌟"
        case 70..<90: return "Great job! 💪"
        case 50..<70: return "Good effort! 📚"
        default: return "Keep practicing! 💪"
        }
    }
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Result Circle
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 12)
                    .frame(width: 160, height: 160)
                
                Circle()
                    .trim(from: 0, to: Double(correct) / Double(max(total, 1)))
                    .stroke(
                        AppTheme.success,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 4) {
                    Text("\(percentage)%")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(.white)
                    Text("\(correct)/\(total)")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            
            Text(message)
                .font(.title2.weight(.bold))
                .foregroundColor(.white)
            
            Text("You've completed this review session!")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
            
            Spacer()
            
            // Buttons
            VStack(spacing: 12) {
                Button(action: onRestart) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Review Again")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.primaryGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Button(action: onClose) {
                    Text("Done")
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
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }
}

// MARK: - Empty Review View
struct EmptyReviewView: View {
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text("📚")
                .font(.system(size: 64))
            
            Text("No words to review")
                .font(.title2.weight(.bold))
                .foregroundColor(.white)
            
            Text("Add vocabulary from your translations to start learning!")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
            
            Button(action: onClose) {
                Text("Go Back")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.primaryGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }
}

#Preview {
    VocabReviewView()
        .environmentObject({
            let vm = AppViewModel()
            vm.vocabBank = [
                VocabItem(
                    from: Alternative(word: "drained", pos: "adj", meaning: "extremely tired", example: "I feel completely drained", meaningVi: "kiệt sức", bandLevel: "7.0+"),
                    original: "tired",
                    context: "feel tired"
                ),
                VocabItem(
                    from: Alternative(word: "exhausted", pos: "adj", meaning: "very tired", example: "She was exhausted", meaningVi: "kiệt lực", bandLevel: "6.5+"),
                    original: "tired",
                    context: "feel tired"
                ),
                VocabItem(
                    from: Alternative(word: "hectic", pos: "adj", meaning: "very busy", example: "a hectic day", meaningVi: "bận rộn", bandLevel: "7.0+"),
                    original: "busy",
                    context: "busy day"
                )
            ]
            return vm
        }())
}
