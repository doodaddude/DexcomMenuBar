import Foundation
import AppKit

/// Generator for clean clinical PDF reports and CSV exports formatted for endocrinologist visits
public struct DexcomExportService {
    
    /// Exports readings to clean CSV format
    public static func generateCSV(readings: [GlucoseReading], unit: GlucoseUnit) -> String {
        var csv = "Timestamp,ISO8601,Glucose (\(unit.rawValue)),Trend Arrow,Trend Description,Category\n"
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let iso = ISO8601DateFormatter()
        
        for r in readings.sorted(by: { $0.timestamp < $1.timestamp }) {
            let timeStr = df.string(from: r.timestamp)
            let isoStr = iso.string(from: r.timestamp)
            let valStr = r.formattedValue(unit: unit)
            let arrow = r.trend.symbol
            let desc = r.trend.description
            let cat = r.category.title
            csv += "\"\(timeStr)\",\"\(isoStr)\",\(valStr),\"\(arrow)\",\"\(desc)\",\"\(cat)\"\n"
        }
        return csv
    }
    
    /// Generates a clean, professional multi-page or single-page PDF clinical summary
    public static func generateEndocrinologistPDF(
        readings: [GlucoseReading],
        unit: GlucoseUnit,
        tir: Int,
        mean: Double,
        gmi: Double,
        sd: Double,
        filterName: String,
        sensorModel: DexcomSensorModel
    ) -> Data {
        let pdfData = NSMutableData()
        var pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // Standard US Letter
        
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &pageRect, nil) else {
            return Data()
        }
        
        context.beginPage(mediaBox: &pageRect)
        
        // Background
        context.setFillColor(CGColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1.0))
        context.fill(pageRect)
        
        let printDate = Date()
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        
        // Header Bar
        let headerRect = CGRect(x: 36, y: 700, width: 540, height: 60)
        context.setFillColor(CGColor(red: 0.08, green: 0.12, blue: 0.22, alpha: 1.0))
        let headerPath = CGPath(roundedRect: headerRect, cornerWidth: 8, cornerHeight: 8, transform: nil)
        context.addPath(headerPath)
        context.fillPath()
        
        // Title Text
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 18),
            .foregroundColor: NSColor.white
        ]
        let titleString = NSAttributedString(string: "Dexcom Continuous Glucose Monitoring Clinical Report", attributes: titleAttrs)
        titleString.draw(at: CGPoint(x: 52, y: 732))
        
        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor(white: 0.85, alpha: 1.0)
        ]
        let subString = NSAttributedString(string: "Generated for Endocrinologist / Clinician Visit • Sensor: \(sensorModel.rawValue) • Date: \(df.string(from: printDate))", attributes: subAttrs)
        subString.draw(at: CGPoint(x: 52, y: 712))
        
        // Summary Metrics Cards (TIR, Average, GMI, SD)
        let metricsY: CGFloat = 610
        let cardWidth: CGFloat = 125
        let cardHeight: CGFloat = 70
        let cardSpacing: CGFloat = 13.3
        
        let metricData: [(title: String, val: String, sub: String, color: NSColor)] = [
            ("TIME IN RANGE", "\(tir)%", "Target: 70–180 mg/dL (>70%)", NSColor.systemGreen),
            ("MEAN GLUCOSE", "\(unit.format(mgdL: mean)) \(unit.rawValue)", "Overall average", NSColor.systemBlue),
            ("ESTIMATED A1C", String(format: "%.1f%%", gmi), "GMI Formula", NSColor.systemPurple),
            ("GLUCOSE SD", "±\(unit.format(mgdL: sd))", "Standard deviation", NSColor.systemOrange)
        ]
        
        for (idx, m) in metricData.enumerated() {
            let cardX = 36 + CGFloat(idx) * (cardWidth + cardSpacing)
            let cardRect = CGRect(x: cardX, y: metricsY, width: cardWidth, height: cardHeight)
            
            context.setFillColor(NSColor.white.cgColor)
            context.setStrokeColor(NSColor(white: 0.88, alpha: 1.0).cgColor)
            context.setLineWidth(1)
            let path = CGPath(roundedRect: cardRect, cornerWidth: 6, cornerHeight: 6, transform: nil)
            context.addPath(path)
            context.drawPath(using: CGPathDrawingMode.fillStroke)
            
            let mTitleAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 8.5),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            NSAttributedString(string: m.title, attributes: mTitleAttrs).draw(at: CGPoint(x: cardX + 10, y: metricsY + 50))
            
            let mValAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 18),
                .foregroundColor: m.color
            ]
            NSAttributedString(string: m.val, attributes: mValAttrs).draw(at: CGPoint(x: cardX + 10, y: metricsY + 26))
            
            let mSubAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 7.5),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            NSAttributedString(string: m.sub, attributes: mSubAttrs).draw(at: CGPoint(x: cardX + 10, y: metricsY + 10))
        }
        
        // Time Filter Section Title
        let secAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 12),
            .foregroundColor: NSColor.labelColor
        ]
        NSAttributedString(string: "Glucose Readings Table & Trend Log (\(filterName))", attributes: secAttrs).draw(at: CGPoint(x: 36, y: 575))
        
        let countAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9.5),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        NSAttributedString(string: "Total readings recorded in period: \(readings.count)", attributes: countAttrs).draw(at: CGPoint(x: 36, y: 560))
        
        // Table Header
        let tableTopY: CGFloat = 545
        let tableHeaderRect = CGRect(x: 36, y: tableTopY - 20, width: 540, height: 20)
        context.setFillColor(NSColor(white: 0.92, alpha: 1.0).cgColor)
        context.fill(tableHeaderRect)
        
        let thAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 9),
            .foregroundColor: NSColor.darkGray
        ]
        NSAttributedString(string: "TIMESTAMP", attributes: thAttrs).draw(at: CGPoint(x: 46, y: tableTopY - 15))
        NSAttributedString(string: "GLUCOSE (\(unit.rawValue))", attributes: thAttrs).draw(at: CGPoint(x: 180, y: tableTopY - 15))
        NSAttributedString(string: "TREND", attributes: thAttrs).draw(at: CGPoint(x: 290, y: tableTopY - 15))
        NSAttributedString(string: "STATUS / CATEGORY", attributes: thAttrs).draw(at: CGPoint(x: 390, y: tableTopY - 15))
        
        // Table Rows (Up to 26 most recent readings in page)
        var rowY = tableTopY - 38
        let timeRowFormatter = DateFormatter()
        timeRowFormatter.dateFormat = "MMM d, h:mm a"
        
        let rowReadings = Array(readings.prefix(25))
        for (i, r) in rowReadings.enumerated() {
            if i % 2 == 1 {
                context.setFillColor(NSColor(white: 0.97, alpha: 1.0).cgColor)
                context.fill(CGRect(x: 36, y: rowY - 4, width: 540, height: 18))
            }
            
            let cellAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 8.5),
                .foregroundColor: NSColor.labelColor
            ]
            let boldCellAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 8.5),
                .foregroundColor: r.category.nsColor
            ]
            
            NSAttributedString(string: timeRowFormatter.string(from: r.timestamp), attributes: cellAttrs).draw(at: CGPoint(x: 46, y: rowY))
            NSAttributedString(string: "\(r.formattedValue(unit: unit))", attributes: boldCellAttrs).draw(at: CGPoint(x: 180, y: rowY))
            NSAttributedString(string: "\(r.trend.symbol) \(r.trend.description)", attributes: cellAttrs).draw(at: CGPoint(x: 290, y: rowY))
            NSAttributedString(string: r.category.title, attributes: boldCellAttrs).draw(at: CGPoint(x: 390, y: rowY))
            
            rowY -= 18
        }
        
        // Footer Note
        let footerAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 8),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
        let footerText = "Dexcom Menu Bar Companion • Clinical CGM Export • Not intended to replace standard medical advice or comprehensive Dexcom Clarity reports."
        NSAttributedString(string: footerText, attributes: footerAttrs).draw(at: CGPoint(x: 36, y: 25))
        
        context.endPage()
        context.closePDF()
        
        return pdfData as Data
    }
}
