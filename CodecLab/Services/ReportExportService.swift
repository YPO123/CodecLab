import Foundation

struct ReportExportService {
    func jsonData(for report: TestReport) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(report)
    }

    func html(for report: TestReport) -> String {
        let encodeSummary: String
        if let settings = report.encodeSettings {
            let bitrate = settings.bitrateKbps.map { "\($0) kbps" } ?? "Source"
            encodeSummary = """
            <dl class="grid">
              <dt>Format</dt><dd>\(escape(settings.format.label))</dd>
              <dt>Encoder</dt><dd>\(escape(settings.encoder.label))</dd>
              <dt>Bitrate</dt><dd>\(escape(bitrate))</dd>
              <dt>Monitor</dt><dd>\(escape(report.monitorMode))</dd>
            </dl>
            """
        } else {
            encodeSummary = "<p>No encoded monitor has been rendered yet.</p>"
        }

        let nullSummary: String
        if let result = report.nullTestResult {
            let channelRows = result.perChannel.map { channel in
                """
                <tr>
                  <td>\(escape(channel.channelName ?? "Ch \(channel.channelIndex + 1)"))</td>
                  <td>\(String(format: "%.2f", channel.residualRMSdBFS)) dBFS</td>
                  <td>\(String(format: "%.2f", channel.residualPeakdBFS)) dBFS</td>
                </tr>
                """
            }.joined(separator: "\n")

            nullSummary = """
            <dl class="grid">
              <dt>Offset</dt><dd>\(result.offsetSamples) samples</dd>
              <dt>Residual RMS</dt><dd>\(String(format: "%.2f", result.overallResidualRMSdBFS)) dBFS</dd>
              <dt>Residual Peak</dt><dd>\(String(format: "%.2f", result.overallResidualPeakdBFS)) dBFS</dd>
              <dt>Difference WAV</dt><dd>\(result.differenceFileURL == nil ? "Not exported" : "Included in package")</dd>
            </dl>
            <table>
              <thead><tr><th>Channel</th><th>RMS</th><th>Peak</th></tr></thead>
              <tbody>\(channelRows)</tbody>
            </table>
            """
        } else {
            nullSummary = "<p>No null-test result yet.</p>"
        }

        let abxSummary: String
        if let session = report.abxSession {
            let pValue = ABXService.pValue(correct: session.correctCount, total: max(session.completedCount, 1))
            abxSummary = """
            <dl class="grid">
              <dt>Trials</dt><dd>\(session.completedCount) / \(session.totalTrials)</dd>
              <dt>Correct</dt><dd>\(session.correctCount)</dd>
              <dt>p-value</dt><dd>\(String(format: "%.4f", pValue))</dd>
            </dl>
            """
        } else {
            abxSummary = "<p>No ABX session recorded yet.</p>"
        }

        return """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <title>CodecLab Report</title>
          <style>
            :root { color-scheme: light; }
            body { font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif; margin: 0; color: #12151b; background: #f4f6f8; }
            main { max-width: 920px; margin: 0 auto; padding: 40px 28px 56px; }
            header { border-bottom: 1px solid #d9dee7; margin-bottom: 28px; padding-bottom: 20px; }
            h1 { margin: 0 0 8px; font-size: 32px; }
            h2 { margin-top: 28px; font-size: 18px; }
            p { color: #5b6472; }
            .panel { background: #fff; border: 1px solid #dde3ec; border-radius: 12px; padding: 18px 20px; box-shadow: 0 12px 30px rgba(20, 28, 40, 0.06); }
            .grid { display: grid; grid-template-columns: 160px 1fr; gap: 10px 18px; margin: 0; }
            dt { color: #657082; }
            dd { margin: 0; font-weight: 600; }
            table { border-collapse: collapse; margin-top: 16px; width: 100%; }
            td, th { border-bottom: 1px solid #e5e9f0; padding: 9px 10px; text-align: left; }
            th { color: #657082; font-size: 12px; text-transform: uppercase; letter-spacing: 0.04em; }
          </style>
        </head>
        <body>
          <main>
            <header>
              <h1>CodecLab Report</h1>
              <p>Your audio stayed on this Mac. No upload. No cloud processing. No account required.</p>
            </header>

            <section class="panel">
              <h2>Reference</h2>
              <dl class="grid">
                <dt>File</dt><dd>\(escape(report.reference.fileName))</dd>
                <dt>Format</dt><dd>\(escape(report.reference.shortFormatSummary))</dd>
                <dt>Duration</dt><dd>\(escape(report.reference.durationText))</dd>
                <dt>Region</dt><dd>\(String(format: "%.1f", report.region.startTime))s to \(String(format: "%.1f", report.region.startTime + report.region.duration))s</dd>
              </dl>
            </section>

            <section class="panel">
              <h2>Encoding</h2>
              \(encodeSummary)
            </section>

            <section class="panel">
              <h2>Null Test</h2>
              \(nullSummary)
            </section>

            <section class="panel">
              <h2>ABX</h2>
              \(abxSummary)
            </section>
          </main>
        </body>
        </html>
        """
    }

    private func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
