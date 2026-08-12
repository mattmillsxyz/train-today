import AVFoundation

/// Speaks each step aloud with `AVSpeechSynthesizer` — first-party, offline, no
/// dependency and no network.
///
/// This is the single feature that makes the walkthrough usable: an 8-12 year
/// old mid-drill cannot hold a phone and read it. If the step is spoken, the
/// phone goes in a pocket.
final class SpeechService {
    static let shared = SpeechService()

    /// Off switch for Settings. Persisted by the caller.
    var isEnabled = true

    private let synthesizer = AVSpeechSynthesizer()

    private init() {}

    /// Speaks `text`, cutting off whatever is mid-sentence — a new step has
    /// arrived and the old one is no longer what he should be doing.
    func speak(_ text: String) {
        guard isEnabled, !text.isEmpty else { return }
        AudioSessionController.activate()
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        utterance.pitchMultiplier = 1.0
        utterance.postUtteranceDelay = 0
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.preferredLanguages.first ?? "en-US")
        synthesizer.speak(utterance)
    }

    func stop() {
        guard synthesizer.isSpeaking else { return }
        synthesizer.stopSpeaking(at: .immediate)
    }
}
