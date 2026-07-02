import SwiftUI

struct ABXView: View {
    @ObservedObject var model: CodecLabViewModel
    @ObservedObject var abxService: ABXService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("ABX", systemImage: "questionmark.circle")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button {
                    model.startABX(totalTrials: 10)
                } label: {
                    Label("10", systemImage: "play.circle")
                }
                .disabled(model.currentArtifacts == nil)
            }

            if let session = abxService.session {
                HStack(spacing: 8) {
                    abxPlayButton("A", slot: .a)
                    abxPlayButton("B", slot: .b)
                    abxPlayButton("X", slot: .x)
                }

                HStack(spacing: 8) {
                    Button("X is A") {
                        submitGuessFromA(session)
                    }
                    .frame(maxWidth: .infinity)
                    Button("X is B") {
                        submitGuessFromB(session)
                    }
                    .frame(maxWidth: .infinity)
                }

                VStack(spacing: 7) {
                    MetricRow(label: "Trials", value: "\(session.completedCount)/\(session.totalTrials)")
                    MetricRow(label: "Correct", value: "\(session.correctCount)")
                    MetricRow(label: "p-value", value: String(format: "%.4f", ABXService.pValue(correct: session.correctCount, total: max(session.completedCount, 1))))
                }
            } else {
                Text("Generate Current MP3 to start")
                    .font(.system(size: 12))
                    .foregroundStyle(CodecLabStyle.secondaryText)
            }
        }
        .codecPanel()
    }

    private func abxPlayButton(_ title: String, slot: ABXSlot) -> some View {
        Button {
            model.playABXSlot(slot)
        } label: {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 42)
        }
        .buttonStyle(.bordered)
    }

    private func submitGuessFromA(_ session: ABXSession) {
        guard let trial = session.trials[safe: session.currentIndex] else { return }
        model.submitABXGuess(trial.a)
    }

    private func submitGuessFromB(_ session: ABXSession) {
        guard let trial = session.trials[safe: session.currentIndex] else { return }
        model.submitABXGuess(trial.b)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

