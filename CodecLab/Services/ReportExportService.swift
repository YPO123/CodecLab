import Foundation

struct ReportExportService {
    func jsonData(for report: TestReport) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(report)
    }

    func html(for report: TestReport) -> String {
        let nullSummary: String
        if let result = report.nullTestResult {
            nullSummary = """
            <p><strong>Offset:</strong> \(result.offsetSamples) samples</p>
            <p><strong>Residual RMS:</strong> \(String(format: "%.2f", result.overallResidualRMSdBFS)) dBFS</p>
            <p><strong>Residual Peak:</strong> \(String(format: "%.2f", result.overallResidualPeakdBFS)) dBFS</p>
            """
        } else {
            nullSummary = "<p>No null-test result yet.</p>"
        }

        return """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <title>CodecLab Report</title>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 40px; color: #111; }
            h1 { margin-bottom: 0; }
            table { border-collapse: collapse; margin-top: 20px; }
            td, th { border: 1px solid #ddd; padding: 8px 12px; }
          </style>
        </head>
        <body>
          <h1>CodecLab Report</h1>
          <p>Your audio stayed on this Mac. No upload. No cloud processing. No account required.</p>
          <h2>Reference</h2>
          <p>\(escape(report.reference.fileName)) · \(escape(report.reference.shortFormatSummary)) · \(escape(report.reference.durationText))</p>
          <h2>Null Test</h2>
          \(nullSummary)
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

