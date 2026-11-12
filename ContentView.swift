import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            RecipesTab()
                .tabItem { Label("Rezepte", systemImage: "book.fill") }
            WeekPlanView()
                .tabItem { Label("Wochenplan", systemImage: "calendar") }
            ShoppingListView()
                .tabItem { Label("Einkauf", systemImage: "cart.fill") }
            FavoritesTab()
                .tabItem { Label("Favoriten", systemImage: "heart.fill") }
        }
        .tint(Theme.green)
    }
}

// MARK: - Rezepte

struct RecipesTab: View {
    @Environment(UserRecipesStore.self) private var userRecipes
    @State private var category = RecipeCategory.all[0]
    @State private var query = ""
    @State private var typeFilter: String? = nil
    @State private var showEditor = false

    private var recipes: [Recipe] {
        (RecipeData.all + userRecipes.recipes).filter {
            $0.cat == category.id
                && (typeFilter == nil || $0.ty == typeFilter)
                && $0.matches(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    CategoryPicker(selection: $category)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                Section {
                    ForEach(recipes) { recipe in
                        NavigationLink(value: recipe) {
                            RecipeRow(recipe: recipe)
                        }
                    }
                } header: {
                    Text("\(recipes.count) Rezepte · je 1 Portion")
                } footer: {
                    Button {
                        showEditor = true
                    } label: {
                        Label("Eigenes Rezept eintragen", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Kochbuch to Go")
            .navigationDestination(for: Recipe.self) { RecipeDetailView(recipe: $0) }
            .searchable(text: $query, prompt: "Rezept oder Zutat suchen")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    TypeFilterMenu(selection: $typeFilter)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Eigenes Rezept eintragen")
                }
            }
            .sheet(isPresented: $showEditor) {
                RecipeEditorView(defaultCategory: category.id)
            }
            .overlay {
                if recipes.isEmpty {
                    ContentUnavailableView("Keine Rezepte gefunden",
                                           systemImage: "magnifyingglass",
                                           description: Text("Ändere die Suche oder den Filter."))
                }
            }
        }
    }
}

struct CategoryPicker: View {
    @Binding var selection: RecipeCategory

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(RecipeCategory.all) { cat in
                    let selected = cat == selection
                    Button {
                        withAnimation(.snappy) { selection = cat }
                    } label: {
                        Label(cat.title, systemImage: cat.icon)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .foregroundStyle(selected ? Color.white : Color.primary)
                            .background(
                                Capsule().fill(selected ? Theme.green : Color(.secondarySystemBackground))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 6)
        }
    }
}

struct TypeFilterMenu: View {
    @Binding var selection: String?

    var body: some View {
        Menu {
            Picker("Filter", selection: $selection) {
                Text("Alle").tag(String?.none)
                ForEach(RecipeType.all) { type in
                    Text(type.name).tag(Optional(type.id))
                }
            }
        } label: {
            Image(systemName: selection == nil
                  ? "line.3.horizontal.decrease.circle"
                  : "line.3.horizontal.decrease.circle.fill")
        }
        .accessibilityLabel("Filter")
    }
}

struct RecipeRow: View {
    let recipe: Recipe
    @Environment(FavoritesStore.self) private var favorites

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(recipe.type.color.opacity(0.15))
                VStack(spacing: 0) {
                    if recipe.kcal > 0 {
                        Text("\(recipe.kcal)")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                        Text("kcal")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: recipe.isCustom ? "pencil" : "fork.knife")
                            .font(.headline)
                            .foregroundStyle(recipe.type.color)
                    }
                }
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(.headline)
                HStack(spacing: 6) {
                    Circle().fill(recipe.type.color).frame(width: 8, height: 8)
                    Text(recipe.metaText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            if favorites.isFavorite(recipe.id) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.pink)
                    .accessibilityLabel("Favorit")
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Favoriten

struct FavoritesTab: View {
    @Environment(FavoritesStore.self) private var favorites
    @Environment(UserRecipesStore.self) private var userRecipes

    private var recipes: [Recipe] {
        (RecipeData.all + userRecipes.recipes).filter { favorites.isFavorite($0.id) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(RecipeCategory.all) { cat in
                    let items = recipes.filter { $0.cat == cat.id }
                    if !items.isEmpty {
                        Section(cat.title) {
                            ForEach(items) { recipe in
                                NavigationLink(value: recipe) { RecipeRow(recipe: recipe) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Favoriten")
            .navigationDestination(for: Recipe.self) { RecipeDetailView(recipe: $0) }
            .overlay {
                if recipes.isEmpty {
                    ContentUnavailableView("Noch keine Favoriten",
                                           systemImage: "heart",
                                           description: Text("Tippe in einem Rezept auf das Herz, um es hier zu speichern."))
                }
            }
        }
    }
}

// MARK: - Detail

struct RecipeDetailView: View {
    let initial: Recipe
    @Environment(FavoritesStore.self) private var favorites
    @Environment(UserRecipesStore.self) private var userRecipes
    @Environment(PlannerStore.self) private var planner
    @Environment(\.dismiss) private var dismiss
    @State private var portions = 1
    @State private var plannedDay: Int?
    @State private var showCooking = false
    @State private var showEditor = false
    @State private var confirmDelete = false

    init(recipe: Recipe) {
        self.initial = recipe
    }

    /// Bei eigenen Rezepten immer die aktuelle, gespeicherte Fassung anzeigen.
    private var recipe: Recipe {
        initial.isCustom ? (userRecipes.recipe(withID: initial.id) ?? initial) : initial
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                VStack(alignment: .leading, spacing: 8) {
                    Label(recipe.category.title, systemImage: recipe.category.icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.green)
                    Text(recipe.name)
                        .font(.largeTitle.bold())
                        .fixedSize(horizontal: false, vertical: true)
                    if recipe.isCustom {
                        Label("Eigenes Rezept", systemImage: "pencil")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 10) {
                    if recipe.kcal > 0 {
                        FactBox(value: "\(recipe.kcal)", label: "kcal pro Portion")
                    }
                    if !recipe.t.isEmpty {
                        FactBox(value: recipe.t, label: "Zeit")
                    }
                    FactBox(value: recipe.type.name, label: "Art", color: recipe.type.color)
                }

                Button {
                    showCooking = true
                } label: {
                    Label("Kochmodus starten", systemImage: "frying.pan.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Zutaten").font(.title2.bold())
                        Spacer()
                        Stepper(value: $portions, in: 1...8) {
                            Text("\(portions) \(portions == 1 ? "Portion" : "Portionen")")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .fixedSize()
                    }

                    ForEach(Array(recipe.g.enumerated()), id: \.offset) { _, group in
                        if recipe.g.count > 1 {
                            Text(group.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.green)
                                .padding(.top, 6)
                        }
                        VStack(spacing: 0) {
                            ForEach(Array(group.items.enumerated()), id: \.offset) { _, item in
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    Text(item.amountText(times: Double(portions)))
                                        .fontWeight(.semibold)
                                        .frame(width: 100, alignment: .leading)
                                    Text(item.name)
                                    Spacer(minLength: 0)
                                }
                                .padding(.vertical, 9)
                                Divider()
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("Zubereitung").font(.title2.bold())
                    ForEach(Array(recipe.s.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(Theme.green))
                            VStack(alignment: .leading, spacing: 3) {
                                if !step.title.isEmpty {
                                    Text(step.title).font(.headline)
                                }
                                Text(step.text)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                if recipe.isCustom {
                    Button {
                        showEditor = true
                    } label: {
                        Label("Rezept bearbeiten", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("Rezept löschen", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Text("Kalorien sind ungefähre Richtwerte pro Portion.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditor) {
            RecipeEditorView(existing: recipe)
        }
        .fullScreenCover(isPresented: $showCooking) {
            CookingModeView(recipe: recipe, portions: portions)
        }
        .alert("Eingeplant", isPresented: Binding(get: { plannedDay != nil }, set: { if !$0 { plannedDay = nil } })) {
            Button("OK") { plannedDay = nil }
        } message: {
            Text("„\(recipe.name)“ steht jetzt am \(Weekday.names[plannedDay ?? 0]) im Wochenplan.")
        }
        .confirmationDialog("„\(recipe.name)“ wirklich löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                favorites.remove(recipe.id)
                planner.removeRecipeEverywhere(recipe.id)
                userRecipes.delete(recipe.id)
                dismiss()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Section("Zum Wochenplan (\(recipe.category.title))") {
                        ForEach(0..<7, id: \.self) { day in
                            Button(Weekday.names[day]) {
                                planner.set(recipe.id, day: day, category: recipe.cat)
                                plannedDay = day
                            }
                        }
                    }
                } label: {
                    Image(systemName: "calendar.badge.plus")
                }
                .accessibilityLabel("Zum Wochenplan hinzufügen")
                ShareLink(item: recipe.shareText(portions: portions))
                Button {
                    favorites.toggle(recipe.id)
                } label: {
                    Image(systemName: favorites.isFavorite(recipe.id) ? "heart.fill" : "heart")
                        .foregroundStyle(.pink)
                }
                .accessibilityLabel(favorites.isFavorite(recipe.id) ? "Aus Favoriten entfernen" : "Zu Favoriten hinzufügen")
            }
        }
    }
}

struct FactBox: View {
    let value: String
    let label: String
    var color: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
    }
}
