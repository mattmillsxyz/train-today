import AVFoundation

/// Speaks each step aloud with `AVSpeechSynthesizer` — first-party, offline, no
/// dependency and no network.
///
/// This is the single feature that makes the walkthrough usable: an 8-12 year
/// old mid-drill cannot hold a phone and read it. If the step is spoken, the
/// phone goes in a pocket.
final class SpeechService: NSObject {
    static let shared = SpeechService()

    /// Off switch for Settings. Persisted by the caller.
    var isEnabled = true

    private let synthesizer = AVSpeechSynthesizer()
    /// Held while a cancel is in flight, then spoken from `didCancel`.
    private var pending: String?

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Speaks `text`, cutting off whatever is mid-sentence — a new step has
    /// arrived and the old one is no longer what he should be doing.
    ///
    /// Cancelling is asynchronous, which is the whole difficulty here. Calling
    /// `stopSpeaking` and then `speak` in the same turn races the teardown: the
    /// new utterance is dropped and the *previous* line carries on playing over
    /// the new step. So the new text waits as `pending` until the cancel is
    /// confirmed, and `didCancel` starts it.
    func speak(_ text: String) {
        guard isEnabled, !text.isEmpty else { return }
        AudioSessionController.activate()

        guard synthesizer.isSpeaking || synthesizer.isPaused else {
            pending = nil
            utter(text)
            return
        }

        pending = text
        if synthesizer.stopSpeaking(at: .immediate) {
            // A cancel really is in flight. `didCancel` picks it up from here,
            // with a watchdog in case that callback never lands.
            schedulePendingWatchdog()
        } else {
            // Nothing was actually cancellable, so no callback is coming.
            pending = nil
            utter(text)
        }
    }

    func stop() {
        pending = nil
        guard synthesizer.isSpeaking || synthesizer.isPaused else { return }
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func utter(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        utterance.pitchMultiplier = 1.0
        utterance.postUtteranceDelay = 0
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.preferredLanguages.first ?? "en-US")
        synthesizer.speak(utterance)
    }

    /// Belt and braces: if the cancel callback is ever missed, the step would
    /// go silent, which is worse than a slightly late line.
    private func schedulePendingWatchdog() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, let text = self.pending else { return }
            guard !self.synthesizer.isSpeaking else { return }
            self.pending = nil
            self.utter(text)
        }
    }

    private func startPendingIfAny() {
        guard let text = pending else { return }
        pending = nil
        utter(text)
    }
}

extension SpeechService: AVSpeechSynthesizerDelegate {
    /// Delegate callbacks are not promised on any particular queue, and
    /// `speak` touches `pending`, so hop to main before doing anything.
    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        DispatchQueue.main.async { [weak self] in self?.startPendingIfAny() }
    }
}
