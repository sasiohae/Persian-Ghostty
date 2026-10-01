import SwiftUI

@main
struct GhosttyPersianApp: App {
    @State private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup("Ghostty Persian") {
            MainView()
                .environment(viewModel)
        }
        .windowResizability(.contentSize)
    }
}
