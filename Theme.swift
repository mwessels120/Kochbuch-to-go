import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

enum Theme {
    static let green = Color(hex: 0x2F6D4F)
    static let gold = Color(hex: 0xE2AE2A)
}

struct RecipeCategory: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String

    static let all: [RecipeCategory] = [
        RecipeCategory(id: "fruehstueck", title: "Frühstück", icon: "sunrise.fill"),
        RecipeCategory(id: "mittag", title: "Mittagessen", icon: "fork.knife"),
        RecipeCategory(id: "snack", title: "Snacks", icon: "carrot.fill"),
        RecipeCategory(id: "abend", title: "Abendessen", icon: "moon.stars.fill"),
        RecipeCategory(id: "dessert", title: "Desserts", icon: "birthday.cake.fill")
    ]

    static func of(_ id: String) -> RecipeCategory {
        all.first { $0.id == id } ?? all[0]
    }
}

struct RecipeType: Identifiable, Hashable {
    let id: String
    let name: String
    let color: Color

    static let all: [RecipeType] = [
        RecipeType(id: "veggie", name: "Vegetarisch", color: Color(hex: 0x5E8C3A)),
        RecipeType(id: "haehnchen", name: "Hähnchen", color: Color(hex: 0xD49A16)),
        RecipeType(id: "pute", name: "Pute", color: Color(hex: 0xB07A2E)),
        RecipeType(id: "rind", name: "Rind", color: Color(hex: 0xA8483A)),
        RecipeType(id: "schwein", name: "Schwein", color: Color(hex: 0xD9788A)),
        RecipeType(id: "fisch", name: "Fisch", color: Color(hex: 0x4A6FA5))
    ]

    static func of(_ id: String) -> RecipeType {
        all.first { $0.id == id } ?? all[0]
    }
}
