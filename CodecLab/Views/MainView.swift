import SwiftUI

struct MainView: View {
    @StateObject private var model = CodecLabViewModel()

    var body: some View {
        ZStack {
            CodecLabStyle.background.ignoresSafeArea()

            VStack(spacing: 16) {
                header

                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 16) {
                        DropZoneView(model: model)
                        FileInfoView(info: model.referenceInfo)
                        TestRegionView(model: model)
                    }
                    .frame(width: 300)

                    VStack(spacing: 16) {
                        CodecAuditionView(model: model, playbackEngine: model.playbackEngine)
                        NullTestView(model: model)
                        ABXView(model: model, abxService: model.abxService)
                    }
                    .frame(minWidth: 560)

                    VStack(spacing: 16) {
                        EncoderStatusView(model: model)
                        ExportView(model: model)
                        SettingsView(model: model)
                    }
                    .frame(width: 310)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
        }
        .foregroundStyle(CodecLabStyle.primaryText)
        .task {
            await model.refreshDiagnostics()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text("CodecLab")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                Text("Free local codec testing. No upload. No account.")
                    .font(.system(size: 12))
                    .foregroundStyle(CodecLabStyle.secondaryText)
            }

            Spacer()

            HStack(spacing: 8) {
                if model.isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .tint(CodecLabStyle.accent)
                }
                Text(model.statusMessage)
                    .lineLimit(1)
                    .font(.system(size: 12))
                    .foregroundStyle(CodecLabStyle.secondaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(CodecLabStyle.surfaceRaised)
            .clipShape(Capsule())
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
    }
}
