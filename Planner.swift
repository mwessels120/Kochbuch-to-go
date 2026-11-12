import SwiftUI
import Observation

enum Weekday {
    static let names = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"]

    /// 0 = Montag … 6 = Sonntag
    static var todayIndex: Int {
        (Calendar.current.component(.weekday, from: .now) + 5) % 7
    }
}

struct ShoppingItem: Identifiable, Hashable {
    let id: String
    let name: String
    let amount: String
    let recipeCount: Int
}

/// Wochenplan und Einkaufsliste, gespeichert in den App-Einstellungen.
@Observable
final class PlannerStore {
    private(set) var plan: [String: String] = [:]      // "Tag|Kategorie" -> Rezept-ID
    private(set) var people: Int = 1
    private(set) var checked: Set<String> = []
    private(set) var extras: [String] = []

    private let defaults = UserDefaults.standard

    init() {
        plan = (defaults.dictionary(forKey: "plan") as? [String: String]) ?? [:]
        people = max(1, defaults.integer(forKey: "people"))
        checked = Set(defaults.stringArray(forKey: "checked") ?? [])
        extras = defaults.stringArray(forKey: "extras") ?? []
    }

    static func key(_ day: Int, _ category: String) -> String { "\(day)|\(category)" }

    var plannedCount: Int { plan.count }

    func recipeID(day: Int, category: String) -> String? {
        plan[Self.key(day, category)]
    }

    func set(_ recipeID: String?, day: Int, category: String) {
        plan[Self.key(day, category)] = recipeID
        save()
    }

    func clearPlan() {
        plan = [:]
        checked = []
        save()
    }

    func removeRecipeEverywhere(_ id: String) {
        plan = plan.filter { $0.value != id }
        save()
    }

    /// Füllt nur leere Plätze (Frühstück, Mittag, Snack, Abend) mit zufälligen Rezepten.
    func fillEmptySlots(with recipes: [Recipe]) {
        for day in 0..<7 {
            for category in ["fruehstueck", "mittag", "snack", "abend"] where plan[Self.key(day, category)] == nil {
                if let pick = recipes.filter({ $0.cat == category }).randomElement() {
                    plan[Self.key(day, category)] = pick.id
                }
            }
        }
        save()
    }

    func setPeople(_ value: Int) {
        people = max(1, value)
        save()
    }

    func isChecked(_ key: String) -> Bool { checked.contains(key) }

    func toggleChecked(_ key: String) {
        if checked.contains(key) { checked.remove(key) } else { checked.insert(key) }
        save()
    }

    func resetChecks() {
        checked = []
        save()
    }

    func addExtra(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, !extras.contains(t) else { return }
        extras.append(t)
        save()
    }

    func removeExtras(at offsets: IndexSet) {
        for i in offsets { checked.remove("extra|" + extras[i]) }
        extras.remove(atOffsets: offsets)
        save()
    }

    func plannedRecipes(from all: [Recipe]) -> [Recipe] {
        let byID = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return plan.values.compactMap { byID[$0] }
    }

    /// Fasst gleiche Zutaten (gleicher Name und gleiche Einheit) zusammen.
    static func shoppingList(for recipes: [Recipe], people: Int) -> [ShoppingItem] {
        struct Acc {
            var name: String
            var unit: String
            var total: Double
            var hasAmount: Bool
            var recipeIDs: Set<String>
        }
        var acc: [String: Acc] = [:]
        for recipe in recipes {
            for group in recipe.g {
                for item in group.items {
                    let key = item.name.lowercased() + "|" + item.unit.lowercased()
                    var entry = acc[key] ?? Acc(name: item.name, unit: item.unit, total: 0, hasAmount: false, recipeIDs: [])
                    if let amount = item.amount {
                        entry.total += amount.max() ?? 0
                        entry.hasAmount = true
                    }
                    entry.recipeIDs.insert(recipe.id)
                    acc[key] = entry
                }
            }
        }
        return acc.map { key, entry in
            let amount = entry.hasAmount
                ? Ingredient.format(entry.total * Double(people)) + (entry.unit.isEmpty ? "" : " \(entry.unit)")
                : ""
            return ShoppingItem(id: key, name: entry.name, amount: amount, recipeCount: entry.recipeIDs.count)
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func save() {
        defaults.set(plan, forKey: "plan")
        defaults.set(people, forKey: "people")
        defaults.set(Array(checked), forKey: "checked")
        defaults.set(extras, forKey: "extras")
    }
}
