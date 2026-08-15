import AVFoundation
import UIKit

/// Every audio cue the walkthrough plays, built with `AVAudioEngine` rather
/// than shipped as files — a handful of lines of envelope each, and no binary
/// assets to keep in sync.
final class SoundService {
    static let shared = SoundService()

    var isEnabled = true

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var started = false

    /// Three quick claps rather than a buzzer — the exercise is done, not an
    /// alarm going off.
    private lazy var finishBuffer = makeClapBuffer(
        claps: [(start: 0, duration: 0.09), (start: 0.13, duration: 0.09), (start: 0.29, duration: 0.13)],
        peak: 0.8
    )
    /// A soft sine chime, not the harsh square-wave "ding" it started as —
    /// this plays on every phase change, including a mashed skip/restart, so
    /// it has to be pleasant repeated.
    private lazy var phaseBuffer = makeChimeBuffer(frequency: 523.25, duration: 0.22, peak: 0.3)
    private lazy var countdownBuffer = makeBuffer(
        frequency: 440,
        bursts: [(start: 0, duration: 0.08)],
        peak: 0.25
    )

    private init() {}

    /// Three claps. The exercise is over.
    func playFinish() { play(finishBuffer) }

    /// A new phase has started — work, rest, or the next step.
    func playPhaseChange() { play(phaseBuffer) }

    /// The last three seconds of a countdown.
    func playCountdownTick() { play(countdownBuffer) }

    /// Cuts off whatever is currently sounding. Called whenever the
    /// walkthrough pauses or the screen closes — a scheduled buffer keeps
    /// playing out on its own otherwise, regardless of what the UI is doing.
    func stop() {
        player.stop()
    }

    private func play(_ buffer: AVAudioPCMBuffer) {
        guard isEnabled else { return }
        AudioSessionController.activate()
        startIfNeeded()
        guard engine.isRunning else { return }
        // `scheduleBuffer` appends to the player's queue rather than
        // replacing it, so without an explicit stop, rapid skips/restarts
        // pile up a train of cues that keeps playing long after the walkthrough
        // has moved on — exactly what "cutting off whatever is mid-sentence"
        // means for `SpeechService.speak`, and this needs the same rule.
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        player.play()
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

    /// Builds a mono buffer of square-wave bursts with a 10 ms attack, hold,
    /// 40 ms release envelope.
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

    /// A single soft sine pulse: a gentle 20 ms attack into an exponential
    /// decay, with none of a square wave's harmonics to sound harsh.
    private func makeChimeBuffer(frequency: Double, duration: Double, peak: Float) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount((duration + 0.02) * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let samples = buffer.floatChannelData![0]

        let attack = 0.02
        let decayTau = duration * 0.35
        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            var gain: Float = 0
            if t < duration {
                gain = t < attack
                    ? peak * Float(t / attack)
                    : peak * Float(exp(-(t - attack) / decayTau))
            }
            samples[frame] = gain * Float(sin(2 * Double.pi * frequency * t))
        }
        return buffer
    }

    /// A clap: filtered noise rather than a tone. Each burst is white noise
    /// through a one-zero high-pass (drop the rumble, keep the crack) inside
    /// a sharp-attack, fast-decay envelope.
    private func makeClapBuffer(
        claps: [(start: Double, duration: Double)],
        peak: Float
    ) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let total = (claps.last.map { $0.start + $0.duration } ?? 0) + 0.08
        let frameCount = AVAudioFrameCount(total * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let samples = buffer.floatChannelData![0]

        let attack = 0.003
        var previousNoise: Float = 0
        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            var gain: Float = 0
            for clap in claps where t >= clap.start && t < clap.start + clap.duration {
                let local = t - clap.start
                if local < attack {
                    gain = peak * Float(local / attack)
                } else {
                    let tau = (clap.duration - attack) / 3.2
                    gain = peak * Float(exp(-(local - attack) / tau))
                }
            }
            let noise = Float.random(in: -1...1)
            let shaped = noise - previousNoise * 0.72
            previousNoise = noise
            samples[frame] = max(-1, min(1, gain * shaped))
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
