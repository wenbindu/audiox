import SwiftUI
import AppKit

@main
struct AudioXApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel = AppDependencyContainer.buildViewModel()
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup("AudioX") {
            ContentView(viewModel: viewModel, settings: settings)
                .task {
                    viewModel.importLaunchArgumentsIfNeeded()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    viewModel.dispose()
                }
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button(AppText(language: settings.language).openAudioMenu) {
                    viewModel.openFromPicker()
                }
                .keyboardShortcut("o", modifiers: [.command])
            }
        }
    }
}
