import Foundation
import UserNotifications

enum OutfitNotifications {
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func cancelScheduled() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    static func schedule(forecast: Forecast, children: [Child], start: Int, end: Int,
                         hour: Int, minute: Int, groundSnow: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard !children.isEmpty else { return }
        var calendar = Calendar.current
        calendar.timeZone = .current
        let now = Date()
        // Forecasts are refreshed when the app opens. Queue the available days so alerts still work if it stays closed.
        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now),
                  let fireDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  fireDate > now else { continue }
            let hours = forecast.hours(on: day, from: start, through: end)
            guard !hours.isEmpty else { continue }
            let lines = children.compactMap { child -> String? in
                guard let outfit = Outfit.recommend(hours: hours, age: child.age, runsCold: child.runsCold, groundSnow: groundSnow) else { return nil }
                return "\(child.name): \(outfit.layers); \(outfit.shoes). \(outfit.extras)."
            }
            guard !lines.isEmpty else { continue }
            let content = UNMutableNotificationContent()
            content.title = "Today’s outfit"
            content.body = lines.joined(separator: " ")
            content.sound = .default
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: "outfit-\(day.formatted(.iso8601.year().month().day().dateSeparator(.dash)))", content: content, trigger: trigger)
            center.add(request)
        }
    }
}
