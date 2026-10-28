import Foundation

public enum ClockFormatting {
    /// Formats the actual system instant using the current presentation preferences.
    /// A formatter is local to each call so locale and time-zone changes never reuse stale state.
    public static func string(date: Date, format: GameSettings.ClockFormat,
                              locale: Locale, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        switch format {
        case .system: formatter.timeStyle = .short
        case .twelveHour: formatter.dateFormat = "h:mm a"
        case .twentyFourHour: formatter.dateFormat = "HH:mm"
        }
        return formatter.string(from: date)
    }
}
