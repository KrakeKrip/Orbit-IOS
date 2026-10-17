import AVFoundation
import UIKit
import OSLog

/// Shared by every completion entry point, after the store accepts the write.
/// Audio/haptics are optional presentation effects and never affect persistence.
@MainActor
final class OrbitCompletionFeedback {
    static let shared = OrbitCompletionFeedback()
    private let haptic = UINotificationFeedbackGenerator()
    private var player: AVAudioPlayer?
    private let log = Logger(subsystem: "local.orbit.ios", category: "CompletionFeedback")

    func completed() {
        if OrbitHaptics.enabled {
            haptic.notificationOccurred(.success)
        }
        guard UserDefaults.standard.object(forKey: "orbit.ui.completionSound") as? Bool ?? true else { return }
        do {
            // Ambient mixes with other audio and respects iPhone Silent mode.
            try AVAudioSession.sharedInstance().setCategory(.ambient)
            if player == nil {
                guard let url = Bundle.main.url(forResource: "orbit-complete", withExtension: "wav") else {
                    throw CocoaError(.fileNoSuchFile)
                }
                player = try AVAudioPlayer(contentsOf: url)
                player?.volume = 0.85
            }
            player?.currentTime = 0
            let started = player?.play() == true
            log.notice("Completion audio started: \(started)")
        } catch {
            // The task is already saved. An optional sound must not report a
            // false task-save failure or roll back a successful completion.
            log.error("Completion audio unavailable: \(error.localizedDescription, privacy: .public)")
        }
    }
}
