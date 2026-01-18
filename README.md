# RePhrase - IELTS Translation Practice App

A SwiftUI iOS app for practicing English translation skills with AI-powered feedback using OpenAI API.

## Features

- 🎯 **Target Band Selection**: Choose your target IELTS band (5.0 - 7.5)
- 📝 **Translation Practice**: Translate Vietnamese sentences to English
- 📊 **IELTS-style Feedback**: Get detailed scoring across 4 criteria:
  - Lexical Resource
  - Grammatical Range & Accuracy
  - Coherence & Cohesion
  - Task Achievement
- 🚀 **Vocabulary Upgrades**: Learn advanced vocabulary alternatives
- 📚 **Vocabulary Bank**: Save and review learned words
- 🔥 **Streak Tracking**: Track your daily practice streak

## Requirements

- iOS 17.0+
- Xcode 15.0+
- OpenAI API Key

## Setup

### 1. Clone/Download the project

### 2. Set up OpenAI API Key

There are two ways to configure your API key:

#### Option A: Xcode Scheme Environment Variable (Recommended for Development)

1. Open the project in Xcode
2. Go to **Product → Scheme → Edit Scheme...**
3. Select **Run** on the left sidebar
4. Go to **Arguments** tab
5. Under **Environment Variables**, click **+** to add:
   - Name: `OPENAI_API_KEY`
   - Value: `your-openai-api-key-here`

#### Option B: Modify the Service Code

If you prefer to hardcode the API key (not recommended for production):

1. Open `Services/OpenAIService.swift`
2. Replace the `apiKey` computed property:

```swift
private var apiKey: String {
    return "your-openai-api-key-here"
}
```

### 3. Build and Run

1. Open `RePhrase.xcodeproj` in Xcode
2. Select your target device/simulator
3. Press **Cmd + R** to build and run

## Project Structure

```
RePhrase/
├── RephraseApp.swift          # App entry point
├── Models/
│   └── Models.swift           # Data models
├── Services/
│   └── OpenAIService.swift    # OpenAI API integration
├── ViewModels/
│   └── AppViewModel.swift     # Main state management
├── Views/
│   ├── ContentView.swift      # Root view with navigation
│   ├── HomeView.swift         # Topic & band selection
│   ├── TranslateView.swift    # Translation input screen
│   ├── FeedbackView.swift     # AI feedback display
│   ├── VocabBankView.swift    # Saved vocabulary list
│   └── Components/
│       └── Theme.swift        # Colors & styling
└── Assets.xcassets/           # App icons & colors
```

## Usage

1. **Select Target Band**: Choose your target IELTS band on the home screen
2. **Pick a Topic**: Select from Work, Health, Relationships, Travel, or Daily Life
3. **Translate**: Write your English translation of the Vietnamese sentence
4. **Review Feedback**: 
   - See your overall band score
   - Review scores for each IELTS criterion
   - Learn from vocabulary upgrade suggestions
5. **Save Vocabulary**: Add useful words to your Vocab Bank for later review

## API Usage

The app uses OpenAI's `gpt-4o` model for:
- Generating Vietnamese sentences based on topic and target band
- Evaluating translations with IELTS-style scoring
- Suggesting vocabulary upgrades

## Customization

### Change AI Model

In `OpenAIService.swift`, modify the `model` parameter:

```swift
let body: [String: Any] = [
    "model": "gpt-4o-mini",  // or other OpenAI model
    ...
]
```

### Add More Topics

In `Models.swift`, add to the `Topic.all` array:

```swift
static let all: [Topic] = [
    // existing topics...
    Topic(id: "education", label: "Education", icon: "📚", color: "9B59B6"),
]
```

## License

MIT License - Feel free to use and modify for your own projects.

## Support

For issues or feature requests, please create an issue in the repository.
