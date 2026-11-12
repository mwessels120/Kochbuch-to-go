import Foundation
import Observation

// MARK: - Zutaten

private enum AmountValue: Decodable {
    case single(Double)
    case range([Double])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(Double.self) {
            self = .single(v)
        } else {
            self = .range(try c.decode([Double].self))
        }
    }
}

struct Ingredient: Codable, Hashable {
    let amount: [Double]?
    let unit: String
    let name: String

    init(amount: [Double]?, unit: String, name: String) {
        self.amount = amount
        self.unit = unit
        self.name = name
    }

    // JSON-Format: [Menge | null | [von, bis], "Einheit", "Name"]
    init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        switch try c.decodeIfPresent(AmountValue.self) {
        case .single(let v)?: amount = [v]
        case .range(let r)?: amount = r
        case nil: amount = nil
        }
        unit = try c.decode(String.self)
        name = try c.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.unkeyedContainer()
        if let amount {
            if amount.count == 1 { try c.encode(amount[0]) } else { try c.encode(amount) }
        } else {
            try c.encodeNil()
        }
        try c.encode(unit)
        try c.encode(name)
    }

    func amountText(times factor: Double) -> String {
        guard let amount else { return "" }
        let value = amount.map { Ingredient.format($0 * factor) }.joined(separator: "–")
        return unit.isEmpty ? value : "\(value) \(unit)"
    }

    static func format(_ v: Double) -> String {
        let whole = Int(v.rounded(.down))
        let rest = ((v - Double(whole)) * 100).rounded() / 100
        let fractions: [Double: String] = [0.25: "¼", 0.5: "½", 0.75: "¾"]
        if rest == 0 { return "\(whole)" }
        if let f = fractions[rest] { return whole > 0 ? "\(whole) \(f)" : f }
        return String(format: "%.1f", v).replacingOccurrences(of: ".", with: ",")
    }

    /// Liest Eingaben wie "150", "1,5", "½", "1 ½" oder "2–3".
    static func parseAmount(_ text: String) -> [Double]? {
        let t = text.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return nil }
        let parts = t.split(whereSeparator: { $0 == "-" || $0 == "–" }).map(String.init)
        var values: [Double] = []
        for part in parts {
            guard let v = parseNumber(part) else { return nil }
            values.append(v)
        }
        return values.isEmpty || values.count > 2 ? nil : values
    }

    private static func parseNumber(_ text: String) -> Double? {
        let fractions: [Character: Double] = ["½": 0.5, "¼": 0.25, "¾": 0.75]
        var t = text.trimmingCharacters(in: .whitespaces)
        var extra = 0.0
        if let last = t.last, let f = fractions[last] {
            extra = f
            t.removeLast()
            t = t.trimmingCharacters(in: .whitespaces)
            if t.isEmpty { return extra }
        }
        guard let v = Double(t.replacingOccurrences(of: ",", with: ".")) else { return nil }
        return v + extra
    }
}

struct IngredientGroup: Codable, Hashable {
    let title: String
    let items: [Ingredient]

    init(title: String, items: [Ingredient]) {
        self.title = title
        self.items = items
    }

    init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        title = try c.decode(String.self)
        items = try c.decode([Ingredient].self)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.unkeyedContainer()
        try c.encode(title)
        try c.encode(items)
    }
}

struct Step: Codable, Hashable {
    let title: String
    let text: String

    init(title: String, text: String) {
        self.title = title
        self.text = text
    }

    init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        title = try c.decode(String.self)
        text = try c.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.unkeyedContainer()
        try c.encode(title)
        try c.encode(text)
    }
}

// MARK: - Rezept

struct Recipe: Codable, Identifiable, Hashable {
    let id: String
    let cat: String
    let ty: String
    let kcal: Int
    let t: String
    let name: String
    let g: [IngredientGroup]
    let s: [Step]

    var category: RecipeCategory { RecipeCategory.of(cat) }
    var type: RecipeType { RecipeType.of(ty) }
    var isCustom: Bool { id.hasPrefix("eigen-") }

    var metaText: String {
        var parts = [type.name]
        if !t.isEmpty { parts.append(t) }
        if isCustom { parts.append("Eigenes Rezept") }
        return parts.joined(separator: " · ")
    }

    func matches(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return true }
        return name.localizedCaseInsensitiveContains(q)
            || g.contains { $0.items.contains { $0.name.localizedCaseInsensitiveContains(q) } }
    }

    func shareText(portions: Int) -> String {
        var info: [String] = []
        if kcal > 0 { info.append("ca. \(kcal) kcal pro Portion") }
        if !t.isEmpty { info.append(t) }
        info.append("\(portions) \(portions == 1 ? "Portion" : "Portionen")")
        var lines = [name, info.joined(separator: " · "), "", "Zutaten:"]
        for group in g {
            if g.count > 1 { lines.append("\(group.title):") }
            for i in group.items {
                let a = i.amountText(times: Double(portions))
                lines.append("• " + (a.isEmpty ? i.name : "\(a) \(i.name)"))
            }
        }
        lines.append("")
        lines.append("Zubereitung:")
        for (n, step) in s.enumerated() {
            lines.append("\(n + 1). " + (step.title.isEmpty ? step.text : "\(step.title): \(step.text)"))
        }
        lines.append("")
        lines.append("Aus „Kochbuch to Go“")
        return lines.joined(separator: "\n")
    }
}

// MARK: - Speicher

@Observable
final class FavoritesStore {
    private(set) var ids: Set<String>
    private let key = "favorites"

    init() {
        ids = Set(UserDefaults.standard.stringArray(forKey: "favorites") ?? [])
    }

    func isFavorite(_ id: String) -> Bool { ids.contains(id) }

    func toggle(_ id: String) {
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
        UserDefaults.standard.set(Array(ids), forKey: key)
    }

    func remove(_ id: String) {
        ids.remove(id)
        UserDefaults.standard.set(Array(ids), forKey: key)
    }
}

/// Eigene Rezepte, gespeichert als JSON-Datei im Dokumente-Ordner der App.
@Observable
final class UserRecipesStore {
    private(set) var recipes: [Recipe] = []
    private let fileURL = URL.documentsDirectory.appending(path: "eigene-rezepte.json")

    init() {
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([Recipe].self, from: data) {
            recipes = saved
        }
    }

    func recipe(withID id: String) -> Recipe? {
        recipes.first { $0.id == id }
    }

    func save(_ recipe: Recipe) {
        if let index = recipes.firstIndex(where: { $0.id == recipe.id }) {
            recipes[index] = recipe
        } else {
            recipes.append(recipe)
        }
        persist()
    }

    func delete(_ id: String) {
        recipes.removeAll { $0.id == id }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(recipes) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
