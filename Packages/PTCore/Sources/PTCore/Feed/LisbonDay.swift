import Foundation

extension Lisbon {
    /// The Lisbon calendar day of an instant, as `yyyy-MM-dd` (the agenda's `date` field). The one copy for the app
    /// (Q8): the schedule, planner, reminders and team views use it; Ask's context and the reader can too.
    public static func day(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
