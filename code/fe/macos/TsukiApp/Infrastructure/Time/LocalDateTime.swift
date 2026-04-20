import Foundation

enum LocalDateTime {
    static func noteDayString(from date: Date = Date()) -> String {
        formatted(date, pattern: "yyyy-MM-dd")
    }

    static func runIDString(from date: Date = Date()) -> String {
        formatted(date, pattern: "yyyyMMdd-HHmmss")
    }

    static func logTimestampString(from date: Date = Date()) -> String {
        formatted(date, pattern: "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ")
    }

    private static func formatted(_ date: Date, pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.autoupdatingCurrent
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
