import SwiftUI
import UserNotifications
import Observation

// MARK: - Timer

struct RunningTimer: Identifiable {
    let id = UUID()
    let label: String
    let end: Date
}

@Observable
final class CookingTimers {
    private(set) var timers: [RunningTimer] = []

    func start(minutes: Int, label: String) {
        let timer = RunningTimer(label: label, end: .now.addingTimeInterval(Double(minutes * 60)))
        timers.append(timer)

        // Benachrichtigung, damit der Timer auch klingelt, wenn die App im Hintergrund ist.
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Timer abgelaufen"
            content.body = label
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(minutes * 60), repeats: false)
            center.add(UNNotificationRequest(identifier: timer.id.uuidString, content: content, trigger: trigger))
        }
    }

    func cancel(_ timer: RunningTimer) {
        timers.removeAll { $0.id == timer.id }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [timer.id.uuidString])
    }
}

/// Zeigt Timer-Hinweise auch an, während die App geöffnet ist.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

extension Step {
    /// Erkennt Zeitangaben wie "20 Minuten", "25–30 Minuten", "5 Min." oder "2 Stunden".
    var timerMinutes: Int? {
        let pattern = #"(\d+)(?:\s*[–-]\s*\d+)?\s*(Minuten|Minute|Min\.?|Stunden|Stunde|Std\.?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let numberRange = Range(match.range(at: 1), in: text),
              let unitRange = Range(match.range(at: 2), in: text),
              let number = Int(text[numberRange]), number > 0 else { return nil }
        return text[unitRange].hasPrefix("St") ? number * 60 : number
    }
}

func durationText(_ minutes: Int) -> String {
    if minutes >= 60 && minutes % 60 == 0 { return "\(minutes / 60) Std." }
    return "\(minutes) Min."
}

// MARK: - Kochmodus

struct CookingModeView: View {
    let recipe: Recipe
    let portions: Int

    @Environment(\.dismiss) private var dismiss
    @State private var page = 0
    @State private var checked: Set<Int> = []

    private var lastPage: Int { recipe.s.count }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressView(value: Double(page), total: Double(max(lastPage, 1)))
                    .tint(Theme.green)
                    .padding(.horizontal)
                    .padding(.top, 4)

                TabView(selection: $page) {
                    IngredientsPage(recipe: recipe, portions: portions, checked: $checked)
                        .tag(0)
                    ForEach(Array(recipe.s.enumerated()), id: \.offset) { index, step in
                        StepPage(recipe: recipe, step: step, index: index, total: recipe.s.count)
                            .tag(index + 1)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                TimerBar()

                HStack(spacing: 12) {
                    Button {
                        withAnimation { page = max(0, page - 1) }
                    } label: {
                        Label("Zurück", systemImage: "chevron.left")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(page == 0)

                    if page < lastPage {
                        Button {
                            withAnimation { page += 1 }
                        } label: {
                            Text(page == 0 ? "Los geht’s" : "Weiter")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button {
                            dismiss()
                        } label: {
                            Label("Fertig", systemImage: "checkmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .controlSize(.large)
                .padding()
            }
            .navigationTitle(recipe.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
        }
        .tint(Theme.green)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }   // Bildschirm bleibt an
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}

struct IngredientsPage: View {
    let recipe: Recipe
    let portions: Int
    @Binding var checked: Set<Int>

    private var items: [Ingredient] { recipe.g.flatMap { $0.items } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Zutaten bereitlegen")
                    .font(.largeTitle.bold())
                Text("\(portions) \(portions == 1 ? "Portion" : "Portionen") · antippen zum Abhaken")
                    .foregroundStyle(.secondary)

                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    let done = checked.contains(index)
                    Button {
                        if done { checked.remove(index) } else { checked.insert(index) }
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 14) {
                            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(done ? Theme.green : Color.secondary)
                            Text(item.amountText(times: Double(portions)))
                                .fontWeight(.bold)
                            Text(item.name)
                                .strikethrough(done)
                                .foregroundStyle(done ? Color.secondary : Color.primary)
                            Spacer(minLength: 0)
                        }
                        .font(.title2)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
        }
    }
}

struct StepPage: View {
    let recipe: Recipe
    let step: Step
    let index: Int
    let total: Int

    @Environment(CookingTimers.self) private var timers

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Schritt \(index + 1) von \(total)")
                    .font(.headline)
                    .foregroundStyle(Theme.green)
                if !step.title.isEmpty {
                    Text(step.title)
                        .font(.largeTitle.bold())
                }
                Text(step.text)
                    .font(.system(size: 28))
                    .fixedSize(horizontal: false, vertical: true)

                if let minutes = step.timerMinutes {
                    Button {
                        let name = step.title.isEmpty ? "Schritt \(index + 1)" : step.title
                        timers.start(minutes: minutes, label: "\(recipe.name): \(name)")
                    } label: {
                        Label("Timer \(durationText(minutes)) starten", systemImage: "timer")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.gold)
                    .controlSize(.large)
                    .padding(.top, 8)
                }
            }
            .padding(24)
        }
    }
}

struct TimerBar: View {
    @Environment(CookingTimers.self) private var timers

    var body: some View {
        if !timers.timers.isEmpty {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(spacing: 6) {
                    ForEach(timers.timers) { timer in
                        let remaining = max(0, Int(timer.end.timeIntervalSince(context.date).rounded(.up)))
                        HStack(spacing: 10) {
                            Image(systemName: remaining == 0 ? "bell.fill" : "timer")
                                .foregroundStyle(remaining == 0 ? Theme.gold : Theme.green)
                            Text(timer.label)
                                .lineLimit(1)
                                .font(.subheadline)
                            Spacer(minLength: 0)
                            Text(remaining == 0 ? "Fertig!" : String(format: "%d:%02d", remaining / 60, remaining % 60))
                                .font(.title3.bold())
                                .monospacedDigit()
                            Button {
                                timers.cancel(timer)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Timer beenden")
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(remaining == 0 ? Theme.gold.opacity(0.25) : Color(.secondarySystemBackground))
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
    }
}
