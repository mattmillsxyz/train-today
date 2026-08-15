import Foundation
import UIKit

/// Drives a `Walkthrough`: which phase is showing, how much of it is left, and
/// every cue that fires on the way through.
///
/// Timed phases advance on their own. Only genuinely self-paced work waits for a
/// tap — that is the difference between a screen he has to watch and a coach he
/// can listen to with the phone in his pocket.
@Observable
final class WalkthroughEngine {
    enum Stage: Equatable {
        /// Cones and form, before the clock starts.
        case getReady
        case running
        case finished
    }

    let walkthrough: Walkthrough

    private(set) var stage: Stage
    private(set) var phaseIndex = 0
    /// Whole seconds left in the current phase, for the big readout.
    private(set) var remainingSeconds = 0
    /// 1 → phase just started, 0 → phase over. Drives the countdown ring.
    private(set) var fractionRemaining: Double = 1
    private(set) var isPaused = false

    private var deadline: Date?
    private var pausedRemaining: TimeInterval?
    private var phaseDuration: TimeInterval = 0
    private var ticker: Timer?
    private var lastSpokenCountdown = 0

    var exercise: Exercise { walkthrough.exercise }
    var phases: [WalkPhase] { walkthrough.phases }

    var currentPhase: WalkPhase? {
        phases.indices.contains(phaseIndex) ? phases[phaseIndex] : nil
    }

    var nextPhase: WalkPhase? {
        phases.indices.contains(phaseIndex + 1) ? phases[phaseIndex + 1] : nil
    }

    /// How far through the exercise, for the thin bar at the top.
    var overallProgress: Double {
        guard !phases.isEmpty else { return 1 }
        return Double(phaseIndex) / Double(phases.count)
    }

    var remainingText: String {
        String(format: "%02d:%02d", remainingSeconds / 60, remainingSeconds % 60)
    }

    /// True when the current phase is waiting on him rather than on the clock.
    var waitsForTap: Bool {
        guard let phase = currentPhase else { return false }
        return !phase.kind.advancesAutomatically
    }

    init(exercise: Exercise) {
        self.walkthrough = Walkthrough(exercise: exercise)
        // Nothing to get ready for? Go straight to the work.
        self.stage = walkthrough.getReady.isEmpty ? .running : .getReady
        if stage == .running { enterPhase(0) }
    }

    deinit {
        ticker?.invalidate()
    }

    // MARK: - Control

    func start() {
        guard stage == .getReady else { return }
        stage = .running
        enterPhase(0)
    }

    /// The whole screen calls this when the phase is waiting for a tap.
    func advance() {
        guard stage == .running, waitsForTap else { return }
        goToNextPhase()
    }

    /// The explicit skip control, which also works on timed phases.
    func skip() {
        guard stage == .running else { return }
        goToNextPhase()
    }

    func togglePause() {
        guard stage == .running, phaseDuration > 0 else { return }
        if isPaused {
            let left = pausedRemaining ?? 0
            deadline = Date().addingTimeInterval(left)
            pausedRemaining = nil
            isPaused = false
        } else {
            pausedRemaining = deadline?.timeIntervalSinceNow ?? 0
            deadline = nil
            isPaused = true
            SpeechService.shared.stop()
            SoundService.shared.stop()
        }
    }

    func restartPhase() {
        guard stage == .running else { return }
        enterPhase(phaseIndex)
    }

    /// Ends the exercise early, without the finish fanfare.
    func stop() {
        ticker?.invalidate()
        ticker = nil
        SpeechService.shared.stop()
        SoundService.shared.stop()
        UIApplication.shared.isIdleTimerDisabled = false
        AudioSessionController.deactivate()
    }

    // MARK: - Phases

    private func goToNextPhase() {
        if phaseIndex + 1 < phases.count {
            enterPhase(phaseIndex + 1)
        } else {
            finish()
        }
    }

    private func enterPhase(_ index: Int) {
        phaseIndex = index
        isPaused = false
        pausedRemaining = nil
        lastSpokenCountdown = 0
        guard let phase = currentPhase else { return finish() }

        if let seconds = phase.kind.seconds {
            phaseDuration = TimeInterval(seconds)
            deadline = Date().addingTimeInterval(phaseDuration)
            remainingSeconds = seconds
            fractionRemaining = 1
            startTicker()
        } else {
            phaseDuration = 0
            deadline = nil
            remainingSeconds = 0
            fractionRemaining = 1
            ticker?.invalidate()
            ticker = nil
        }

        UIApplication.shared.isIdleTimerDisabled = true
        SoundService.shared.playPhaseChange()
        Haptics.phaseChange()
        SpeechService.shared.speak(phase.spoken)
    }

    private func finish() {
        stage = .finished
        ticker?.invalidate()
        ticker = nil
        deadline = nil
        UIApplication.shared.isIdleTimerDisabled = false
        SoundService.shared.playFinish()
        Haptics.success()
        SpeechService.shared.speak("Nice work. \(exercise.name) done.")
    }

    private func startTicker() {
        ticker?.invalidate()
        // 0.1s so the ring animates smoothly; the readout only changes on whole
        // seconds, and the deadline is absolute so drift never accumulates.
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func tick() {
        guard !isPaused, let deadline else { return }
        let left = deadline.timeIntervalSinceNow

        let whole = max(0, Int(left.rounded(.up)))
        if whole != remainingSeconds {
            remainingSeconds = whole
            // Count the last three seconds out loud so he can look up in time.
            if (1...3).contains(whole), whole != lastSpokenCountdown {
                lastSpokenCountdown = whole
                SoundService.shared.playCountdownTick()
                Haptics.tick()
            }
        }
        fractionRemaining = phaseDuration > 0 ? max(0, min(1, left / phaseDuration)) : 0

        if left <= 0 {
            ticker?.invalidate()
            ticker = nil
            goToNextPhase()
        }
    }
}
