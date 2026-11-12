import SwiftUI

/// Formular zum Eintragen und Bearbeiten eigener Rezepte.
struct RecipeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(UserRecipesStore.self) private var userRecipes

    private let existing: Recipe?

    @State private var name: String
    @State private var category: String
    @State private var type: String
    @State private var kcalText: String
    @State private var time: String
    @State private var ingredients: [DraftIngredient]
    @State private var steps: [DraftStep]

    init(existing: Recipe? = nil, defaultCategory: String = "fruehstueck") {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _category = State(initialValue: existing?.cat ?? defaultCategory)
        _type = State(initialValue: existing?.ty ?? "veggie")
        _kcalText = State(initialValue: (existing?.kcal ?? 0) > 0 ? "\(existing!.kcal)" : "")
        _time = State(initialValue: existing?.t ?? "")
        let items = existing?.g.flatMap { $0.items } ?? []
        _ingredients = State(initialValue: items.isEmpty
            ? [DraftIngredient(), DraftIngredient(), DraftIngredient()]
            : items.map { DraftIngredient(from: $0) })
        let savedSteps = existing?.s ?? []
        _steps = State(initialValue: savedSteps.isEmpty
            ? [DraftStep()]
            : savedSteps.map { DraftStep(title: $0.title, text: $0.text) })
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Rezept") {
                    TextField("Name des Rezepts", text: $name)
                    Picker("Kategorie", selection: $category) {
                        ForEach(RecipeCategory.all) { Text($0.title).tag($0.id) }
                    }
                    Picker("Art", selection: $type) {
                        ForEach(RecipeType.all) { Text($0.name).tag($0.id) }
                    }
                    TextField("Kalorien pro Portion (optional)", text: $kcalText)
                        .keyboardType(.numberPad)
                    TextField("Zeit, z. B. 15 Min. (optional)", text: $time)
                }

                Section {
                    ForEach($ingredients) { $item in
                        HStack(spacing: 8) {
                            TextField("Menge", text: $item.amount)
                                .keyboardType(.numbersAndPunctuation)
                                .frame(width: 64)
                            TextField("Einheit", text: $item.unit)
                                .frame(width: 70)
                            TextField("Zutat", text: $item.name)
                        }
                    }
                    .onDelete { ingredients.remove(atOffsets: $0) }
                    .onMove { ingredients.move(fromOffsets: $0, toOffset: $1) }

                    Button {
                        ingredients.append(DraftIngredient())
                    } label: {
                        Label("Zutat hinzufügen", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Zutaten für 1 Portion")
                } footer: {
                    Text("Menge z. B. 150, 1,5, ½ oder 2–3. Einheit z. B. g, ml, EL, TL. Zum Löschen nach links wischen.")
                }

                Section {
                    ForEach($steps) { $step in
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("Kurztitel (optional)", text: $step.title)
                                .font(.headline)
                            TextField("Was ist zu tun?", text: $step.text, axis: .vertical)
                                .lineLimit(2...8)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { steps.remove(atOffsets: $0) }
                    .onMove { steps.move(fromOffsets: $0, toOffset: $1) }

                    Button {
                        steps.append(DraftStep())
                    } label: {
                        Label("Schritt hinzufügen", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Zubereitung")
                }
            }
            .navigationTitle(existing == nil ? "Neues Rezept" : "Rezept bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        let cleanIngredients: [Ingredient] = ingredients.compactMap { draft in
            let amountText = draft.amount.trimmingCharacters(in: .whitespaces)
            let unit = draft.unit.trimmingCharacters(in: .whitespaces)
            let itemName = draft.name.trimmingCharacters(in: .whitespaces)
            if amountText.isEmpty && unit.isEmpty && itemName.isEmpty { return nil }
            if let amount = Ingredient.parseAmount(amountText) {
                return Ingredient(amount: amount, unit: unit, name: itemName)
            }
            // Nicht lesbare Menge (z. B. "etwas"): als Text vor die Zutat schreiben.
            let text = [amountText, unit, itemName].filter { !$0.isEmpty }.joined(separator: " ")
            return Ingredient(amount: nil, unit: "", name: text)
        }
        let cleanSteps: [Step] = steps.compactMap { draft in
            let title = draft.title.trimmingCharacters(in: .whitespaces)
            let text = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if title.isEmpty && text.isEmpty { return nil }
            return Step(title: title, text: text)
        }
        let recipe = Recipe(
            id: existing?.id ?? "eigen-\(UUID().uuidString)",
            cat: category,
            ty: type,
            kcal: Int(kcalText.trimmingCharacters(in: .whitespaces)) ?? 0,
            t: time.trimmingCharacters(in: .whitespaces),
            name: name.trimmingCharacters(in: .whitespaces),
            g: [IngredientGroup(title: "Zutaten", items: cleanIngredients)],
            s: cleanSteps
        )
        userRecipes.save(recipe)
        dismiss()
    }
}

struct DraftIngredient: Identifiable {
    let id = UUID()
    var amount = ""
    var unit = ""
    var name = ""

    init() {}

    init(from ingredient: Ingredient) {
        amount = ingredient.amount.map { $0.map(Ingredient.format).joined(separator: "–") } ?? ""
        unit = ingredient.unit
        name = ingredient.name
    }
}

struct DraftStep: Identifiable {
    let id = UUID()
    var title = ""
    var text = ""
}
