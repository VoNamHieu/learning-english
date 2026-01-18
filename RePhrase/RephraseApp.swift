import SwiftUI

@main
struct RephraseApp: App {
    @StateObject private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: appViewModel)
                .preferredColorScheme(.dark)
        }
    }
}
