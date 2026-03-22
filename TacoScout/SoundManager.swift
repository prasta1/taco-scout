import AVFoundation
import os.log

private let soundLogger = Logger(subsystem: "com.tacoscout.app", category: "SoundManager")

/// Plays short sound effects from bundled audio files.
enum SoundManager {
    /// Global mute toggle, controlled by SettingsManager.
    static var enabled = true

    private static var player: AVAudioPlayer?

    /// Play a bundled audio file by name (without extension).
    static func play(_ name: String, ext: String = "mp3") {
        guard enabled else { return }
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            soundLogger.warning("⚠️ \(name).\(ext) not found in bundle")
            return
        }

        do {
            // Allow playback even in silent mode
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)

            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
        } catch {
            soundLogger.error("Failed to play \(name).\(ext) — \(error.localizedDescription)")
        }
    }

    /// Play the lucky pick sound.
    static func playLuckySound() {
        play("arriba")
    }
}
