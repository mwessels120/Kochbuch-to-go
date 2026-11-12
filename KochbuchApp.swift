import SwiftUI
import UserNotifications

@main
struct KochbuchApp: App {
    @State private var favorites = FavoritesStore()
    @State private var userRecipes = UserRecipesStore()
    @State private var planner = PlannerStore()
    @State private var timers = CookingTimers()

    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(favorites)
                .environment(userRecipes)
                .environment(planner)
                .environment(timers)
        }
    }
}
