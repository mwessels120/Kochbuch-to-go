import SwiftUI

// MARK: - Wochenplan

struct PlannedMeal: Identifiable {
    let category: RecipeCategory
    let recipe: Recipe
    var id: String { category.id }
}

struct PickTarget: Identifiable {
    let day: Int
    let category: RecipeCategory
    var id: String { "\(day)|\(category.id)" }
}

struct WeekPlanView: View {
    @Environment(PlannerStore.self) private var planner
    @Environment(UserRecipesStore.self) private var userRecipes
    @State private var picking: PickTarget?
    @State private var confirmClear = false

    private var allRecipes: [Recipe] { RecipeData.all + userRecipes.recipes }

    private func meals(for day: Int) -> [PlannedMeal] {
        RecipeCategory.all.compactMap { cat in
            guard let id = planner.recipeID(day: day, category: cat.id),
                  let recipe = allRecipes.first(where: { $0.id == id }) else { return nil }
            return PlannedMeal(category: cat, recipe: recipe)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(0..<7, id: \.self) { day in
                    let planned = meals(for: day)
                    let missing = RecipeCategory.all.filter { cat in !planned.contains { $0.category == cat } }
                    let kcal = planned.reduce(0) { $0 + $1.recipe.kcal }

                    Section {
                        ForEach(planned) { meal in
                            NavigationLink(value: meal.recipe) {
                                PlanRow(meal: meal)
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    planner.set(nil, day: day, category: meal.category.id)
                                } label: {
                                    Label("Entfernen", systemImage: "trash")
                                }
                                Button {
                                    picking = PickTarget(day: day, category: meal.category)
                                } label: {
                                    Label("Tauschen", systemImage: "arrow.triangle.2.circlepath")
                                }
                                .tint(Theme.green)
                            }
                        }
                        if !missing.isEmpty {
                            Menu {
                                ForEach(missing) { cat in
                                    Button {
                                        picking = PickTarget(day: day, category: cat)
                                    } label: {
                                        Label(cat.title, systemImage: cat.icon)
                                    }
                                }
                            } label: {
                                Label("Mahlzeit hinzufügen", systemImage: "plus.circle")
                                    .font(.subheadline)
                            }
                        }
                    } header: {
                        HStack {
                            Text(Weekday.names[day] + (day == Weekday.todayIndex ? " · Heute" : ""))
                            Spacer()
                            if kcal > 0 {
                                Text("ca. \(kcal) kcal")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Wochenplan")
            .navigationDestination(for: Recipe.self) { RecipeDetailView(recipe: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            planner.fillEmptySlots(with: allRecipes)
                        } label: {
                            Label("Leere Plätze zufällig füllen", systemImage: "dice")
                        }
                        Button(role: .destructive) {
                            confirmClear = true
                        } label: {
                            Label("Plan leeren", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Weitere Aktionen")
                }
            }
            .confirmationDialog("Ganzen Wochenplan leeren?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Plan leeren", role: .destructive) { planner.clearPlan() }
            }
            .sheet(item: $picking) { target in
                RecipePickerView(category: target.category) { recipe in
                    planner.set(recipe.id, day: target.day, category: target.category.id)
                }
            }
        }
    }
}

struct PlanRow: View {
    let meal: PlannedMeal

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: meal.category.icon)
                .foregroundStyle(meal.recipe.type.color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(meal.category.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(meal.recipe.name)
                    .font(.body)
            }
            Spacer(minLength: 0)
            if meal.recipe.kcal > 0 {
                Text("\(meal.recipe.kcal) kcal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct RecipePickerView: View {
    let category: RecipeCategory
    let onPick: (Recipe) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(UserRecipesStore.self) private var userRecipes
    @State private var query = ""

    private var recipes: [Recipe] {
        (RecipeData.all + userRecipes.recipes).filter { $0.cat == category.id && $0.matches(query) }
    }

    var body: some View {
        NavigationStack {
            List(recipes) { recipe in
                Button {
                    onPick(recipe)
                    dismiss()
                } label: {
                    RecipeRow(recipe: recipe)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .navigationTitle(category.title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Rezept suchen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Einkaufsliste

struct ShoppingListView: View {
    @Environment(PlannerStore.self) private var planner
    @Environment(UserRecipesStore.self) private var userRecipes
    @State private var newItem = ""

    private var items: [ShoppingItem] {
        PlannerStore.shoppingList(
            for: planner.plannedRecipes(from: RecipeData.all + userRecipes.recipes),
            people: planner.people
        )
    }

    private func shareText(open: [ShoppingItem]) -> String {
        var lines = ["Einkaufsliste (Kochbuch to Go)", ""]
        for item in open {
            lines.append("• " + (item.amount.isEmpty ? item.name : "\(item.amount) \(item.name)"))
        }
        for extra in planner.extras where !planner.isChecked("extra|" + extra) {
            lines.append("• " + extra)
        }
        return lines.joined(separator: "\n")
    }

    private func addExtra() {
        planner.addExtra(newItem)
        newItem = ""
    }

    var body: some View {
        let all = items
        let open = all.filter { !planner.isChecked($0.id) }
        let done = all.filter { planner.isChecked($0.id) }

        NavigationStack {
            List {
                Section {
                    Stepper(value: Binding(get: { planner.people }, set: { planner.setPeople($0) }), in: 1...10) {
                        Text("Für \(planner.people) \(planner.people == 1 ? "Person" : "Personen")")
                    }
                } footer: {
                    Text("Berechnet aus \(planner.plannedCount) geplanten Mahlzeiten im Wochenplan.")
                }

                if !open.isEmpty {
                    Section("Zu kaufen (\(open.count))") {
                        ForEach(open) { item in
                            ShoppingRow(name: item.name, amount: item.amount, recipeCount: item.recipeCount, checked: false) {
                                planner.toggleChecked(item.id)
                            }
                        }
                    }
                }

                Section("Eigene Artikel") {
                    ForEach(planner.extras, id: \.self) { extra in
                        ShoppingRow(name: extra, amount: "", recipeCount: 0, checked: planner.isChecked("extra|" + extra)) {
                            planner.toggleChecked("extra|" + extra)
                        }
                    }
                    .onDelete { planner.removeExtras(at: $0) }

                    HStack {
                        TextField("Artikel hinzufügen, z. B. Kaffee", text: $newItem)
                            .onSubmit(addExtra)
                        Button(action: addExtra) {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityLabel("Artikel hinzufügen")
                    }
                }

                if !done.isEmpty {
                    Section("Erledigt (\(done.count))") {
                        ForEach(done) { item in
                            ShoppingRow(name: item.name, amount: item.amount, recipeCount: item.recipeCount, checked: true) {
                                planner.toggleChecked(item.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Einkaufsliste")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    ShareLink(item: shareText(open: open))
                    Menu {
                        Button {
                            planner.resetChecks()
                        } label: {
                            Label("Alle Häkchen entfernen", systemImage: "arrow.uturn.backward")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Weitere Aktionen")
                }
            }
            .overlay {
                if all.isEmpty && planner.extras.isEmpty {
                    ContentUnavailableView("Noch nichts geplant",
                                           systemImage: "cart",
                                           description: Text("Plane im Wochenplan deine Mahlzeiten. Die Zutaten erscheinen dann automatisch hier."))
                }
            }
        }
    }
}

struct ShoppingRow: View {
    let name: String
    let amount: String
    let recipeCount: Int
    let checked: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 12) {
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(checked ? Theme.green : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .strikethrough(checked)
                        .foregroundStyle(checked ? Color.secondary : Color.primary)
                    if recipeCount > 1 {
                        Text("für \(recipeCount) Rezepte")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                if !amount.isEmpty {
                    Text(amount)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(checked ? "erledigt" : "offen")
    }
}
