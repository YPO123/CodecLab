import SwiftUI

struct TestRegionView: View {
    @ObservedObject var model: CodecLabViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Test Region", systemImage: "timeline.selection")
                .font(.system(size: 14, weight: .semibold))

            Picker("Duration", selection: $model.region.duration) {
                ForEach(TestRegion.durationPresets, id: \.self) { value in
                    Text("\(Int(value))s").tag(value)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Start")
                    Spacer()
                    Text(String(format: "%.2fs", model.region.startTime))
                        .fontDesign(.monospaced)
                }
                .font(.system(size: 12))
                .foregroundStyle(CodecLabStyle.secondaryText)

                Slider(
                    value: $model.region.startTime,
                    in: 0...sliderUpperBound,
                    step: 0.1
                )
                .disabled(maxStart <= 0)
            }

            MetricRow(label: "End", value: String(format: "%.2fs", model.region.endTime))
        }
        .codecPanel()
    }

    private var maxStart: Double {
        guard let duration = model.referenceInfo?.duration, duration > model.region.duration else {
            return 0
        }
        return max(0, duration - model.region.duration)
    }

    private var sliderUpperBound: Double {
        max(0.1, maxStart)
    }
}
