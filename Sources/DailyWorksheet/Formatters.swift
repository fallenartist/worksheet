import Foundation

enum Formatters {
    static let apiDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let monthTitle: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()

    static let displayDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let hours: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    static let percent: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    static func hoursString(seconds: Int) -> String {
        let value = Double(seconds) / 3600
        return hours.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    static func percentString(_ value: Double) -> String {
        percent.string(from: NSNumber(value: value)) ?? String(format: "%.1f%%", value * 100)
    }
}

extension Calendar {
    func monthInterval(containing date: Date) -> DateInterval {
        dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 0)
    }

    func lastDayOfMonth(containing date: Date) -> Date {
        let interval = monthInterval(containing: date)
        return self.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
    }
}
