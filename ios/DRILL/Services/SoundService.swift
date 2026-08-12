import AVFoundation
import UIKit

/// The web app's `playCompleteSound` — three sharp square-wave bursts at 180 Hz —
/// rebuilt with `AVAudioEngine`, plus the shorter cues the per-step timer needs.
///
/// It is synthesised rather than shipped as an audio file for the same reason
/// the web version was: it is nine lines of envelope and it means no binary
/// assets to keep in sync.
final class SoundService {
    static let shared = SoundService()

    var isEnabled = true

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var started = false

    private lazy var finishBuffer = makeBuffer(
        frequency: 180,
        bursts: [(start: 0, duration: 0.32), (start: 0.45, duration: 0.32), (start: 0.90, duration: 0.32)],
        peak: 0.6
    )
    private lazy var phaseBuffer = makeBuffer(
        frequency: 660,
        bursts: [(start: 0, duration: 0.14)],
        peak: 0.35
    )
    private lazy var countdownBuffer = makeBuffer(
        frequency: 440,
        bursts: [(start: 0, duration: 0.08)],
        peak: 0.25
    )

    private init() {}

    /// Three buzzers. The exercise is over.
    func playFinish() { play(finishBuffer) }

    /// A new phase has started — work, rest, or the next step.
    func playPhaseChange() { play(phaseBuffer) }

    /// The last three seconds of a countdown.
    func playCountdownTick() { play(countdownBuffer) }

    private func play(_ buffer: AVAudioPCMBuffer) {
        guard isEnabled else { return }
        AudioSessionController.activate()
        startIfNeeded()
        guard engine.isRunning else { return }
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    private func startIfNeeded() {
        guard !started else { return }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        do {
            try engine.start()
            started = true
        } catch {
            // No audio is a degraded experience, not a broken one — the haptics
            // and the on-screen countdown still carry the transition.
            started = false
        }
    }

    /// Builds a mono buffer of square-wave bursts with the web version's
    /// envelope: 10 ms attack, hold, 40 ms release.
    private func makeBuffer(
        frequency: Double,
        bursts: [(start: Double, duration: Double)],
        peak: Float
    ) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let total = (bursts.last.map { $0.start + $0.duration } ?? 0) + 0.05
        let frameCount = AVAudioFrameCount(total * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let samples = buffer.floatChannelData![0]

        let attack = 0.01, release = 0.04
        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            var gain: Float = 0
            for burst in bursts where t >= burst.start && t < burst.start + burst.duration {
                let local = t - burst.start
                if local < attack {
                    gain = peak * Float(local / attack)
                } else if local > burst.duration - release {
                    gain = peak * Float((burst.duration - local) / release)
                } else {
                    gain = peak
                }
            }
            let phase = (t * frequency).truncatingRemainder(dividingBy: 1)
            samples[frame] = gain * (phase < 0.5 ? 1 : -1)
        }
        return buffer
    }
}

/// Transition haptics, so he does not have to watch the screen mid-drill.
enum Haptics {
    static var isEnabled = true

    static func phaseChange() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func tick() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func success() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
