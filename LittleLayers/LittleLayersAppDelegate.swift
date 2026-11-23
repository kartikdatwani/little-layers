import UIKit
import UserNotifications

extension Notification.Name {
    static let openTodayOutfitFromNotification = Notification.Name("openTodayOutfitFromNotification")
}

final class LittleLayersAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static let pendingOutfitRouteKey = "pendingOutfitRouteFromNotification"

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        guard response.notification.request.identifier.hasPrefix("outfit-") else {
            completionHandler()
            return
        }

        UserDefaults.standard.set(true, forKey: Self.pendingOutfitRouteKey)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .openTodayOutfitFromNotification, object: nil)
        }
        completionHandler()
    }
}
