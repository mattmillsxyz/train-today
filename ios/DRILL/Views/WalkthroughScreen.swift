import SwiftUI

/// The per-step walkthrough — feature #2, and the reason the content got
/// restructured.
///
/// The web app's timer took one duration for the whole exercise and listed the
/// steps statically beside it. This one walks them: get ready, then one screen
/// per action step, spoken aloud, advancing itself whenever there is a clock to
/// advance on.
struct WalkthroughScreen: View {
    let exercise: Exercise
    let dayKey: String
    let onClose: (_ completed: Bool) -> Void

    @Environment(TrainingStore.self) private var store
    @State private var engine: WalkthroughEngine
    @State private var recordValue = ""
    @State private var recordIsPR = false
    @State private var recordLogged = false

    init(exercise: Exercise, dayKey: String, onClose: @escaping (_ completed: Bool) -> Void) {
        self.exercise = exercise
        self.dayKey = dayKey
        self.onClose = onClose
        _engine = State(initialValue: WalkthroughEngine(exercise: exercise))
    }

    var body: some View {
        ZStack {
            Theme.timerGreen.ignoresSafeArea()
            switch engine.stage {
            case .getReady: getReady
            case .running: running
            case .finished: finished
            }
        }
        .foregroundStyle(Theme.ink)
        // Starting lives here rather than in the engine's init, which SwiftUI
        // re-runs on every redraw. `task` fires once per presentation.
        .task { engine.begin() }
        .onDisappear { engine.stop() }
    }

    // MARK: - Get ready

    private var getReady: some View {
        VStack(spacing: 0) {
            closeBar

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Get ready")
                            .font(.system(size: 15, weight: .bold))
                            .opacity(0.65)
                        Text(exercise.name)
                            .font(.system(size: 32, weight: .bold))
                            .kerning(-0.5)
                        Text(exercise.displayDuration)
                            .font(.system(size: 16, weight: .medium))
                            .opacity(0.7)
                    }

                    if !engine.walkthrough.getReady.setup.isEmpty {
                        block(title: "Set up", items: engine.walkthrough.getReady.setup)
                    }
                    if !engine.walkthrough.getReady.form.isEmpty {
                        block(title: "How it should look", items: engine.walkthrough.getReady.form)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }

            Button {
                engine.start()
            } label: {
                Text("Start")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Theme.ink.opacity(0.12), in: .capsule)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private func block(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 13, weight: .bold))
                .kerning(0.5)
                .opacity(0.6)
            ForEach(Array(items.enumerated()), id: \.offset) { index, text in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 24, height: 24)
                        .background(.black.opacity(0.15), in: .circle)
                    Text(text)
                        .font(.system(size: 17, weight: .medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Running

    private var running: some View {
        VStack(spacing: 0) {
            closeBar

            ThinProgressBar(
                fraction: engine.overallProgress,
                tint: Theme.ink.opacity(0.55),
                track: Theme.ink.opacity(0.15)
            )
            .padding(.horizontal, 24)
            .padding(.top, 12)

            if let phase = engine.currentPhase {
                ScrollView {
                    VStack(spacing: 16) {
                        if let round = phase.round {
                            Text(round.label)
                                .font(.system(size: 16, weight: .bold))
                                .opacity(0.65)
                        }

                        clock(for: phase)

                        Text(phase.title)
                            .font(.system(size: 26, weight: .bold))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        // The hint belongs after the instruction, not before it —
                        // read what to do, then find out how to move on.
                        if !phase.kind.advancesAutomatically {
                            tapHint
                        }

                        if let detail = phase.detail, phase.kind.isRest {
                            Text(detail)
                                .font(.system(size: 16, weight: .medium))
                                .multilineTextAlignment(.center)
                                .opacity(0.65)
                        }

                        ForEach(Array(phase.cues.enumerated()), id: \.offset) { _, cue in
                            Label(cue, systemImage: "lightbulb.fill")
                                .font(.system(size: 15, weight: .medium))
                                .multilineTextAlignment(.leading)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.black.opacity(0.1), in: .rect(cornerRadius: 12))
                        }

                        if let next = engine.nextPhase {
                            VStack(spacing: 4) {
                                Text("NEXT").font(.system(size: 11, weight: .bold)).kerning(0.5)
                                Text(next.kind.isRest ? "Rest" : next.title)
                                    .font(.system(size: 15))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            .opacity(0.55)
                            .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                }
                // The whole screen is the tap target when a tap is what's needed —
                // he is out of breath and not aiming carefully.
                .contentShape(.rect)
                .onTapGesture { engine.advance() }
            }

            controls
        }
    }

    @ViewBuilder
    private func clock(for phase: WalkPhase) -> some View {
        switch phase.kind {
        case .work, .rest, .block:
            ZStack {
                Circle()
                    .strokeBorder(Theme.ink.opacity(0.15), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: engine.fractionRemaining)
                    .stroke(Theme.ink, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: engine.fractionRemaining)
                VStack(spacing: 2) {
                    Text(engine.remainingText)
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    if phase.kind.isRest {
                        Text("REST").font(.system(size: 13, weight: .bold)).kerning(1).opacity(0.6)
                    }
                }
            }
            .frame(width: 220, height: 220)

        case .reps(let count, let each):
            VStack(spacing: 4) {
                Text("\(count)")
                    .font(.system(size: 84, weight: .bold, design: .rounded))
                Text(each.map { "each \($0)" } ?? "reps")
                    .font(.system(size: 18, weight: .semibold))
                    .opacity(0.7)
            }
            .frame(height: 200)

        case .selfPaced:
            Image(systemName: "figure.run")
                .font(.system(size: 72, weight: .semibold))
                .frame(height: 200)
        }
    }

    private var tapHint: some View {
        Label("Tap anywhere when you're done", systemImage: "hand.tap")
            .font(.system(size: 14, weight: .semibold))
            .opacity(0.6)
    }

    private var controls: some View {
        HStack(spacing: 16) {
            circleButton("arrow.counterclockwise", label: "Restart step") { engine.restartPhase() }

            Button {
                engine.togglePause()
            } label: {
                Text(engine.isPaused ? "Resume" : "Pause")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(minWidth: 120)
                    .padding(.vertical, 14)
                    .background(Theme.timerButton, in: .capsule)
            }
            .buttonStyle(.plain)
            // Nothing to pause on a phase that is already waiting for him.
            .disabled(engine.waitsForTap)
            .opacity(engine.waitsForTap ? 0.35 : 1)

            circleButton("forward.fill", label: "Skip step") { engine.skip() }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    private func circleButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 56, height: 56)
                .background(Theme.timerButton, in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var closeBar: some View {
        HStack {
            Button {
                engine.stop()
                onClose(false)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 40, height: 40)
                    .background(.black.opacity(0.12), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // MARK: - Finished

    private var finished: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 20) {
                    Text("💪").font(.system(size: 64))
                    Text("Nice work!")
                        .font(.system(size: 34, weight: .bold))
                    Text(exercise.name)
                        .font(.system(size: 18, weight: .medium))
                        .opacity(0.7)

                    if let metric = exercise.prMetric, !recordLogged {
                        recordEntry(metric)
                    } else if recordLogged {
                        Text(recordIsPR ? "🏆 New personal record!" : "Logged. Beat it next time.")
                            .font(.system(size: 17, weight: .bold))
                            .padding(14)
                            .frame(maxWidth: .infinity)
                            .background(.black.opacity(0.12), in: .rect(cornerRadius: 14))
                    }

                    Button {
                        onClose(true)
                    } label: {
                        Text("Done")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Theme.timerGreen)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Theme.ink, in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
                .frame(minHeight: geo.size.height)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func recordEntry(_ metric: PRMetric) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(metric.label)
                .font(.system(size: 16, weight: .bold))
            if let best = store.best(for: exercise) {
                Text("Best so far: \(format(best, metric))")
                    .font(.system(size: 14))
                    .opacity(0.7)
            }
            HStack(spacing: 10) {
                TextField(metric.unit.fieldLabel, text: $recordValue)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20, weight: .semibold))
                    .padding(12)
                    .background(.white.opacity(0.85), in: .rect(cornerRadius: 12))
                    .foregroundStyle(Theme.ink)

                Button("Log") {
                    guard let value = Double(recordValue) else { return }
                    recordIsPR = store.logRecord(value, for: exercise)
                    recordLogged = true
                    if recordIsPR { Haptics.success() }
                }
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.timerGreen)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Theme.ink, in: .capsule)
                .buttonStyle(.plain)
                .disabled(Double(recordValue) == nil)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.1), in: .rect(cornerRadius: 16))
    }

    private func format(_ value: Double, _ metric: PRMetric) -> String {
        let number = value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
        return number + metric.unit.suffix
    }
}
