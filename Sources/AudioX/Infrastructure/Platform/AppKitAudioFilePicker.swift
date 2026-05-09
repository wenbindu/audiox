import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class AppKitAudioFilePicker: AudioFilePickerPort {
    func pickAudioFiles() async -> [URL] {
        await withCheckedContinuation { continuation in
            let panel = NSOpenPanel()
            panel.canChooseFiles = true
            panel.allowsMultipleSelection = true
            panel.canChooseDirectories = true
            panel.allowsOtherFileTypes = true
            var contentTypes: [UTType] = [.audio]
            for ext in AudioFormat.supportedFileExtensions {
                if let type = UTType(filenameExtension: ext) {
                    contentTypes.append(type)
                }
            }
            panel.allowedContentTypes = Array(Set(contentTypes))

            panel.begin { response in
                if response == .OK {
                    continuation.resume(returning: panel.urls)
                } else {
                    continuation.resume(returning: [])
                }
            }
        }
    }
}

extension Notification.Name {
    static let audioXOpenFromFinder = Notification.Name("AudioX.openFromFinder")
}
