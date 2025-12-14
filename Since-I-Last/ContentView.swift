import SwiftUI
import Combine
import UserNotifications

// MARK: - Theme

enum AppTheme: String, CaseIterable, Codable {
    case ocean = "Ocean"
    case sunset = "Sunset"
    case forest = "Forest"
    case lavender = "Lavender"
    case monochrome = "Monochrome"
    
    var colors: ThemeColors {
        switch self {
        case .ocean:
            return ThemeColors(
                primary: Color(red: 0.25, green: 0.67, blue: 0.84),
                accent: Color(red: 0.95, green: 0.61, blue: 0.47),
                success: Color(red: 0.4, green: 0.78, blue: 0.65),
                warning: Color(red: 0.98, green: 0.73, blue: 0.38),
                attention: Color(red: 0.95, green: 0.55, blue: 0.55)
            )
        case .sunset:
            return ThemeColors(
                primary: Color(red: 0.95, green: 0.52, blue: 0.38),
                accent: Color(red: 0.98, green: 0.73, blue: 0.38),
                success: Color(red: 0.4, green: 0.78, blue: 0.65),
                warning: Color(red: 0.95, green: 0.61, blue: 0.73),
                attention: Color(red: 0.85, green: 0.35, blue: 0.35)
            )
        case .forest:
            return ThemeColors(
                primary: Color(red: 0.35, green: 0.65, blue: 0.45),
                accent: Color(red: 0.75, green: 0.85, blue: 0.35),
                success: Color(red: 0.25, green: 0.75, blue: 0.55),
                warning: Color(red: 0.85, green: 0.65, blue: 0.35),
                attention: Color(red: 0.85, green: 0.45, blue: 0.35)
            )
        case .lavender:
            return ThemeColors(
                primary: Color(red: 0.65, green: 0.55, blue: 0.95),
                accent: Color(red: 0.95, green: 0.61, blue: 0.73),
                success: Color(red: 0.55, green: 0.85, blue: 0.75),
                warning: Color(red: 0.95, green: 0.75, blue: 0.55),
                attention: Color(red: 0.95, green: 0.55, blue: 0.55)
            )
        case .monochrome:
            return ThemeColors(
                primary: Color(red: 0.3, green: 0.3, blue: 0.3),
                accent: Color(red: 0.5, green: 0.5, blue: 0.5),
                success: Color(red: 0.4, green: 0.4, blue: 0.4),
                warning: Color(red: 0.6, green: 0.6, blue: 0.6),
                attention: Color(red: 0.7, green: 0.7, blue: 0.7)
            )
        }
    }
}

struct ThemeColors {
    let primary: Color
    let accent: Color
    let success: Color
    let warning: Color
    let attention: Color
    
    static let background = Color(red: 0.97, green: 0.97, blue: 0.98)
    static let cardBackground = Color.white
}

// MARK: - Models

struct Thing: Identifiable, Codable {
    let id: UUID
    var name: String
    var category: Category
    var goalFrequency: Int?
    var events: [Event]
    var createdAt: Date
    var tags: [String]
    var remindersEnabled: Bool
    var emoji: String?
    var isDeleted: Bool
    var deletedAt: Date?
    
    init(id: UUID = UUID(), name: String, category: Category = .personal, goalFrequency: Int? = nil, tags: [String] = [], remindersEnabled: Bool = false, emoji: String? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.goalFrequency = goalFrequency
        self.events = []
        self.createdAt = Date()
        self.tags = tags
        self.remindersEnabled = remindersEnabled
        self.emoji = emoji
        self.isDeleted = false
        self.deletedAt = nil
    }
    
    var lastEvent: Event? {
        events.sorted(by: { $0.timestamp > $1.timestamp }).first
    }
    
    var daysSinceLastEvent: Int? {
        guard let last = lastEvent else { return nil }
        return Calendar.current.dateComponents([.day], from: last.timestamp, to: Date()).day
    }
    
    var averageFrequency: Int? {
        guard events.count >= 2 else { return nil }
        let sorted = events.sorted(by: { $0.timestamp < $1.timestamp })
        var gaps: [Int] = []
        
        for i in 1..<sorted.count {
            if let days = Calendar.current.dateComponents([.day], from: sorted[i-1].timestamp, to: sorted[i].timestamp).day {
                gaps.append(days)
            }
        }
        
        guard !gaps.isEmpty else { return nil }
        return gaps.reduce(0, +) / gaps.count
    }
    
    var suggestedGoalFrequency: Int? {
        guard let avg = averageFrequency, events.count >= 3 else { return nil }
        return avg
    }
    
    var nextSuggestedDate: Date? {
        guard let last = lastEvent?.timestamp, let avg = averageFrequency else { return nil }
        return Calendar.current.date(byAdding: .day, value: avg, to: last)
    }
    
    var streak: Int {
        guard events.count >= 2 else { return events.isEmpty ? 0 : 1 }
        let sorted = events.sorted(by: { $0.timestamp > $1.timestamp })
        var currentStreak = 1
        
        for i in 1..<sorted.count {
            let days = Calendar.current.dateComponents([.day], from: sorted[i].timestamp, to: sorted[i-1].timestamp).day ?? 0
            if let goal = goalFrequency, days <= goal + 3 {
                currentStreak += 1
            } else if days <= 10 {
                currentStreak += 1
            } else {
                break
            }
        }
        
        return currentStreak
    }
    
    var status: ThingStatus {
        guard let days = daysSinceLastEvent, let goal = goalFrequency else {
            return .noData
        }
        
        if days >= goal + 2 {
            return .needsAttention
        } else if days >= goal - 2 {
            return .upcoming
        } else {
            return .onTrack
        }
    }
}

enum ThingStatus {
    case noData
    case onTrack
    case upcoming
    case needsAttention
    
    func color(theme: ThemeColors) -> Color {
        switch self {
        case .noData: return .secondary
        case .onTrack: return theme.success
        case .upcoming: return theme.warning
        case .needsAttention: return theme.attention
        }
    }
    
    func gradient(theme: ThemeColors) -> LinearGradient {
        let color = self.color(theme: theme)
        return LinearGradient(colors: [color.opacity(0.3), color.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct Event: Identifiable, Codable {
    let id: UUID
    var timestamp: Date
    var note: String?
    
    init(id: UUID = UUID(), timestamp: Date = Date(), note: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.note = note
    }
}

enum Category: String, CaseIterable, Codable {
    case home = "Home"
    case health = "Health"
    case relationships = "Relationships"
    case training = "Training"
    case lifeAdmin = "Life Admin"
    case personal = "Personal"
    
    func color(theme: ThemeColors) -> Color {
        switch self {
        case .home: return theme.primary
        case .health: return theme.attention
        case .relationships: return Color(red: 0.95, green: 0.61, blue: 0.73)
        case .training: return Color(red: 0.65, green: 0.55, blue: 0.95)
        case .lifeAdmin: return theme.warning
        case .personal: return theme.success
        }
    }
    
    func gradient(theme: ThemeColors) -> LinearGradient {
        let color = self.color(theme: theme)
        return LinearGradient(colors: [color.opacity(0.6), color.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .health: return "heart.fill"
        case .relationships: return "person.2.fill"
        case .training: return "figure.run"
        case .lifeAdmin: return "doc.fill"
        case .personal: return "star.fill"
        }
    }
}

enum SortOption: String, CaseIterable {
    case needsAttention = "Needs Attention First"
    case recent = "Recently Done"
    case alphabetical = "A-Z"
    case category = "By Category"
}

// MARK: - Data Manager

class DataManager: ObservableObject {
    @Published var things: [Thing] = []
    @Published var currentTheme: AppTheme = .ocean
    
    private let saveKey = "SavedThings"
    private let themeKey = "AppTheme"
    private let trashRetentionDays = 7
    
    init() {
        loadTheme()
        load()
        cleanupOldTrash()
        requestNotificationPermission()
    }
    
    var activeThings: [Thing] {
        things.filter { !$0.isDeleted }
    }
    
    var trashedThings: [Thing] {
        things.filter { $0.isDeleted }
    }
    
    func addThing(_ thing: Thing) {
        things.append(thing)
        save()
        if thing.remindersEnabled {
            scheduleReminder(for: thing)
        }
    }
    
    func updateThing(_ thing: Thing) {
        if let index = things.firstIndex(where: { $0.id == thing.id }) {
            things[index] = thing
            save()
            
            cancelReminder(for: thing)
            if thing.remindersEnabled {
                scheduleReminder(for: thing)
            }
        }
    }
    
    func softDeleteThing(_ thing: Thing) {
        var updated = thing
        updated.isDeleted = true
        updated.deletedAt = Date()
        updateThing(updated)
        cancelReminder(for: thing)
    }
    
    func restoreThing(_ thing: Thing) {
        var updated = thing
        updated.isDeleted = false
        updated.deletedAt = nil
        updateThing(updated)
    }
    
    func permanentlyDeleteThing(_ thing: Thing) {
        cancelReminder(for: thing)
        things.removeAll { $0.id == thing.id }
        save()
    }
    
    func addEvent(to thing: Thing, event: Event) {
        var updated = thing
        updated.events.append(event)
        updateThing(updated)
    }
    
    func exportData() -> String {
        let activeData = activeThings
        guard let data = try? JSONEncoder().encode(activeData),
              let json = String(data: data, encoding: .utf8) else {
            return ""
        }
        return json
    }
    
    func importData(from json: String) -> Bool {
        guard let data = json.data(using: .utf8),
              let imported = try? JSONDecoder().decode([Thing].self, from: data) else {
            return false
        }
        
        for importedThing in imported {
            if !things.contains(where: { $0.id == importedThing.id }) {
                things.append(importedThing)
            }
        }
        save()
        return true
    }
    
    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: themeKey)
    }
    
    private func loadTheme() {
        if let savedTheme = UserDefaults.standard.string(forKey: themeKey),
           let theme = AppTheme(rawValue: savedTheme) {
            currentTheme = theme
        }
    }
    
    private func cleanupOldTrash() {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -trashRetentionDays, to: Date())!
        let toDelete = trashedThings.filter { thing in
            guard let deletedAt = thing.deletedAt else { return false }
            return deletedAt < cutoffDate
        }
        
        for thing in toDelete {
            permanentlyDeleteThing(thing)
        }
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(things) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([Thing].self, from: data) {
            things = decoded
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
    
    private func scheduleReminder(for thing: Thing) {
        guard thing.remindersEnabled else { return }
        
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Just a friendly nudge 👋"
        content.body = "Haven't done \(thing.name) in a while—care to check in?"
        content.sound = .default
        
        let daysToWait = thing.goalFrequency ?? thing.averageFrequency ?? 7
        
        var dateComponents = DateComponents()
        if let lastDate = thing.lastEvent?.timestamp {
            dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: lastDate)
            dateComponents.day = (dateComponents.day ?? 0) + daysToWait
            dateComponents.hour = 10
            dateComponents.minute = 0
        }
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: thing.id.uuidString, content: content, trigger: trigger)
        
        center.add(request)
    }
    
    private func cancelReminder(for thing: Thing) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [thing.id.uuidString])
    }
}

// MARK: - Content View

struct ContentView: View {
    @StateObject private var dataManager = DataManager()
    
    var body: some View {
        HomeView()
            .environmentObject(dataManager)
    }
}

// MARK: - Home View

struct HomeView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingAddThing = false
    @State private var selectedCategory: Category?
    @State private var searchText = ""
    @State private var sortOption: SortOption = .needsAttention
    @State private var showingStats = false
    @State private var showingSettings = false
    @State private var showingTrash = false
    @State private var celebratingThing: Thing?
    
    var filteredThings: [Thing] {
        var filtered = dataManager.activeThings
        
        if let category = selectedCategory {
            filtered = filtered.filter { $0.category == category }
        }
        
        if !searchText.isEmpty {
            filtered = filtered.filter { thing in
                thing.name.localizedCaseInsensitiveContains(searchText) ||
                thing.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        switch sortOption {
        case .needsAttention:
            filtered.sort { t1, t2 in
                let order: [ThingStatus] = [.needsAttention, .upcoming, .onTrack, .noData]
                let i1 = order.firstIndex(of: t1.status) ?? 999
                let i2 = order.firstIndex(of: t2.status) ?? 999
                return i1 < i2
            }
        case .recent:
            filtered.sort { ($0.lastEvent?.timestamp ?? .distantPast) > ($1.lastEvent?.timestamp ?? .distantPast) }
        case .alphabetical:
            filtered.sort { $0.name < $1.name }
        case .category:
            filtered.sort { $0.category.rawValue < $1.category.rawValue }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                ThemeColors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if !dataManager.activeThings.isEmpty {
                        searchBar
                        categoryPicker
                    }
                    
                    if filteredThings.isEmpty {
                        emptyState
                    } else {
                        thingsList
                    }
                }
                .navigationTitle("Since I Last")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Menu {
                            Picker("Sort", selection: $sortOption) {
                                ForEach(SortOption.allCases, id: \.self) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down.circle.fill")
                                .foregroundColor(dataManager.currentTheme.colors.primary)
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 16) {
                            Button(action: { showingTrash = true }) {
                                Image(systemName: "trash")
                                    .foregroundColor(dataManager.currentTheme.colors.primary)
                            }
                            
                            Button(action: { showingSettings = true }) {
                                Image(systemName: "gearshape.fill")
                                    .foregroundColor(dataManager.currentTheme.colors.primary)
                            }
                            
                            Button(action: { showingStats = true }) {
                                Image(systemName: "chart.bar.fill")
                                    .foregroundColor(dataManager.currentTheme.colors.primary)
                            }
                            
                            Button(action: { showingAddThing = true }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(dataManager.currentTheme.colors.accent)
                            }
                        }
                    }
                }
                
                if celebratingThing != nil {
                    ConfettiView()
                        .allowsHitTesting(false)
                }
            }
            .sheet(isPresented: $showingAddThing) {
                AddThingView()
            }
            .sheet(isPresented: $showingStats) {
                StatsView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingTrash) {
                TrashView()
            }
        }
        .navigationViewStyle(.stack)
    }
    
    var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(dataManager.currentTheme.colors.primary)
            
            TextField("Search or filter by tag", text: $searchText)
                .textInputAutocapitalization(.never)
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(ThemeColors.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                CategoryChip(
                    title: "All",
                    icon: "square.grid.2x2.fill",
                    color: dataManager.currentTheme.colors.primary,
                    isSelected: selectedCategory == nil
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedCategory = nil
                    }
                }
                
                ForEach(Category.allCases, id: \.self) { category in
                    CategoryChip(
                        title: category.rawValue,
                        icon: category.icon,
                        color: category.color(theme: dataManager.currentTheme.colors),
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }
    
    var thingsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredThings) { thing in
                    ThingCard(thing: thing) {
                        quickLog(thing)
                    }
                }
            }
            .padding()
        }
    }
    
    var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: searchText.isEmpty ? "clock.badge.checkmark" : "magnifyingglass")
                .font(.system(size: 70))
                .foregroundStyle(
                    LinearGradient(
                        colors: [dataManager.currentTheme.colors.primary, dataManager.currentTheme.colors.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 8) {
                Text(searchText.isEmpty ? "Nothing here yet" : "No matches")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(searchText.isEmpty ? "What will you track first?" : "Try a different search term")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if searchText.isEmpty {
                Button(action: { showingAddThing = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Your First Thing")
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [dataManager.currentTheme.colors.primary, dataManager.currentTheme.colors.accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: dataManager.currentTheme.colors.primary.opacity(0.3), radius: 8, y: 4)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    func quickLog(_ thing: Thing) {
        let event = Event()
        dataManager.addEvent(to: thing, event: event)
        
        celebratingThing = thing
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            celebratingThing = nil
        }
    }
}

// MARK: - Thing Card

struct ThingCard: View {
    let thing: Thing
    let onQuickLog: () -> Void
    
    @EnvironmentObject var dataManager: DataManager
    @State private var showingDetail = false
    @State private var showingEdit = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: { showingDetail = true }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    HStack(spacing: 8) {
                        if let emoji = thing.emoji {
                            Text(emoji)
                                .font(.title2)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(thing.name)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 6) {
                                Image(systemName: thing.category.icon)
                                    .font(.caption)
                                Text(thing.category.rawValue)
                                    .font(.caption)
                            }
                            .foregroundColor(thing.category.color(theme: dataManager.currentTheme.colors))
                        }
                    }
                    
                    Spacer()
                    
                    Circle()
                        .fill(thing.status.color(theme: dataManager.currentTheme.colors))
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(thing.status.color(theme: dataManager.currentTheme.colors).opacity(0.3), lineWidth: 4)
                        )
                }
                
                if !thing.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(thing.tags.prefix(3), id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(dataManager.currentTheme.colors.primary.opacity(0.1))
                                    .foregroundColor(dataManager.currentTheme.colors.primary)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                
                Divider()
                
                if let days = thing.daysSinceLastEvent {
                    HStack(spacing: 16) {
                        StatItem(label: "Last done", value: "\(days)d ago", color: .primary)
                        
                        if let goal = thing.goalFrequency {
                            StatItem(label: "Goal", value: "~\(goal)d", color: thing.category.color(theme: dataManager.currentTheme.colors))
                        }
                        
                        if let avg = thing.averageFrequency {
                            StatItem(label: "Typical", value: "~\(avg)d", color: .secondary)
                        }
                    }
                    
                    if thing.streak > 1 {
                        HStack {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                            Text("\(thing.streak)-event streak!")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                        }
                        .padding(.top, 4)
                    }
                    
                    if let suggested = thing.suggestedGoalFrequency, thing.goalFrequency == nil || suggested != thing.goalFrequency {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(dataManager.currentTheme.colors.accent)
                            Text("Suggested goal: ~\(suggested) days")
                                .font(.caption)
                                .foregroundColor(dataManager.currentTheme.colors.accent)
                        }
                        .padding(.top, 4)
                    }
                    
                    if let next = thing.nextSuggestedDate {
                        Text("Next: \(next.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundColor(dataManager.currentTheme.colors.primary)
                            .padding(.top, 4)
                    }
                } else {
                    Text("Never done—ready to start?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 8) {
                    Button(action: onQuickLog) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Log it!")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(thing.category.gradient(theme: dataManager.currentTheme.colors))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { showingEdit = true }) {
                        Image(systemName: "pencil")
                            .font(.subheadline)
                            .foregroundColor(dataManager.currentTheme.colors.primary)
                            .frame(width: 44, height: 44)
                            .background(dataManager.currentTheme.colors.primary.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(ThemeColors.cardBackground)
            .cornerRadius(20)
            .shadow(color: .black.opacity(isPressed ? 0.1 : 0.08), radius: isPressed ? 4 : 12, y: isPressed ? 2 : 4)
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
        .sheet(isPresented: $showingDetail) {
            ThingDetailView(thing: thing)
        }
        .sheet(isPresented: $showingEdit) {
            EditThingView(thing: thing)
        }
    }
}

// MARK: - Edit Thing View

struct EditThingView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataManager: DataManager

    let thing: Thing

    @State private var name = ""
    @State private var category: Category = .personal
    @State private var goalFrequency = ""
    @State private var hasGoal = false
    @State private var tagInput = ""
    @State private var tags: [String] = []
    @State private var remindersEnabled = false
    @State private var showingDeleteAlert = false

    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case name, goal, tag
    }

    var body: some View {
        NavigationView {
            Form {

                Section(header: Text("Name")) {
                    TextField("What do you want to track?", text: $name)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .name)
                }

                Section(header: Text("Category")) {
                    Picker("Category", selection: $category) {
                        ForEach(Category.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.rawValue)
                            }
                            .tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section(
                    header: Text("Goal (Optional)"),
                    footer: Text("This is just a gentle guide—no pressure or warnings")
                ) {
                    Toggle("Set a goal frequency", isOn: $hasGoal)

                    if hasGoal {
                        HStack {
                            Text("About every")
                            TextField("14", text: $goalFrequency)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                                .focused($focusedField, equals: .goal)
                            Text("days")
                        }
                    }

                    if let suggested = thing.suggestedGoalFrequency,
                       thing.events.count >= 3 {
                        Button {
                            hasGoal = true
                            goalFrequency = "\(suggested)"
                        } label: {
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(dataManager.currentTheme.colors.accent)
                                Text("Use suggested goal: ~\(suggested) days")
                                    .foregroundColor(dataManager.currentTheme.colors.accent)
                            }
                        }
                    }
                }

                Section(header: Text("Tags (Optional)")) {
                    HStack {
                        TextField("Add tag", text: $tagInput)
                            .textInputAutocapitalization(.never)
                            .focused($focusedField, equals: .tag)

                        Button("Add") {
                            if !tagInput.isEmpty {
                                tags.append(tagInput)
                                tagInput = ""
                            }
                        }
                        .disabled(tagInput.isEmpty)
                    }

                    ForEach(tags, id: \.self) { tag in
                        HStack {
                            Text("#\(tag)")
                            Spacer()
                            Button {
                                tags.removeAll { $0 == tag }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section(
                    footer: Text("Get a friendly nudge when it's been a while 👋")
                ) {
                    Toggle("Enable gentle reminders", isOn: $remindersEnabled)
                }

                Section {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Thing")
                            Spacer()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Edit Thing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveThing()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .alert("Delete Thing?", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    dataManager.softDeleteThing(thing)
                    dismiss()
                }
            } message: {
                Text("This will move \(thing.name) to trash. You can restore it within 7 days.")
            }
            .onAppear {
                name = thing.name
                category = thing.category
                hasGoal = thing.goalFrequency != nil
                goalFrequency = thing.goalFrequency.map { "\($0)" } ?? ""
                tags = thing.tags
                remindersEnabled = thing.remindersEnabled
            }
        }
    }

    func saveThing() {
        var updated = thing
        updated.name = name
        updated.category = category
        updated.goalFrequency = hasGoal ? Int(goalFrequency) : nil
        updated.tags = tags
        updated.remindersEnabled = remindersEnabled
        dataManager.updateThing(updated)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: Binding(
                        get: { dataManager.currentTheme },
                        set: { dataManager.setTheme($0) }
                    )) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            HStack {
                                Circle()
                                    .fill(theme.colors.primary)
                                    .frame(width: 20, height: 20)
                                Text(theme.rawValue)
                            }
                            .tag(theme)
                        }
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Active Things")
                        Spacer()
                        Text("\(dataManager.activeThings.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Total Events")
                        Spacer()
                        Text("\(dataManager.activeThings.reduce(0) { $0 + $1.events.count })")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Trash View

struct TrashView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                ThemeColors.background.ignoresSafeArea()
                
                if dataManager.trashedThings.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "trash")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("Trash is Empty")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("Deleted items will appear here for 7 days")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(dataManager.trashedThings) { thing in
                                TrashItemCard(thing: thing)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Trash")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Trash Item Card

struct TrashItemCard: View {
    let thing: Thing
    @EnvironmentObject var dataManager: DataManager
    @State private var showingPermanentDeleteAlert = false
    
    var daysRemaining: Int {
        guard let deletedAt = thing.deletedAt else { return 0 }
        let cutoffDate = Calendar.current.date(byAdding: .day, value: 7, to: deletedAt)!
        let days = Calendar.current.dateComponents([.day], from: Date(), to: cutoffDate).day ?? 0
        return max(0, days)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(thing.name)
                        .font(.headline)
                    
                    HStack(spacing: 6) {
                        Image(systemName: thing.category.icon)
                            .font(.caption)
                        Text(thing.category.rawValue)
                            .font(.caption)
                    }
                    .foregroundColor(thing.category.color(theme: dataManager.currentTheme.colors))
                }
                
                Spacer()
                
                Text("\(daysRemaining)d left")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 8) {
                Button(action: {
                    dataManager.restoreThing(thing)
                }) {
                    HStack {
                        Image(systemName: "arrow.uturn.backward")
                        Text("Restore")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(dataManager.currentTheme.colors.success)
                    .cornerRadius(12)
                }
                
                Button(action: { showingPermanentDeleteAlert = true }) {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("Delete")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(dataManager.currentTheme.colors.attention)
                    .cornerRadius(12)
                }
            }
        }
        .padding(16)
        .background(ThemeColors.cardBackground)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        .alert("Permanently Delete?", isPresented: $showingPermanentDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Forever", role: .destructive) {
                dataManager.permanentlyDeleteThing(thing)
            }
        } message: {
            Text("This will permanently delete \(thing.name) and all its events. This cannot be undone.")
        }
    }
}

// MARK: - Stat Item

struct StatItem: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Group {
                    if isSelected {
                        LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        color.opacity(0.15)
                    }
                }
            )
            .cornerRadius(20)
            .shadow(color: isSelected ? color.opacity(0.3) : .clear, radius: 8, y: 2)
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Add Thing View

struct AddThingView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataManager: DataManager

    @State private var name = ""
    @State private var category: Category = .personal
    @State private var goalFrequency = ""
    @State private var hasGoal = false
    @State private var tagInput = ""
    @State private var tags: [String] = []
    @State private var remindersEnabled = false

    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case name, goal, tag
    }

    var body: some View {
        NavigationView {
            Form {

                Section(header: Text("Name Your Thing")) {
                    TextField("What do you want to track?", text: $name)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .name)
                }

                Section(header: Text("Category")) {
                    Picker("Category", selection: $category) {
                        ForEach(Category.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.rawValue)
                            }
                            .tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section(
                    header: Text("Goal (Optional)"),
                    footer: Text("This is just a gentle guide—no pressure or warnings")
                ) {
                    Toggle("Set a goal frequency", isOn: $hasGoal)

                    if hasGoal {
                        HStack {
                            Text("About every")
                            TextField("14", text: $goalFrequency)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                                .focused($focusedField, equals: .goal)
                            Text("days")
                        }
                    }
                }

                Section(header: Text("Tags (Optional)")) {
                    HStack {
                        TextField("Add tag", text: $tagInput)
                            .textInputAutocapitalization(.never)
                            .focused($focusedField, equals: .tag)

                        Button("Add") {
                            if !tagInput.isEmpty {
                                tags.append(tagInput)
                                tagInput = ""
                            }
                        }
                        .disabled(tagInput.isEmpty)
                    }

                    ForEach(tags, id: \.self) { tag in
                        HStack {
                            Text("#\(tag)")
                            Spacer()
                            Button {
                                tags.removeAll { $0 == tag }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section(
                    footer: Text("Get a friendly nudge when it's been a while 👋")
                ) {
                    Toggle("Enable gentle reminders", isOn: $remindersEnabled)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Add Thing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add Thing") {
                        addThing()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    focusedField = .name
                }
            }
        }
    }

    func addThing() {
        let goal = hasGoal ? Int(goalFrequency) : nil
        let thing = Thing(
            name: name,
            category: category,
            goalFrequency: goal,
            tags: tags,
            remindersEnabled: remindersEnabled,
            emoji: nil
        )
        dataManager.addThing(thing)
    }
}

// MARK: - Thing Detail View

struct ThingDetailView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    let thing: Thing
    
    var body: some View {
        NavigationView {
            ZStack {
                ThemeColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 12) {
                            if let emoji = thing.emoji {
                                Text(emoji)
                                    .font(.system(size: 60))
                            }
                            
                            Text(thing.name)
                                .font(.title)
                                .fontWeight(.bold)
                            
                            HStack {
                                Image(systemName: thing.category.icon)
                                Text(thing.category.rawValue)
                            }
                            .foregroundColor(thing.category.color(theme: dataManager.currentTheme.colors))
                            .font(.subheadline)
                            
                            if thing.streak > 1 {
                                HStack {
                                    Image(systemName: "flame.fill")
                                    Text("\(thing.streak)-event streak!")
                                }
                                .foregroundColor(.orange)
                                .fontWeight(.semibold)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(ThemeColors.cardBackground)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                        
                        if !thing.tags.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Tags")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                FlowLayout(spacing: 8) {
                                    ForEach(thing.tags, id: \.self) { tag in
                                        Text("#\(tag)")
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(dataManager.currentTheme.colors.primary.opacity(0.15))
                                            .foregroundColor(dataManager.currentTheme.colors.primary)
                                            .cornerRadius(12)
                                    }
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(ThemeColors.cardBackground)
                            .cornerRadius(20)
                            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("History")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            if thing.events.isEmpty {
                                Text("No events yet—time to get started!")
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding()
                            } else {
                                ForEach(thing.events.sorted(by: { $0.timestamp > $1.timestamp })) { event in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(event.timestamp.formatted(date: .long, time: .shortened))
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        
                                        if let note = event.note, !note.isEmpty {
                                            Text(note)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(thing.category.color(theme: dataManager.currentTheme.colors).opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ThemeColors.cardBackground)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                    }
                    .padding()
                }
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Stats View

struct StatsView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    @State private var animateStats = false
    @State private var showingExportSuccess = false
    @State private var showingImportError = false
    
    var body: some View {
        NavigationView {
            ZStack {
                ThemeColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 16) {
                            StatCard(
                                title: "Total Things",
                                value: "\(dataManager.activeThings.count)",
                                icon: "square.grid.2x2.fill",
                                color: dataManager.currentTheme.colors.primary,
                                animate: animateStats
                            )
                            
                            StatCard(
                                title: "Total Events",
                                value: "\(dataManager.activeThings.reduce(0) { $0 + $1.events.count })",
                                icon: "checkmark.circle.fill",
                                color: dataManager.currentTheme.colors.success,
                                animate: animateStats
                            )
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("By Category")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            ForEach(Category.allCases, id: \.self) { category in
                                let count = dataManager.activeThings.filter { $0.category == category }.count
                                if count > 0 {
                                    HStack {
                                        Image(systemName: category.icon)
                                            .foregroundColor(category.color(theme: dataManager.currentTheme.colors))
                                            .frame(width: 24)
                                        
                                        Text(category.rawValue)
                                        
                                        Spacer()
                                        
                                        Text("\(count)")
                                            .fontWeight(.bold)
                                            .foregroundColor(category.color(theme: dataManager.currentTheme.colors))
                                    }
                                    .padding()
                                    .background(category.color(theme: dataManager.currentTheme.colors).opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding()
                        .background(ThemeColors.cardBackground)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Status Overview")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            let needsAttention = dataManager.activeThings.filter { $0.status == .needsAttention }.count
                            let upcoming = dataManager.activeThings.filter { $0.status == .upcoming }.count
                            let onTrack = dataManager.activeThings.filter { $0.status == .onTrack }.count
                            
                            StatusRow(label: "Needs Attention", count: needsAttention, color: dataManager.currentTheme.colors.attention, total: dataManager.activeThings.count, animate: animateStats)
                            StatusRow(label: "Upcoming", count: upcoming, color: dataManager.currentTheme.colors.warning, total: dataManager.activeThings.count, animate: animateStats)
                            StatusRow(label: "On Track", count: onTrack, color: dataManager.currentTheme.colors.success, total: dataManager.activeThings.count, animate: animateStats)
                        }
                        .padding()
                        .background(ThemeColors.cardBackground)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Data Management")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                let json = dataManager.exportData()
                                UIPasteboard.general.string = json
                                showingExportSuccess = true
                            }) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up.fill")
                                    Text("Export Data to Clipboard")
                                    Spacer()
                                    Image(systemName: "doc.on.clipboard.fill")
                                        .foregroundColor(.secondary)
                                }
                                .foregroundColor(dataManager.currentTheme.colors.primary)
                                .padding()
                                .background(dataManager.currentTheme.colors.primary.opacity(0.1))
                                .cornerRadius(12)
                            }
                            
                            Button(action: {
                                if let json = UIPasteboard.general.string {
                                    let success = dataManager.importData(from: json)
                                    if !success {
                                        showingImportError = true
                                    }
                                }
                            }) {
                                HStack {
                                    Image(systemName: "square.and.arrow.down.fill")
                                    Text("Import Data from Clipboard")
                                    Spacer()
                                    Image(systemName: "doc.on.clipboard")
                                        .foregroundColor(.secondary)
                                }
                                .foregroundColor(dataManager.currentTheme.colors.accent)
                                .padding()
                                .background(dataManager.currentTheme.colors.accent.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                        .padding()
                        .background(ThemeColors.cardBackground)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                    }
                    .padding()
                }
            }
            .navigationTitle("Stats & Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .alert("Data Exported!", isPresented: $showingExportSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your data has been copied to the clipboard. You can paste it to save as a backup.")
            }
            .alert("Import Failed", isPresented: $showingImportError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("The clipboard doesn't contain valid export data. Make sure you've copied the export text.")
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    animateStats = true
                }
            }
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let animate: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(
                        colors: [color, color.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Text(value)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                    .opacity(animate ? 1 : 0)
                    .scaleEffect(animate ? 1 : 0.5)
            }
        }
        .padding(20)
        .background(ThemeColors.cardBackground)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

// MARK: - Status Row

struct StatusRow: View {
    let label: String
    let count: Int
    let color: Color
    let total: Int
    let animate: Bool
    
    var percentage: Double {
        total > 0 ? Double(count) / Double(total) : 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                
                Text(label)
                    .font(.subheadline)
                
                Spacer()
                
                Text("\(count)")
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(color.opacity(0.2))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: animate ? geo.size.width * percentage : 0, height: 6)
                        .cornerRadius(3)
                        .animation(.easeOut(duration: 0.8).delay(0.2), value: animate)
                }
            }
            .frame(height: 6)
        }
        .padding()
        .background(color.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Confetti View

struct ConfettiView: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<30, id: \.self) { i in
                    ConfettiPiece(delay: Double(i) * 0.02, containerHeight: geo.size.height)
                }
            }
        }
    }
}

struct ConfettiPiece: View {
    let delay: Double
    let containerHeight: CGFloat

    @State private var yOffset: CGFloat = -100
    @State private var xOffset: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1

    let colors: [Color] = [
        Color(red: 0.25, green: 0.67, blue: 0.84),
        Color(red: 0.95, green: 0.61, blue: 0.47),
        Color(red: 0.4, green: 0.78, blue: 0.65),
        Color(red: 0.98, green: 0.73, blue: 0.38),
        .purple,
        .pink
    ]

    var body: some View {
        Circle()
            .fill(colors.randomElement() ?? .blue)
            .frame(width: 8, height: 8)
            .offset(x: xOffset, y: yOffset)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
            .onAppear {
                xOffset = CGFloat.random(in: -150...150)

                withAnimation(
                    .easeOut(duration: 2)
                    .delay(delay)
                ) {
                    yOffset = containerHeight + 100
                    rotation = Double.random(in: 0...720)
                    opacity = 0
                }
            }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: currentX, y: currentY))
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
