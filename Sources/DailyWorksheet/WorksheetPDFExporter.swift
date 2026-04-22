import AppKit
import CoreGraphics
import Foundation

enum PDFExportError: Error, LocalizedError {
    case cannotCreateContext

    var errorDescription: String? {
        "Could not create the PDF file."
    }
}

enum WorksheetPDFExporter {
    static func export(entries: [WorksheetEntry], projectTotals: [ProjectTotal], totals: WorksheetTotals, month: Date, to url: URL) throws {
        var mediaBox = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
            throw PDFExportError.cannotCreateContext
        }

        let renderer = PDFTextRenderer(context: context, mediaBox: mediaBox)
        renderer.beginPage()

        renderer.drawTitle("Monthly Work Worksheet - \(Formatters.monthTitle.string(from: month))")
        renderer.drawLine("Total: \(Formatters.hoursString(seconds: totals.totalSeconds)) h")
        renderer.drawLine("Creative: \(Formatters.hoursString(seconds: totals.creativeSeconds)) h / \(Formatters.percentString(totals.creativeRatio))")
        renderer.drawLine("Admin: \(Formatters.hoursString(seconds: totals.adminSeconds)) h / \(Formatters.percentString(totals.adminRatio))")
        renderer.drawGap()

        renderer.drawSection("Project Totals")
        renderer.drawLine("Project                                      Creative     Admin     Total")
        for total in projectTotals {
            renderer.drawLine(
                columns([
                    total.project,
                    "\(Formatters.hoursString(seconds: total.creativeSeconds)) h",
                    "\(Formatters.hoursString(seconds: total.adminSeconds)) h",
                    "\(Formatters.hoursString(seconds: total.totalSeconds)) h"
                ])
            )
        }

        renderer.drawGap()
        renderer.drawSection("Entries")
        renderer.drawLine("Date        Project                         Category    Hours    Activity")
        for entry in entries {
            renderer.drawLine(
                columns([
                    Formatters.displayDay.string(from: entry.date),
                    entry.project,
                    entry.category.rawValue,
                    "\(Formatters.hoursString(seconds: entry.seconds)) h",
                    entry.activity
                ])
            )
        }

        renderer.endPage()
        context.closePDF()
    }

    private static func columns(_ values: [String]) -> String {
        let widths = [12, 32, 11, 9]
        var output = ""
        for index in values.indices {
            if index < widths.count {
                output += values[index].padding(toLength: widths[index], withPad: " ", startingAt: 0)
            } else {
                output += values[index]
            }
        }
        return output
    }
}

final class PDFTextRenderer {
    private let context: CGContext
    private let mediaBox: CGRect
    private let margin: CGFloat = 42
    private let lineHeight: CGFloat = 16
    private var y: CGFloat

    init(context: CGContext, mediaBox: CGRect) {
        self.context = context
        self.mediaBox = mediaBox
        self.y = mediaBox.height - margin
    }

    func beginPage() {
        context.beginPDFPage(nil)
        y = mediaBox.height - margin
    }

    func endPage() {
        context.endPDFPage()
    }

    func drawTitle(_ text: String) {
        draw(text, font: NSFont.boldSystemFont(ofSize: 18))
        drawGap()
    }

    func drawSection(_ text: String) {
        draw(text, font: NSFont.boldSystemFont(ofSize: 13))
    }

    func drawLine(_ text: String) {
        draw(text, font: NSFont.monospacedSystemFont(ofSize: 10.5, weight: .regular))
    }

    func drawGap() {
        y -= lineHeight
    }

    private func draw(_ text: String, font: NSFont) {
        if y < margin {
            context.endPDFPage()
            beginPage()
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]
        let point = CGPoint(x: margin, y: y)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        (text as NSString).draw(at: point, withAttributes: attributes)
        NSGraphicsContext.restoreGraphicsState()

        y -= lineHeight
    }
}
