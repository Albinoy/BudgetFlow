import SwiftUI
import CoreData
import UIKit

// MARK: - App configuration and currency

enum AppConfig {
    static let enableICloudSync = true
    static let cloudKitContainerIdentifier = "iCloud.com.budgetflow.personal"
    static let currentModelVersion = 2
    static let settingsID = UUID(uuidString: "B6C0C4B4-7A7E-4DD0-9F4A-6E0D13D1D115")!
    static let setupFlag = "BudgetFlow.showFirstLaunchSetup"

    // MARK: Support and privacy: EDIT THESE TWO VALUES BEFORE SUBMITTING TO THE APP STORE
    /// The public address of your hosted privacy policy page (for example a GitHub Pages URL).
    static let privacyPolicyURLString = "https://YOUR-GITHUB-USERNAME.github.io/budgetflow-privacy/"
    /// The email address people can use to contact you about the app.
    static let supportEmail = "YOUR-SUPPORT-EMAIL@YOUR-DOMAIN.com"

    static var privacyPolicyURL: URL? { URL(string: privacyPolicyURLString) }
    static var supportMailURL: URL? { URL(string: "mailto:\(supportEmail)?subject=BudgetFlow%20support") }
    /// False while either value above still contains the "YOUR-" placeholder text.
    static var supportDetailsAreSet: Bool {
        !privacyPolicyURLString.contains("YOUR-") && !supportEmail.contains("YOUR-")
    }
}

struct CurrencyChoice: Identifiable {
    let id: String
    let title: String
}

struct CurrencyFormatter {
    init() {}

    static let shared = CurrencyFormatter()
    static let choices = [
        CurrencyChoice(id: "system", title: "System default"),
        CurrencyChoice(id: "USD", title: "US Dollar (USD)"),
        CurrencyChoice(id: "EUR", title: "Euro (EUR)"),
        CurrencyChoice(id: "GBP", title: "Pound Sterling (GBP)"),
        CurrencyChoice(id: "JPY", title: "Japanese Yen (JPY)"),
        CurrencyChoice(id: "CAD", title: "Canadian Dollar (CAD)"),
        CurrencyChoice(id: "AUD", title: "Australian Dollar (AUD)"),
        CurrencyChoice(id: "INR", title: "Indian Rupee (INR)"),
        CurrencyChoice(id: "CHF", title: "Swiss Franc (CHF)")
    ]

    static func systemIdentifier() -> String {
        if #available(iOS 16.0, *) {
            return Locale.current.currency?.identifier ?? Locale.current.currencyCode ?? "USD"
        }
        return Locale.current.currencyCode ?? "USD"
    }

    func identifier(override: String?) -> String {
        guard let override, !override.isEmpty, override != "system" else {
            return Self.systemIdentifier()
        }
        return override
    }

    func symbol(override: String?) -> String {
        let id = identifier(override: override)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        formatter.currencyCode = id
        return formatter.currencySymbol ?? id
    }

    func string(_ value: Double, override: String?) -> String {
        let id = identifier(override: override)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        formatter.currencyCode = id
        formatter.currencySymbol = symbol(override: override)
        formatter.minimumFractionDigits = id == "JPY" ? 0 : 2
        formatter.maximumFractionDigits = id == "JPY" ? 0 : 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(value) \(id)"
    }
}

// MARK: - Core Data model

@objc(Job)
final class Job: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var location: String
    @NSManaged var weeklyHours: Double
    @NSManaged var hourlyRate: Double

    @nonobjc class func fetchRequest() -> NSFetchRequest<Job> {
        NSFetchRequest<Job>(entityName: "Job")
    }

    convenience init(context: NSManagedObjectContext, name: String, location: String = "", weeklyHours: Double = 0, hourlyRate: Double = 0) {
        let entity = NSEntityDescription.entity(forEntityName: "Job", in: context)!
        self.init(entity: entity, insertInto: context)
        id = UUID()
        self.name = name
        self.location = location
        self.weeklyHours = weeklyHours
        self.hourlyRate = hourlyRate
    }

    var weeklyPay: Double { weeklyHours * hourlyRate }
}

@objc(Expense)
final class Expense: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var amount: Double
    @NSManaged var recurrence: String
    @NSManaged var enabled: Bool

    @nonobjc class func fetchRequest() -> NSFetchRequest<Expense> {
        NSFetchRequest<Expense>(entityName: "Expense")
    }

    convenience init(context: NSManagedObjectContext, name: String, amount: Double, recurrence: ExpenseRecurrence = .monthly, enabled: Bool = true) {
        let entity = NSEntityDescription.entity(forEntityName: "Expense", in: context)!
        self.init(entity: entity, insertInto: context)
        id = UUID()
        self.name = name
        self.amount = amount
        self.recurrence = recurrence.rawValue
        self.enabled = enabled
    }

    var recurrenceValue: ExpenseRecurrence { ExpenseRecurrence(rawValue: recurrence) ?? .monthly }
    // A "month" here is treated as 4 weeks everywhere in the app, so weeklyAmount * 4 always
    // equals monthlyAmount. For a yearly expense, the monthly figure (amount / 12) is the one
    // most people recognise at a glance, so it's the anchor; weekly is derived from it.
    var weeklyAmount: Double {
        switch recurrenceValue {
        case .weekly: return amount
        case .monthly: return amount / 4
        case .yearly: return (amount / 12) / 4
        }
    }
    var monthlyAmount: Double {
        switch recurrenceValue {
        case .weekly: return amount * 4
        case .monthly: return amount
        case .yearly: return amount / 12
        }
    }
}

enum ExpenseRecurrence: String, CaseIterable, Identifiable {
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

@objc(Goal)
final class Goal: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var targetAmount: Double
    @NSManaged var currentSavings: Double
    @NSManaged var targetDate: Date?
    @NSManaged var createdAt: Date

    @nonobjc class func fetchRequest() -> NSFetchRequest<Goal> {
        NSFetchRequest<Goal>(entityName: "Goal")
    }

    convenience init(context: NSManagedObjectContext, name: String, targetAmount: Double, currentSavings: Double = 0, targetDate: Date? = nil) {
        let entity = NSEntityDescription.entity(forEntityName: "Goal", in: context)!
        self.init(entity: entity, insertInto: context)
        id = UUID()
        self.name = name
        self.targetAmount = targetAmount
        self.currentSavings = currentSavings
        self.targetDate = targetDate
        createdAt = Date()
    }
}

@objc(BudgetSettings)
final class BudgetSettings: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var currencyOverride: String?
    @NSManaged var primaryView: String
    @NSManaged var weeklyHoursLimitEnabled: Bool
    @NSManaged var weeklyHoursLimit: Double
    @NSManaged var weeklySavingsTarget: Double
    @NSManaged var firstLaunchSetupComplete: Bool
    @NSManaged var schemaVersion: Int16

    // Retained for lightweight migration from the prior v1 Core Data model.
    // They are hidden from new-user UI and imported once into neutral entities.
    @NSManaged var travel: Double
    @NSManaged var food: Double
    @NSManaged var gym: Double
    @NSManaged var protein: Double
    @NSManaged var weeklyTarget: Double
    @NSManaged var movingGoal: Double
    @NSManaged var currentSavings: Double

    @nonobjc class func fetchRequest() -> NSFetchRequest<BudgetSettings> {
        NSFetchRequest<BudgetSettings>(entityName: "BudgetSettings")
    }

    convenience init(context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "BudgetSettings", in: context)!
        self.init(entity: entity, insertInto: context)
        id = AppConfig.settingsID
        currencyOverride = nil
        primaryView = "monthly"
        weeklyHoursLimitEnabled = false
        weeklyHoursLimit = 0
        weeklySavingsTarget = 0
        firstLaunchSetupComplete = false
        schemaVersion = Int16(AppConfig.currentModelVersion)
        travel = 0
        food = 0
        gym = 0
        protein = 0
        weeklyTarget = 0
        movingGoal = 0
        currentSavings = 0
    }
}

final class PersistenceController {
    let container: NSPersistentContainer
    let usesICloud: Bool

    init() {
        if AppConfig.enableICloudSync {
            let cloud = Self.makeCloudContainer()
            if Self.loadStores(for: cloud) {
                container = cloud
                usesICloud = true
            } else {
                let local = Self.makeLocalContainer()
                _ = Self.loadStores(for: local)
                container = local
                usesICloud = false
            }
        } else {
            let local = Self.makeLocalContainer()
            if Self.loadStores(for: local) {
                container = local
            } else {
                Self.moveLocalStoreAside()
                let fresh = Self.makeLocalContainer()
                _ = Self.loadStores(for: fresh)
                container = fresh
            }
            usesICloud = false
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.undoManager = nil
    }

    /// Loaded once from BudgetFlow.xcdatamodeld, which replaces the model that used to be built
    /// by hand in code. This is what makes the schema "versioned": a future change adds a new
    /// xcdatamodel version inside that bundle (Xcode: Editor > Add Model Version) rather than
    /// editing this one in place, and Core Data migrates existing users from the old version
    /// to the new one automatically (lightweight migration is already turned on below).
    private static let model: NSManagedObjectModel = {
        guard let url = Bundle.main.url(forResource: "BudgetFlow", withExtension: "momd"),
              let loaded = NSManagedObjectModel(contentsOf: url) else {
            fatalError("BudgetFlow: could not load BudgetFlow.xcdatamodeld. Check that it's included in the app target's Resources build phase.")
        }
        return loaded
    }()

    private static func makeLocalContainer() -> NSPersistentContainer {
        let result = NSPersistentContainer(name: "BudgetFlow", managedObjectModel: model)
        configure(result.persistentStoreDescriptions[0], cloud: false)
        return result
    }

    private static func makeCloudContainer() -> NSPersistentCloudKitContainer {
        let result = NSPersistentCloudKitContainer(name: "BudgetFlow", managedObjectModel: model)
        configure(result.persistentStoreDescriptions[0], cloud: true)
        return result
    }

    private static func configure(_ description: NSPersistentStoreDescription, cloud: Bool) {
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // CloudKit and local fallback share the same SQLite store so enabling sync does not silently start with an empty database.
        description.url = directory.appendingPathComponent("BudgetFlow.sqlite")
        if cloud {
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: AppConfig.cloudKitContainerIdentifier)
        }
    }

    /// Renames BudgetFlow.sqlite (and its -wal/-shm files) to *.backup so nothing is deleted.
    private static func moveLocalStoreAside() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let stamp = Int(Date().timeIntervalSince1970)
        for suffix in ["", "-wal", "-shm"] {
            let source = directory.appendingPathComponent("BudgetFlow.sqlite" + suffix)
            let target = directory.appendingPathComponent("BudgetFlow.sqlite\(suffix).\(stamp).backup")
            if FileManager.default.fileExists(atPath: source.path) {
                try? FileManager.default.moveItem(at: source, to: target)
            }
        }
        print("BudgetFlow: moved an unreadable store aside and started a new one")
    }

    private static func loadStores(for container: NSPersistentContainer) -> Bool {
        var loadError: Error?
        let semaphore = DispatchSemaphore(value: 0)
        container.loadPersistentStores { _, error in
            loadError = error
            semaphore.signal()
        }
        guard semaphore.wait(timeout: .now() + 8) == .success else {
            print("BudgetFlow store load timed out")
            return false
        }
        if let loadError {
            print("BudgetFlow store load failed: \(loadError.localizedDescription)")
            return false
        }
        return true
    }
}

// MARK: - Migration and store reset

struct StoreMigrator {
    static func migrateIfNeeded(context: NSManagedObjectContext) {
        let request = BudgetSettings.fetchRequest()
        request.fetchLimit = 1
        let settings: BudgetSettings
        if let existing = try? context.fetch(request).first {
            settings = existing
        } else {
            settings = BudgetSettings(context: context)
        }

        if settings.schemaVersion < Int16(AppConfig.currentModelVersion) {
            importLegacyValuesIfNeeded(settings: settings, context: context)
            settings.schemaVersion = Int16(AppConfig.currentModelVersion)
        }
        if settings.id != AppConfig.settingsID { settings.id = AppConfig.settingsID }
        saveContext(context)
    }

    private static func importLegacyValuesIfNeeded(settings: BudgetSettings, context: NSManagedObjectContext) {
        let hasLegacyExpense = settings.travel != 0 || settings.food != 0 || settings.gym != 0 || settings.protein != 0
        if hasLegacyExpense {
            let values: [(String, Double, ExpenseRecurrence)] = [
                ("Imported expense 1", settings.travel, .weekly),
                ("Imported expense 2", settings.food, .weekly),
                ("Imported expense 3", settings.gym, .monthly),
                ("Imported expense 4", settings.protein, .monthly)
            ]
            for item in values where item.1 != 0 {
                _ = Expense(context: context, name: item.0, amount: item.1, recurrence: item.2)
            }
        }
        if settings.movingGoal != 0 || settings.currentSavings != 0 {
            let oldTimestamp = UserDefaults.standard.double(forKey: "goalTargetDateTimestamp")
            let oldDate = oldTimestamp > 0 ? Date(timeIntervalSince1970: oldTimestamp) : nil
            _ = Goal(context: context,
                     name: "Imported savings goal",
                     targetAmount: max(settings.movingGoal, 0),
                     currentSavings: max(settings.currentSavings, 0),
                     targetDate: oldDate)
        }
        if settings.weeklyTarget != 0 { settings.weeklySavingsTarget = max(settings.weeklyTarget, 0) }
        if hasLegacyExpense || settings.movingGoal != 0 || settings.currentSavings != 0 {
            settings.firstLaunchSetupComplete = true
        }
    }

    static func resetAll(context: NSManagedObjectContext) {
        for entityName in ["Job", "Expense", "Goal", "BudgetSettings"] {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            if let objects = try? context.fetch(request) as? [NSManagedObject] {
                objects.forEach(context.delete)
            }
        }
        _ = BudgetSettings(context: context)
        saveContext(context)
        UserDefaults.standard.set(true, forKey: AppConfig.setupFlag)
    }
}

extension Notification.Name {
    static let budgetFlowSaveFailed = Notification.Name("BudgetFlow.saveFailed")
}

@main
struct BudgetFlowApp: App {
    private let persistenceController = PersistenceController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

func parseUserNumber(_ text: String) -> Double? {
    let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
    guard !normalized.isEmpty, let value = Double(normalized), value.isFinite else { return nil }
    return value
}

@discardableResult
func saveContext(_ context: NSManagedObjectContext) -> Bool {
    guard context.hasChanges else { return true }
    do {
        try context.save()
        return true
    } catch {
        print("BudgetFlow save failed: \(error.localizedDescription)")
        NotificationCenter.default.post(name: .budgetFlowSaveFailed, object: nil, userInfo: ["message": error.localizedDescription])
        return false
    }
}

// MARK: - Derived calculations

extension Array where Element == Job {
    var weeklyIncome: Double { reduce(0) { $0 + $1.weeklyPay } }
    var totalHours: Double { reduce(0) { $0 + $1.weeklyHours } }
}

extension Array where Element == Expense {
    var weeklyTotal: Double { filter { $0.enabled }.reduce(0) { $0 + $1.weeklyAmount } }
    var monthlyTotal: Double { filter { $0.enabled }.reduce(0) { $0 + $1.monthlyAmount } }
}

struct SavingsPlan {
    let target: Double
    let saved: Double
    let weeklyTarget: Double
    let targetDate: Date?
    let today: Date

    var remaining: Double { max(target - saved, 0) }
    var reached: Bool { target > 0 && target - saved <= 0 }
    var weeksAtTarget: Int? {
        guard !reached, weeklyTarget > 0 else { return nil }
        let result = ceil(remaining / weeklyTarget)
        return result.isFinite && result < 100_000 ? Int(result) : nil
    }
    var weeksToTargetDate: Int? {
        guard let targetDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: today), to: Calendar.current.startOfDay(for: targetDate)).day ?? 0
        guard days > 0 else { return nil }
        return max(1, Int(ceil(Double(days) / 7)))
    }
    var requiredWeekly: Double? {
        guard let weeks = weeksToTargetDate, !reached else { return nil }
        return ceil(remaining / Double(weeks) * 100) / 100
    }
}

// MARK: - Root and first launch

struct ContentView: View {
    @Environment(\.managedObjectContext) private var modelContext
    @FetchRequest(sortDescriptors: [], predicate: NSPredicate(format: "id == %@", AppConfig.settingsID as CVarArg), animation: .default) private var settingsRows: FetchedResults<BudgetSettings>
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppConfig.setupFlag) private var showSetup = false
    @State private var selection = 0
    @State private var didMigrate = false
    @State private var saveErrorMessage: String?

    var body: some View {
        TabView(selection: $selection) {
            DashboardView().tabItem { Label("Dashboard", systemImage: "rectangle.grid.2x2.fill") }.tag(0)
            BudgetView().tabItem { Label("Budget", systemImage: "chart.bar.xaxis") }.tag(1)
            GoalsView().tabItem { Label("Goals", systemImage: "target") }.tag(2)
            SettingsView().tabItem { Label("Settings", systemImage: "gearshape") }.tag(3)
        }
        .tint(AppTheme.lime)
        .background(AppTheme.backgroundGradient.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear {
            guard !didMigrate else { return }
            didMigrate = true
            StoreMigrator.migrateIfNeeded(context: modelContext)
            DispatchQueue.main.async {
                if let settings = settingsRows.first, !settings.firstLaunchSetupComplete { showSetup = true }
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active { saveContext(modelContext) }
        }
        .sheet(isPresented: $showSetup) {
            if let settings = settingsRows.first { FirstLaunchSetup(settings: settings) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .budgetFlowSaveFailed)) { notification in
            saveErrorMessage = notification.userInfo?["message"] as? String ?? "Your changes could not be saved."
        }
        .alert("Could not save changes", isPresented: Binding(get: { saveErrorMessage != nil }, set: { if !$0 { saveErrorMessage = nil } })) {
            Button("OK", role: .cancel) { saveErrorMessage = nil }
        } message: {
            Text(saveErrorMessage ?? "Your changes could not be saved.")
        }
    }
}

struct FirstLaunchSetup: View {
    @Environment(\.managedObjectContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var settings: BudgetSettings
    @State private var goalName = ""
    @State private var goalAmount = ""
    @State private var addGoal = false
    @State private var targetDateEnabled = false
    @State private var targetDate = Date()
    @State private var enableHours = false
    @State private var hoursLimit = ""

    private var amount: Double? { parseUserNumber(goalAmount) }
    private var hours: Double? { parseUserNumber(hoursLimit) }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Welcome")) {
                    Text("Set a few preferences now. You can skip this and change everything later in Settings.")
                        .fixedSize(horizontal: false, vertical: true)
                }
                Section(header: Text("Display")) {
                    Picker("Display currency", selection: Binding(get: { settings.currencyOverride ?? "system" }, set: { settings.currencyOverride = $0 == "system" ? nil : $0 })) {
                        ForEach(CurrencyFormatter.choices) { choice in Text(choice.title).tag(choice.id) }
                    }
                    Picker("Primary view", selection: Binding(get: { settings.primaryView }, set: { settings.primaryView = $0 })) {
                        Text("Monthly").tag("monthly")
                        Text("Weekly").tag("weekly")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                Section(header: Text("First savings goal (optional)")) {
                    Toggle("Add a goal now", isOn: $addGoal)
                    if addGoal {
                        TextField("Goal name", text: $goalName)
                        TextField("Target amount", text: $goalAmount).keyboardType(.decimalPad)
                        Toggle("Set a target date", isOn: $targetDateEnabled)
                        if targetDateEnabled { DatePicker("Target date", selection: $targetDate, in: Date()..., displayedComponents: .date) }
                    }
                }
                Section(header: Text("Weekly hours limit (optional)")) {
                    Toggle("Enable hours limit", isOn: $enableHours)
                    if enableHours { TextField("Hours per week", text: $hoursLimit).keyboardType(.decimalPad) }
                }
                Section {
                    Button("Finish setup") { finish() }
                    Button("Skip for now") { skip() }
                }
            }
            .navigationTitle("Get started")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { dismissKeyboard() } } }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func finish() {
        if addGoal, let amount, !goalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, amount > 0 {
            _ = Goal(context: modelContext, name: goalName.trimmingCharacters(in: .whitespacesAndNewlines), targetAmount: amount, targetDate: targetDateEnabled ? targetDate : nil)
        }
        settings.weeklyHoursLimitEnabled = enableHours && (hours ?? 0) > 0
        settings.weeklyHoursLimit = settings.weeklyHoursLimitEnabled ? (hours ?? 0) : 0
        settings.firstLaunchSetupComplete = true
        saveContext(modelContext)
        dismiss()
    }

    private func skip() {
        settings.firstLaunchSetupComplete = true
        saveContext(modelContext)
        dismiss()
    }
}

// MARK: - Dashboard

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)], animation: .default) private var jobs: FetchedResults<Job>
    @FetchRequest(sortDescriptors: [], animation: .default) private var expenses: FetchedResults<Expense>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)], animation: .default) private var goals: FetchedResults<Goal>
    @FetchRequest(sortDescriptors: [], predicate: NSPredicate(format: "id == %@", AppConfig.settingsID as CVarArg), animation: .default) private var settingsRows: FetchedResults<BudgetSettings>

    private var settings: BudgetSettings? { settingsRows.first }
    private var jobList: [Job] { Array(jobs) }
    private var expenseList: [Expense] { Array(expenses) }
    private var weeklyIncome: Double { jobList.weeklyIncome }
    private var monthlyIncome: Double { weeklyIncome * 52 / 12 }
    private var weeklyExpenses: Double { expenseList.weeklyTotal }
    private var monthlyExpenses: Double { expenseList.monthlyTotal }
    private var weeklyLeft: Double { weeklyIncome - weeklyExpenses }
    private var monthlyLeft: Double { monthlyIncome - monthlyExpenses }
    private var currencyOverride: String? { settings?.currencyOverride }
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    @ViewBuilder
    private var monthlyFigures: some View {
        Text("Monthly figures").font(.headline)
        LazyVGrid(columns: columns, spacing: 12) {
            MetricCard(title: "Monthly income", value: formatted(monthlyIncome), color: AppTheme.lime, icon: "arrow.down.left")
            MetricCard(title: "Monthly expenses", value: formatted(monthlyExpenses), color: AppTheme.coral, icon: "arrow.up.right")
            MetricCard(title: "Monthly left", value: formatted(monthlyLeft), color: AppTheme.blue, icon: "wallet.pass.fill")
        }
    }

    @ViewBuilder
    private var weeklyFigures: some View {
        Text("Weekly figures").font(.headline)
        LazyVGrid(columns: columns, spacing: 12) {
            SummaryPill(title: "Weekly income", value: formatted(weeklyIncome))
            SummaryPill(title: "Weekly expenses", value: formatted(weeklyExpenses))
            SummaryPill(title: "Weekly left", value: formatted(weeklyLeft))
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Header(title: "Your budget overview", subtitle: "Monthly and weekly figures")
                    if settings?.primaryView == "weekly" {
                        weeklyFigures
                        monthlyFigures
                    } else {
                        monthlyFigures
                        weeklyFigures
                    }
                    MonthlyCashFlowChart(weeklyIncome: weeklyIncome, weeklyExpenses: weeklyExpenses, currencyOverride: currencyOverride)
                    SavingsAnalyticsCard(goals: Array(goals), weeklySavingsTarget: settings?.weeklySavingsTarget ?? 0, currencyOverride: currencyOverride)
                    NetCashFlowCard(monthlyIncome: monthlyIncome, monthlyExpenses: monthlyExpenses, currencyOverride: currencyOverride)
                    GoalsOverviewCard(goals: Array(goals), currencyOverride: currencyOverride)
                    if let goal = goals.first { GoalCard(goal: goal, currencyOverride: currencyOverride) }
                    if let settings, settings.weeklyHoursLimitEnabled, settings.weeklyHoursLimit > 0 {
                        HoursLimitCard(used: jobList.totalHours, limit: settings.weeklyHoursLimit)
                    }
                    IncomeChart(jobs: jobList, currencyOverride: currencyOverride)
                }
                .padding()
                .readableWidth()
            }
            .background(AppTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("BudgetFlow")
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func formatted(_ value: Double) -> String { CurrencyFormatter.shared.string(value, override: currencyOverride) }
}

// MARK: - Budget and expenses

struct BudgetView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)], animation: .default) private var jobs: FetchedResults<Job>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)], animation: .default) private var expenses: FetchedResults<Expense>
    @FetchRequest(sortDescriptors: [], predicate: NSPredicate(format: "id == %@", AppConfig.settingsID as CVarArg), animation: .default) private var settingsRows: FetchedResults<BudgetSettings>
    @State private var addingJob = false
    @State private var editingJob: Job?
    @State private var addingExpense = false
    @State private var editingExpense: Expense?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Jobs and income")) {
                    if jobs.isEmpty { Text("No jobs yet. Add a job to calculate income.").foregroundColor(AppTheme.muted) }
                    ForEach(jobs, id: \.objectID) { job in JobRow(job: job, currencyOverride: settingsRows.first?.currencyOverride) { editingJob = job } }
                        .onDelete { offsets in offsets.forEach { index in context.delete(jobs[index]) }; saveContext(context) }
                    Button { addingJob = true } label: { Label("Add job", systemImage: "plus.circle.fill") }
                }
                Section(header: Text("Expenses")) {
                    if expenses.isEmpty { Text("No expenses yet. Add an expense to include it in totals.").foregroundColor(AppTheme.muted) }
                    ForEach(expenses, id: \.objectID) { expense in ExpenseRow(expense: expense, currencyOverride: settingsRows.first?.currencyOverride) { editingExpense = expense } }
                        .onDelete { offsets in offsets.forEach { index in context.delete(expenses[index]) }; saveContext(context) }
                    Button { addingExpense = true } label: { Label("Add expense", systemImage: "plus.circle.fill") }
                }
                Section(header: Text("Summary")) {
                    SummaryRow(title: "Weekly expenses", value: formatted(expensesArray.weeklyTotal))
                    SummaryRow(title: "Monthly expenses", value: formatted(expensesArray.monthlyTotal))
                }
            }
            .background(AppTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Budget plan")
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { dismissKeyboard() } } }
            .sheet(isPresented: $addingJob) { JobEditorView() }
            .sheet(item: $editingJob) { JobEditorView(job: $0) }
            .sheet(isPresented: $addingExpense) { ExpenseEditorView() }
            .sheet(item: $editingExpense) { ExpenseEditorView(expense: $0) }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var expensesArray: [Expense] { Array(expenses) }
    private func formatted(_ value: Double) -> String { CurrencyFormatter.shared.string(value, override: settingsRows.first?.currencyOverride) }
}

struct JobEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(sortDescriptors: [], predicate: NSPredicate(format: "id == %@", AppConfig.settingsID as CVarArg), animation: .default) private var settingsRows: FetchedResults<BudgetSettings>
    let job: Job?
    @State private var name: String
    @State private var location: String
    @State private var hoursText: String
    @State private var rateText: String

    init(job: Job? = nil) {
        self.job = job
        _name = State(initialValue: job?.name ?? "")
        _location = State(initialValue: job?.location ?? "")
        _hoursText = State(initialValue: job?.weeklyHours.editable ?? "")
        _rateText = State(initialValue: job?.hourlyRate.editable ?? "")
    }

    private var hoursValue: Double? { parseUserNumber(hoursText) }
    private var rateValue: Double? { parseUserNumber(rateText) }
    private var hours: Double { hoursValue ?? 0 }
    private var rate: Double { rateValue ?? 0 }
    private var valid: Bool {
        guard let hours = hoursValue, let rate = rateValue else { return false }
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && hours >= 0 && hours <= 168 && rate >= 0
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Job details")) {
                    TextField("Job name", text: $name)
                    TextField("Location (optional)", text: $location)
                    HStack {
                        Text("Weekly hours")
                        Spacer()
                        TextField("0", text: $hoursText).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 100)
                    }
                    HStack {
                        Text("Hourly rate")
                        Spacer()
                        TextField("0", text: $rateText).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 100)
                    }
                }
                Section {
                    InfoRow(title: "Estimated weekly income", value: CurrencyFormatter.shared.string(hours * rate, override: settingsRows.first?.currencyOverride))
                }
            }
            .navigationTitle(job == nil ? "Add job" : "Edit job")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let hours = hoursValue, let rate = rateValue else { return }
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let job {
                            job.name = trimmed
                            job.location = location
                            job.weeklyHours = hours
                            job.hourlyRate = rate
                        } else {
                            _ = Job(context: context, name: trimmed, location: location, weeklyHours: hours, hourlyRate: rate)
                        }
                        saveContext(context)
                        dismiss()
                    }
                    .disabled(!valid)
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { dismissKeyboard() } }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct ExpenseRow: View {
    @ObservedObject var expense: Expense
    let currencyOverride: String?
    let edit: () -> Void
    var body: some View {
        Button(action: edit) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(expense.name).lineLimit(2)
                    Text("\(expense.recurrenceValue.title) · \(expense.enabled ? "Included" : "Excluded")").font(.caption).foregroundColor(.secondary)
                }
                Spacer(minLength: 8)
                Text(CurrencyFormatter.shared.string(expense.amount, override: currencyOverride)).fontWeight(.semibold)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ExpenseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(sortDescriptors: [], predicate: NSPredicate(format: "id == %@", AppConfig.settingsID as CVarArg), animation: .default) private var settingsRows: FetchedResults<BudgetSettings>
    let expense: Expense?
    @State private var name: String
    @State private var amountText: String
    @State private var recurrence: ExpenseRecurrence
    @State private var enabled: Bool

    init(expense: Expense? = nil) {
        self.expense = expense
        _name = State(initialValue: expense?.name ?? "")
        _amountText = State(initialValue: expense.map { String($0.amount) } ?? "")
        _recurrence = State(initialValue: expense?.recurrenceValue ?? .monthly)
        _enabled = State(initialValue: expense?.enabled ?? true)
    }

    private var amountValue: Double? { parseUserNumber(amountText) }
    private var amount: Double { amountValue ?? 0 }
    private var valid: Bool {
        guard let amount = amountValue else { return false }
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && amount >= 0
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Expense details")) {
                    TextField("Expense name", text: $name)
                    TextField("Amount", text: $amountText).keyboardType(.decimalPad)
                    Picker("Recurrence", selection: $recurrence) { ForEach(ExpenseRecurrence.allCases) { Text($0.title).tag($0) } }
                    Toggle("Include in totals", isOn: $enabled)
                }
                Section {
                    InfoRow(title: "Amount", value: CurrencyFormatter.shared.string(amount, override: settingsRows.first?.currencyOverride))
                }
            }
            .navigationTitle(expense == nil ? "Add expense" : "Edit expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let amount = amountValue else { return }
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let expense { expense.name = trimmed; expense.amount = amount; expense.recurrence = recurrence.rawValue; expense.enabled = enabled }
                        else { _ = Expense(context: context, name: trimmed, amount: amount, recurrence: recurrence, enabled: enabled) }
                        saveContext(context); dismiss()
                    }.disabled(!valid)
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { dismissKeyboard() } }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Goals

struct GoalsView: View {
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)], animation: .default) private var goals: FetchedResults<Goal>
    @FetchRequest(sortDescriptors: [], predicate: NSPredicate(format: "id == %@", AppConfig.settingsID as CVarArg), animation: .default) private var settingsRows: FetchedResults<BudgetSettings>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)], animation: .default) private var jobs: FetchedResults<Job>
    @FetchRequest(sortDescriptors: [], animation: .default) private var expenses: FetchedResults<Expense>
    @State private var adding = false
    @State private var editing: Goal?

    private var weeklyLeft: Double { Array(jobs).weeklyIncome - Array(expenses).weeklyTotal }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Header(title: "Savings goals", subtitle: "Name your goals and plan ahead")
                    if let first = goals.first, let settings = settingsRows.first {
                        SavingsPlanCard(goal: first, settings: settings, weeklyLeft: weeklyLeft, currencyOverride: settings.currencyOverride)
                    }
                    if goals.isEmpty { Text("No goals yet. Add one to start planning.").foregroundColor(AppTheme.muted) }
                    ForEach(goals, id: \.objectID) { goal in GoalEditorRow(goal: goal, currencyOverride: settingsRows.first?.currencyOverride) { editing = goal } }
                    Button { adding = true } label: { Label("Add goal", systemImage: "plus.circle.fill").frame(maxWidth: .infinity) }.buttonStyle(BorderedProminentButtonStyle()).tint(AppTheme.lime).glassAction()
                }
                .padding()
                .readableWidth()
            }
            .background(AppTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Goals")
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $adding) { GoalEditorView() }
        .sheet(item: $editing) { GoalEditorView(goal: $0) }
    }
}

struct GoalEditorRow: View {
    @Environment(\.managedObjectContext) private var context
    @ObservedObject var goal: Goal
    let currencyOverride: String?
    let edit: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: edit) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) { Text(goal.name).font(.headline); Text(goal.targetDate?.shortDate ?? "No target date").font(.caption).foregroundColor(AppTheme.muted) }
                    Spacer(); Text(CurrencyFormatter.shared.string(goal.targetAmount, override: currencyOverride)).fontWeight(.semibold)
                }
            }.buttonStyle(PlainButtonStyle())
            ProgressView(value: goal.targetAmount > 0 ? min(max(goal.currentSavings / goal.targetAmount, 0), 1) : 0).progressViewStyle(LinearProgressViewStyle(tint: AppTheme.lime))
            HStack { Text(CurrencyFormatter.shared.string(goal.currentSavings, override: currencyOverride)); Spacer(); Text("of \(CurrencyFormatter.shared.string(goal.targetAmount, override: currencyOverride))").foregroundColor(AppTheme.muted) }
            UpdateSavingsCard(goal: goal, currencyOverride: currencyOverride)
            Button(role: .destructive) { context.delete(goal); saveContext(context) } label: { Label("Delete goal", systemImage: "trash") }.font(.caption)
        }.cardStyle()
    }
}

struct UpdateSavingsCard: View {
    @Environment(\.managedObjectContext) private var context
    @ObservedObject var goal: Goal
    let currencyOverride: String?
    @State private var amountText = ""
    @FocusState private var focused: Bool

    private var amount: Double? {
        guard let value = Double(amountText.replacingOccurrences(of: ",", with: ".")), value.isFinite, value > 0 else { return nil }
        return value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Update savings").font(.headline)
            HStack(spacing: 8) {
                TextField("Amount", text: $amountText)
                    .keyboardType(.decimalPad)
                    .focused($focused)
                    .multilineTextAlignment(.trailing)
                    .frame(minWidth: 80)
                Text(CurrencyFormatter.shared.symbol(override: currencyOverride))
                    .foregroundColor(AppTheme.muted)
                    .fixedSize()
            }
            .padding(10)
            .background(AppTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            HStack(spacing: 10) {
                Button {
                    guard let amount else { return }
                    goal.currentSavings = min(goal.targetAmount, goal.currentSavings + amount)
                    saveContext(context)
                    amountText = ""
                    dismissKeyboard()
                } label: {
                    Label("Add", systemImage: "plus").frame(maxWidth: .infinity)
                }
                .buttonStyle(BorderedProminentButtonStyle())
                .tint(AppTheme.lime)
                .foregroundColor(.black)
                .glassAction(tint: AppTheme.lime)
                Button {
                    guard let amount else { return }
                    goal.currentSavings = max(0, goal.currentSavings - amount)
                    saveContext(context)
                    amountText = ""
                    dismissKeyboard()
                } label: {
                    Label("Take out", systemImage: "minus").frame(maxWidth: .infinity)
                }
                .buttonStyle(BorderedButtonStyle())
                .tint(AppTheme.coral)
                .glassAction(tint: AppTheme.coral)
            }
            .disabled(amount == nil)
        }
        .padding(10)
        .background(AppTheme.background.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { dismissKeyboard() }
            }
        }
    }
}

struct GoalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(sortDescriptors: [], predicate: NSPredicate(format: "id == %@", AppConfig.settingsID as CVarArg), animation: .default) private var settingsRows: FetchedResults<BudgetSettings>
    let goal: Goal?
    @State private var name: String
    @State private var amountText: String
    @State private var savedText: String
    @State private var hasDate: Bool
    @State private var date: Date

    init(goal: Goal? = nil) {
        self.goal = goal
        _name = State(initialValue: goal?.name ?? "")
        _amountText = State(initialValue: goal.map { String($0.targetAmount) } ?? "")
        _savedText = State(initialValue: goal.map { String($0.currentSavings) } ?? "0")
        _hasDate = State(initialValue: goal?.targetDate != nil)
        _date = State(initialValue: goal?.targetDate ?? Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date())
    }

    private var amountValue: Double? { parseUserNumber(amountText) }
    private var savedValue: Double? { parseUserNumber(savedText) }
    private var amount: Double { amountValue ?? 0 }
    private var saved: Double { savedValue ?? 0 }
    private var valid: Bool {
        guard let amount = amountValue, let saved = savedValue else { return false }
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && amount > 0 && saved >= 0
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Goal details")) {
                    TextField("Goal name", text: $name)
                    TextField("Target amount", text: $amountText).keyboardType(.decimalPad)
                    TextField("Already saved", text: $savedText).keyboardType(.decimalPad)
                    Toggle("Set a target date", isOn: $hasDate)
                    if hasDate { DatePicker("Target date", selection: $date, in: Date()..., displayedComponents: .date) }
                }
                Section {
                    InfoRow(title: "Target amount", value: CurrencyFormatter.shared.string(amount, override: settingsRows.first?.currencyOverride))
                    InfoRow(title: "Saved amount", value: CurrencyFormatter.shared.string(saved, override: settingsRows.first?.currencyOverride))
                }
            }
            .navigationTitle(goal == nil ? "Add goal" : "Edit goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let amount = amountValue, let saved = savedValue else { return }
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let goal { goal.name = trimmed; goal.targetAmount = amount; goal.currentSavings = min(saved, amount); goal.targetDate = hasDate ? date : nil }
                        else { _ = Goal(context: context, name: trimmed, targetAmount: amount, currentSavings: min(saved, amount), targetDate: hasDate ? date : nil) }
                        saveContext(context); dismiss()
                    }.disabled(!valid)
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { dismissKeyboard() } }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Settings, export, and setup

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(sortDescriptors: [], predicate: NSPredicate(format: "id == %@", AppConfig.settingsID as CVarArg), animation: .default) private var settingsRows: FetchedResults<BudgetSettings>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)], animation: .default) private var jobs: FetchedResults<Job>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)], animation: .default) private var expenses: FetchedResults<Expense>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)], animation: .default) private var goals: FetchedResults<Goal>
    @AppStorage(AppConfig.setupFlag) private var showSetup = false
    @State private var confirmReset = false
    @State private var showShare = false
    @State private var shareText = ""

    var body: some View {
        NavigationView {
            Form {
                if let settings = settingsRows.first {
                    Section(header: Text("Display")) {
                        Picker("Currency", selection: Binding(get: { settings.currencyOverride ?? "system" }, set: { settings.currencyOverride = $0 == "system" ? nil : $0; saveContext(context) })) {
                            ForEach(CurrencyFormatter.choices) { Text($0.title).tag($0.id) }
                        }
                        Picker("Primary view", selection: Binding(get: { settings.primaryView }, set: { settings.primaryView = $0; saveContext(context) })) {
                            Text("Monthly").tag("monthly")
                            Text("Weekly").tag("weekly")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    Section(header: Text("Planning")) {
                        HStack {
                            Text("Weekly savings target")
                            Spacer()
                            TextField("0", value: Binding(get: { settings.weeklySavingsTarget }, set: { settings.weeklySavingsTarget = max(0, $0); saveContext(context) }), formatter: NumberFormatter.decimal)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                        }
                    }
                    Section(header: Text("Optional hours limit")) {
                        Toggle("Enable weekly hours limit", isOn: Binding(get: { settings.weeklyHoursLimitEnabled }, set: { settings.weeklyHoursLimitEnabled = $0; saveContext(context) }))
                        if settings.weeklyHoursLimitEnabled { HStack { Text("Limit per week"); Spacer(); TextField("Hours", value: Binding(get: { settings.weeklyHoursLimit }, set: { settings.weeklyHoursLimit = max(0, $0); saveContext(context) }), formatter: NumberFormatter.decimal).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 90) } }
                    }
                }
                Section(header: Text("Data")) {
                    Label(AppConfig.enableICloudSync ? "iCloud sync enabled" : "Saved on this device", systemImage: AppConfig.enableICloudSync ? "icloud" : "internaldrive")
                    Button { shareText = SummaryExporter.text(jobs: Array(jobs), expenses: Array(expenses), goals: Array(goals), settings: settingsRows.first); showShare = true } label: { Label("Export / Share summary", systemImage: "square.and.arrow.up") }
                    Button { confirmReset = true } label: { Label("Reset all data", systemImage: "trash") }.foregroundColor(.red)
                }
                Section(header: Text("Support and privacy")) {
                    if let url = AppConfig.privacyPolicyURL {
                        Link(destination: url) { Label("Privacy policy", systemImage: "hand.raised") }
                    }
                    if let url = AppConfig.supportMailURL {
                        Link(destination: url) { Label("Contact support", systemImage: "envelope") }
                    }
                    #if DEBUG
                    if !AppConfig.supportDetailsAreSet {
                        Text("Developer note (debug builds only): set privacyPolicyURLString and supportEmail in AppConfig before submitting.")
                            .font(.footnote)
                            .foregroundColor(AppTheme.coral)
                    }
                    #endif
                }
                Section(header: Text("About")) {
                    InfoRow(title: "App", value: "BudgetFlow")
                    InfoRow(title: "Minimum iOS", value: "15.0")
                    InfoRow(title: "Storage", value: "Core Data")
                }
            }
            .background(AppTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Settings")
            .alert(isPresented: $confirmReset) {
                Alert(title: Text("Reset all data?"), message: Text("This permanently removes jobs, expenses, goals, and preferences from this store."), primaryButton: .destructive(Text("Reset")) { StoreMigrator.resetAll(context: context); showSetup = true }, secondaryButton: .cancel())
            }
            .sheet(isPresented: $showShare) { ShareSheet(items: [shareText]) }
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { dismissKeyboard() } } }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct SummaryExporter {
    static func text(jobs: [Job], expenses: [Expense], goals: [Goal], settings: BudgetSettings?) -> String {
        let currency = settings?.currencyOverride
        var lines = ["BudgetFlow summary", "", "Currency: \(CurrencyFormatter.shared.identifier(override: currency))", "", "Jobs"]
        if jobs.isEmpty { lines.append("No jobs") }
        for job in jobs { lines.append("- \(job.name): \(job.weeklyHours.clean) hours/week, \(CurrencyFormatter.shared.string(job.hourlyRate, override: currency))/hour") }
        lines.append("")
        lines.append("Expenses")
        if expenses.isEmpty { lines.append("No expenses") }
        for expense in expenses { lines.append("- \(expense.name): \(CurrencyFormatter.shared.string(expense.amount, override: currency)) per \(expense.recurrenceValue.rawValue)") }
        lines.append("")
        lines.append("Savings goals")
        if goals.isEmpty { lines.append("No goals") }
        for goal in goals { lines.append("- \(goal.name): \(CurrencyFormatter.shared.string(goal.currentSavings, override: currency)) of \(CurrencyFormatter.shared.string(goal.targetAmount, override: currency))" + (goal.targetDate.map { ", target \($0.shortDate)" } ?? "")) }
        return lines.joined(separator: "\n")
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// MARK: - Components

struct Header: View { let title: String; let subtitle: String; var body: some View { VStack(alignment: .leading, spacing: 5) { Text(title).font(.system(.title, design: .rounded).weight(.bold)).foregroundColor(.white); Text(subtitle).font(.subheadline).foregroundColor(AppTheme.muted) } } }
struct InfoRow: View { let title: String; let value: String; var body: some View { HStack { Text(title); Spacer(); Text(value).foregroundColor(AppTheme.muted) } } }
struct SummaryRow: View { let title: String; let value: String; var body: some View { HStack { Text(title); Spacer(); Text(value).fontWeight(.semibold) } } }
struct SummaryPill: View { let title: String; let value: String; var body: some View { VStack(alignment: .leading, spacing: 4) { Text(title).font(.caption).foregroundColor(AppTheme.muted); Text(value).font(.headline) }.cardStyle() } }

struct MetricCard: View {
    let title: String; let value: String; let color: Color; let icon: String
    var body: some View { VStack(alignment: .leading, spacing: 10) { Image(systemName: icon).foregroundColor(color); Text(title).font(.caption).foregroundColor(AppTheme.muted); Text(value).font(.system(.title3, design: .rounded).weight(.bold)).lineLimit(1).minimumScaleFactor(0.6).foregroundColor(.white) }.cardStyle().accessibilityElement(children: .combine).accessibilityLabel("\(title), \(value)") }
}

struct JobRow: View {
    @ObservedObject var job: Job
    let currencyOverride: String?
    let edit: () -> Void

    var body: some View {
        Button(action: edit) {
            HStack(spacing: 12) {
                Image(systemName: "briefcase.fill").foregroundColor(AppTheme.lime).frame(width: 24)
                VStack(alignment: .leading, spacing: 3) {
                    Text(job.name).lineLimit(2)
                    Text(job.location.isEmpty ? "No location added" : job.location)
                        .font(.caption).foregroundColor(.secondary).lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(CurrencyFormatter.shared.string(job.weeklyPay, override: currencyOverride)).fontWeight(.semibold)
                    Text("\(job.weeklyHours.clean) hours/week").font(.caption).foregroundColor(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(job.name), \(CurrencyFormatter.shared.string(job.weeklyPay, override: currencyOverride)) per week")
    }
}

struct GoalCard: View {
    @ObservedObject var goal: Goal; let currencyOverride: String?
    var body: some View { let progress = goal.targetAmount > 0 ? min(max(goal.currentSavings / goal.targetAmount, 0), 1) : 0; return VStack(alignment: .leading, spacing: 10) { HStack { Label(goal.name, systemImage: "target").lineLimit(2); Spacer(); Text(CurrencyFormatter.shared.string(goal.targetAmount, override: currencyOverride)).fontWeight(.bold) }; ProgressView(value: progress).progressViewStyle(LinearProgressViewStyle(tint: AppTheme.lime)); HStack { Text(CurrencyFormatter.shared.string(goal.currentSavings, override: currencyOverride)).font(.headline); Spacer(); Text(goal.targetDate?.shortDate ?? "No target date").foregroundColor(AppTheme.muted) } }.cardStyle().accessibilityElement(children: .combine).accessibilityLabel("\(goal.name), \(CurrencyFormatter.shared.string(goal.currentSavings, override: currencyOverride)) of \(CurrencyFormatter.shared.string(goal.targetAmount, override: currencyOverride))") }
}

struct HoursLimitCard: View {
    let used: Double; let limit: Double
    var body: some View { let over = used > limit; return HStack(spacing: 12) { Image(systemName: over ? "exclamationmark.triangle.fill" : "checkmark.circle.fill").foregroundColor(over ? AppTheme.coral : AppTheme.lime); VStack(alignment: .leading, spacing: 4) { Text("Weekly hours limit").font(.headline); Text("\(used.clean) of \(limit.clean) hours used this week").font(.subheadline).foregroundColor(AppTheme.muted) }; Spacer(minLength: 0) }.cardStyle().overlay(RoundedRectangle(cornerRadius: 18).stroke(over ? AppTheme.coral.opacity(0.6) : AppTheme.lime.opacity(0.25), lineWidth: 1)).accessibilityElement(children: .combine) }
}

struct BalanceTrendPoint: Identifiable {
    let id: Int
    let day: Int
    let value: Double
}

/// Builds a smooth Bezier path through a set of points, scaled to fit `rect`.
/// Used for both the stroked line and (closed down to the baseline) the gradient fill area.
private func smoothPath(points: [CGPoint], in rect: CGRect, closed: Bool) -> Path {
    var path = Path()
    guard points.count > 1 else { return path }
    path.move(to: points[0])
    for i in 1..<points.count {
        let previous = points[i - 1]
        let current = points[i]
        let midX = (previous.x + current.x) / 2
        let control1 = CGPoint(x: midX, y: previous.y)
        let control2 = CGPoint(x: midX, y: current.y)
        path.addCurve(to: current, control1: control1, control2: control2)
    }
    if closed {
        path.addLine(to: CGPoint(x: points.last!.x, y: rect.maxY))
        path.addLine(to: CGPoint(x: points[0].x, y: rect.maxY))
        path.closeSubpath()
    }
    return path
}

/// A savings trend chart in the style of a banking app's "Balance" screen: a big current total,
/// a coloured delta badge, and a smooth gradient-filled line. There is no day-by-day transaction
/// history in this app, so the line is a projection at your weekly savings target's pace, not
/// a record of actual daily balances. That is stated in the caption rather than left implied.
struct SavingsAnalyticsCard: View {
    let goals: [Goal]
    let weeklySavingsTarget: Double
    let currencyOverride: String?
    @State private var revealed = false

    private var total: Double { goals.reduce(0) { $0 + $1.currentSavings } }
    private var daysElapsed: Int { max(1, Calendar.current.component(.day, from: Date())) }

    private var points: [BalanceTrendPoint] {
        let days = daysElapsed
        let dailyPace = weeklySavingsTarget / 7
        let startValue = max(total - dailyPace * Double(days - 1), 0)
        guard days > 1 else { return [BalanceTrendPoint(id: 0, day: days, value: total)] }
        let sampleCount = min(days, 10)
        let step = max(1, Int(ceil(Double(days - 1) / Double(sampleCount - 1))))
        var result: [BalanceTrendPoint] = []
        var day = 1
        while day < days {
            let value = startValue + dailyPace * Double(day - 1)
            result.append(BalanceTrendPoint(id: day, day: day, value: max(value, 0)))
            day += step
        }
        result.append(BalanceTrendPoint(id: days, day: days, value: total))
        return result
    }

    private var delta: Double {
        guard let first = points.first, let last = points.last else { return 0 }
        return last.value - first.value
    }

    private var hasData: Bool { !goals.isEmpty && (total > 0 || weeklySavingsTarget > 0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Savings").font(.subheadline).foregroundColor(AppTheme.muted)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(CurrencyFormatter.shared.string(total, override: currencyOverride))
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        if hasData, abs(delta) > 0.004 {
                            DeltaBadge(delta: delta, currencyOverride: currencyOverride)
                        }
                    }
                }
                Spacer(minLength: 8)
            }

            if hasData {
                let currentPoints = points
                let lineColor = delta >= 0 ? AppTheme.lime : AppTheme.coral
                GeometryReader { proxy in
                    let rect = CGRect(origin: .zero, size: proxy.size)
                    let plotted = plot(currentPoints, in: rect)
                    ZStack {
                        smoothPath(points: plotted, in: rect, closed: true)
                            .fill(LinearGradient(colors: [lineColor.opacity(0.35), lineColor.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                        smoothPath(points: plotted, in: rect, closed: false)
                            .trim(from: 0, to: revealed ? 1 : 0)
                            .stroke(lineColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        if let last = plotted.last, revealed {
                            Circle().fill(lineColor).frame(width: 8, height: 8).position(last)
                        }
                    }
                }
                .frame(height: 130)

                HStack {
                    ForEach(axisTicks(maxDay: points.last?.day ?? 1), id: \.self) { tick in
                        Text("\(tick)")
                            .font(.caption2)
                            .foregroundColor(AppTheme.muted)
                        if tick != axisTicks(maxDay: points.last?.day ?? 1).last { Spacer() }
                    }
                }

                Text("Projected from your weekly savings target, not a record of daily balances.")
                    .font(.caption2)
                    .foregroundColor(AppTheme.muted)
            } else {
                Text("Add a goal and a weekly savings target to see your savings trend.")
                    .foregroundColor(AppTheme.muted)
                    .frame(minHeight: 100, alignment: .center)
                    .frame(maxWidth: .infinity)
            }
        }
        .cardStyle()
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeOut(duration: 0.7)) { revealed = true }
            }
        }
    }

    /// Scales data points into the given rect, padding the value axis so the line doesn't touch the edges.
    private func plot(_ points: [BalanceTrendPoint], in rect: CGRect) -> [CGPoint] {
        guard points.count > 0 else { return [] }
        let values = points.map(\.value)
        let minValue = min(values.min() ?? 0, 0)
        let maxValue = max(values.max() ?? 1, minValue + 1)
        let dayRange = max(Double((points.last?.day ?? 1) - (points.first?.day ?? 0)), 1)
        return points.map { point in
            let xFraction = Double(point.day - (points.first?.day ?? 0)) / dayRange
            let yFraction = (point.value - minValue) / (maxValue - minValue)
            let x = rect.minX + CGFloat(xFraction) * rect.width
            let y = rect.maxY - CGFloat(yFraction) * rect.height * 0.9 - rect.height * 0.05
            return CGPoint(x: x, y: y)
        }
    }

    private func axisTicks(maxDay: Int) -> [Int] {
        guard maxDay > 1 else { return [1] }
        let tickCount = min(5, maxDay)
        let step = max(1, Int(ceil(Double(maxDay - 1) / Double(tickCount - 1))))
        var ticks = Array(stride(from: 1, to: maxDay, by: step))
        ticks.append(maxDay)
        return ticks
    }
}

private struct DeltaBadge: View {
    let delta: Double
    let currencyOverride: String?
    var body: some View {
        let positive = delta >= 0
        HStack(spacing: 2) {
            Image(systemName: positive ? "arrow.up.right" : "arrow.down.right")
            Text(CurrencyFormatter.shared.string(abs(delta), override: currencyOverride))
        }
        .font(.caption.weight(.semibold))
        .foregroundColor(positive ? AppTheme.lime : AppTheme.coral)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background((positive ? AppTheme.lime : AppTheme.coral).opacity(0.15))
        .clipShape(Capsule())
    }
}

struct MonthlyCashFlowWeek: Identifiable {
    let id: Int
    let label: String
    let income: Double
    let expenses: Double
}

private struct MonthlyChartScrollKey: PreferenceKey {
    static var defaultValue: CGFloat = .greatestFiniteMagnitude
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct MonthlyCashFlowChart: View {
    let weeklyIncome: Double
    let weeklyExpenses: Double
    let currencyOverride: String?
    @State private var revealed = false

    private var rows: [MonthlyCashFlowWeek] {
        let calendar = Calendar.current
        let daysInMonth = calendar.range(of: .day, in: .month, for: Date())?.count ?? 30
        let weekCount = min(5, max(4, Int(ceil(Double(daysInMonth) / 7.0))))
        let monthlyIncome = max(weeklyIncome, 0) * 52 / 12
        let monthlyExpenses = max(weeklyExpenses, 0) * 52 / 12
        return (0..<weekCount).map { index in
            let startDay = index * 7 + 1
            let daysThisWeek = min(7, max(0, daysInMonth - startDay + 1))
            let fraction = Double(daysThisWeek) / Double(daysInMonth)
            return MonthlyCashFlowWeek(id: index, label: "W\(index + 1)", income: monthlyIncome * fraction, expenses: monthlyExpenses * fraction)
        }
    }

    private var maxValue: Double { max(rows.flatMap { [$0.income, $0.expenses] }.max() ?? 0, 1) }

    var body: some View {
        let currentRows = rows
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Monthly cash flow").font(.headline)
                    Text("Estimated by week from recurring entries").font(.caption).foregroundColor(AppTheme.muted)
                }
                Spacer(minLength: 8)
                HStack(spacing: 8) {
                    CashFlowLegend(color: AppTheme.lime, title: "Income")
                    CashFlowLegend(color: AppTheme.coral, title: "Expenses")
                }
            }
            if weeklyIncome == 0 && weeklyExpenses == 0 {
                Text("Add jobs or expenses to see this chart.")
                    .foregroundColor(AppTheme.muted)
                    .frame(maxWidth: .infinity, minHeight: 130, alignment: .center)
            } else {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(currentRows) { row in
                        VStack(spacing: 6) {
                            HStack(alignment: .bottom, spacing: 3) {
                                CashFlowBar(value: row.income, maxValue: maxValue, color: AppTheme.lime, revealed: revealed)
                                CashFlowBar(value: row.expenses, maxValue: maxValue, color: AppTheme.coral, revealed: revealed)
                            }
                            .frame(maxWidth: .infinity, minHeight: 138, alignment: .bottom)
                            Text(row.label).font(.caption).foregroundColor(AppTheme.muted)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(row.label): income \(CurrencyFormatter.shared.string(row.income, override: currencyOverride)), expenses \(CurrencyFormatter.shared.string(row.expenses, override: currencyOverride))")
                    }
                }
                .frame(height: 165)
            }
        }
        .cardStyle()
        .opacity(revealed ? 1 : 0.82)
        .offset(y: revealed ? 0 : 18)
        .background(GeometryReader { proxy in
            Color.clear.preference(key: MonthlyChartScrollKey.self, value: proxy.frame(in: .global).minY)
        })
        .onPreferenceChange(MonthlyChartScrollKey.self) { minY in
            let screenHeight = UIScreen.main.bounds.height
            if minY < screenHeight * 0.92 && minY > -260 && !revealed {
                withAnimation(.easeOut(duration: 0.55)) { revealed = true }
            }
        }
    }
}

private struct CashFlowBar: View {
    let value: Double
    let maxValue: Double
    let color: Color
    let revealed: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(color)
            .frame(width: 13)
            .frame(height: revealed ? max(6, CGFloat(value / maxValue) * 125) : 4, alignment: .bottom)
            .animation(.spring(response: 0.6, dampingFraction: 0.82), value: revealed)
    }
}

private struct CashFlowLegend: View {
    let color: Color
    let title: String
    var body: some View { HStack(spacing: 4) { Circle().fill(color).frame(width: 7, height: 7); Text(title).font(.caption2).foregroundColor(AppTheme.muted) } }
}

/// Mirrors a banking app's "Net cashflow" tile: the monthly total, a Positive/Negative badge,
/// and two proportion bars showing how income and expenses compare.
struct NetCashFlowCard: View {
    let monthlyIncome: Double
    let monthlyExpenses: Double
    let currencyOverride: String?

    private var net: Double { monthlyIncome - monthlyExpenses }
    private var positive: Bool { net >= 0 }
    private var total: Double { max(monthlyIncome + monthlyExpenses, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Net cash flow").font(.subheadline).foregroundColor(AppTheme.muted)
            Text(CurrencyFormatter.shared.string(net, override: currencyOverride))
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            HStack(spacing: 4) {
                Image(systemName: positive ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                Text(positive ? "Positive" : "Negative")
            }
            .font(.caption.weight(.semibold))
            .foregroundColor(positive ? AppTheme.lime : AppTheme.coral)

            VStack(alignment: .leading, spacing: 6) {
                ProportionBar(fraction: monthlyIncome / total, color: AppTheme.lime)
                ProportionBar(fraction: monthlyExpenses / total, color: AppTheme.coral)
            }
            HStack(spacing: 14) {
                LegendDot(color: AppTheme.lime, title: "Income")
                LegendDot(color: AppTheme.coral, title: "Expenses")
            }
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Net cash flow \(CurrencyFormatter.shared.string(net, override: currencyOverride)), \(positive ? "positive" : "negative")")
    }
}

private struct ProportionBar: View {
    let fraction: Double
    let color: Color
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(AppTheme.background)
                Capsule().fill(color).frame(width: max(6, proxy.size.width * CGFloat(min(max(fraction, 0), 1))))
            }
        }
        .frame(height: 8)
    }
}

/// A shared palette so each goal gets a distinct, repeatable colour in the overview bar and legend.
private let goalPalette: [Color] = [AppTheme.lime, AppTheme.blue, AppTheme.coral, Color(red: 0.75, green: 0.55, blue: 1.0), Color(red: 1.0, green: 0.78, blue: 0.3)]

/// Mirrors a banking app's "Overview" card: a total, and a single segmented bar showing how
/// that total splits across your goals, with a coloured-dot legend underneath.
struct GoalsOverviewCard: View {
    let goals: [Goal]
    let currencyOverride: String?

    private var total: Double { goals.reduce(0) { $0 + $1.currentSavings } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview").font(.headline)
            if goals.isEmpty {
                Text("Add a goal in the Goals tab to see your savings breakdown.")
                    .foregroundColor(AppTheme.muted)
            } else {
                Text("Total saved").font(.subheadline).foregroundColor(AppTheme.muted)
                Text(CurrencyFormatter.shared.string(total, override: currencyOverride))
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                GeometryReader { proxy in
                    HStack(spacing: 2) {
                        ForEach(Array(goals.enumerated()), id: \.element.id) { index, goal in
                            let fraction = total > 0 ? goal.currentSavings / total : 1.0 / Double(goals.count)
                            Capsule()
                                .fill(goalPalette[index % goalPalette.count])
                                .frame(width: max(6, proxy.size.width * CGFloat(fraction)))
                        }
                    }
                }
                .frame(height: 10)

                WrapLegend(goals: goals)
            }
        }
        .cardStyle()
    }
}

/// Lays legend items out left to right, wrapping to a new line when they don't fit —
/// goal names vary in length and there can be any number of goals.
private struct WrapLegend: View {
    let goals: [Goal]
    @State private var totalHeight: CGFloat = 32

    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
        .frame(height: totalHeight)
    }

    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width: CGFloat = 0
        var height: CGFloat = 0
        return ZStack(alignment: .topLeading) {
            ForEach(Array(goals.enumerated()), id: \.element.id) { index, goal in
                LegendDot(color: goalPalette[index % goalPalette.count], title: goal.name.isEmpty ? "Goal" : goal.name)
                    .padding(.trailing, 12)
                    .padding(.bottom, 6)
                    .alignmentGuide(.leading) { dimension in
                        if width + dimension.width > geometry.size.width {
                            width = 0
                            height -= dimension.height
                        }
                        let result = width
                        width -= dimension.width
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        return result
                    }
            }
        }
        .background(GeometryReader { proxy in
            Color.clear.onAppear { totalHeight = max(32, proxy.size.height) }
        })
    }
}

private struct LegendDot: View {
    let color: Color
    let title: String
    var body: some View { HStack(spacing: 4) { Circle().fill(color).frame(width: 7, height: 7); Text(title).font(.caption2).foregroundColor(AppTheme.muted) } }
}

struct ChartRow: Identifiable { let id: UUID; let label: String; let pay: Double }
struct IncomeChart: View {
    let jobs: [Job]; let currencyOverride: String?
    private var rows: [ChartRow] { var seen: [String: Int] = [:]; return jobs.map { job in let base = job.name.isEmpty ? "Job" : job.name; seen[base, default: 0] += 1; let n = seen[base] ?? 1; return ChartRow(id: job.id, label: n > 1 ? "\(base) \(n)" : base, pay: max(job.weeklyPay, 0)) } }
    var body: some View { let rows = self.rows; let maxPay = max(rows.map(\.pay).max() ?? 1, 1); return VStack(alignment: .leading, spacing: 10) { Text("Weekly income by job").font(.headline); if rows.isEmpty { Text("Add a job to see income here.").foregroundColor(AppTheme.muted) } else { VStack(spacing: 10) { ForEach(rows) { row in HStack(spacing: 8) { Text(row.label).font(.caption).lineLimit(1).frame(width: 110, alignment: .trailing); GeometryReader { proxy in ZStack(alignment: .leading) { Capsule().fill(AppTheme.background); Capsule().fill(AppTheme.lime).frame(width: max(4, proxy.size.width * CGFloat(row.pay / maxPay))) } }.frame(height: 20); Text(CurrencyFormatter.shared.string(row.pay, override: currencyOverride)).font(.caption2).foregroundColor(AppTheme.muted).frame(width: 72, alignment: .trailing) }.accessibilityElement(children: .combine).accessibilityLabel("\(row.label), \(CurrencyFormatter.shared.string(row.pay, override: currencyOverride)) per week") } }.frame(minHeight: 120) } }.cardStyle() }
}

struct SavingsPlanCard: View { @ObservedObject var goal: Goal; @ObservedObject var settings: BudgetSettings; let weeklyLeft: Double; let currencyOverride: String?
    var body: some View { let plan = SavingsPlan(target: goal.targetAmount, saved: goal.currentSavings, weeklyTarget: settings.weeklySavingsTarget, targetDate: goal.targetDate, today: Date()); return VStack(alignment: .leading, spacing: 10) { Text("Target-date plan").font(.headline); if plan.reached { Text("Goal reached").font(.headline).foregroundColor(AppTheme.lime) } else if let date = goal.targetDate, let required = plan.requiredWeekly { Text("Save \(CurrencyFormatter.shared.string(required, override: currencyOverride)) per week to reach this goal by \(date.shortDate).").fixedSize(horizontal: false, vertical: true); Text(weeklyLeft < required ? "This is above the amount left after expenses." : "This fits within the amount currently left after expenses.").font(.footnote).foregroundColor(weeklyLeft < required ? AppTheme.coral : AppTheme.muted) } else if let weeks = plan.weeksAtTarget { Text("At your current target, about \(weeks) weeks remain.").fixedSize(horizontal: false, vertical: true) } else { Text("Set a weekly savings target in Settings to calculate timing.").foregroundColor(AppTheme.muted) } }.cardStyle() }
}

// MARK: - Theme and helpers

enum AppTheme {
    static let background = Color(red: 0.035, green: 0.055, blue: 0.11)
    // Liquid Glass bends and reflects whatever sits behind it, so a flat colour looks dead
    // once panels turn into glass. A subtle gradient gives the glass something to catch.
    static let backgroundGradient = LinearGradient(
        colors: [Color(red: 0.05, green: 0.04, blue: 0.14), Color(red: 0.03, green: 0.06, blue: 0.13), Color(red: 0.02, green: 0.03, blue: 0.09)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let panel = Color(red: 0.075, green: 0.10, blue: 0.17)
    static let lime = Color(red: 0.70, green: 0.95, blue: 0.25)
    static let blue = Color(red: 0.32, green: 0.65, blue: 1.0)
    static let coral = Color(red: 1.0, green: 0.38, blue: 0.36)
    static let muted = Color.white.opacity(0.62)
}
extension View {
    /// Every card in the app calls this. On iOS 26+ it renders as real Liquid Glass; on iOS 15–25
    /// it falls back to the app's original flat panel, so the app still runs the same on older
    /// devices (see the earlier "capable of running from iOS 15" requirement).
    @ViewBuilder
    func cardStyle() -> some View {
        if #available(iOS 26.0, *) {
            self.frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .glassEffect(.regular.tint(AppTheme.panel), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else {
            self.frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(AppTheme.panel)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
    func readableWidth(_ maxWidth: CGFloat = 700) -> some View { frame(maxWidth: maxWidth).frame(maxWidth: .infinity) }

    /// Adds interactive Liquid Glass on top of a button's existing styling, but only on iOS 26+.
    /// On iOS 15–25 it does nothing, so the button keeps looking exactly as it did before.
    @ViewBuilder
    func glassAction(tint: Color = AppTheme.lime) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(tint.opacity(0.35)).interactive(), in: Capsule())
        } else {
            self
        }
    }
}
func dismissKeyboard() { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
extension Date { var shortDate: String { DateFormatter.budgetShort.string(from: self) } }
extension DateFormatter { static let budgetShort: DateFormatter = { let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f }() }
extension NumberFormatter { static let decimal: NumberFormatter = { let f = NumberFormatter(); f.numberStyle = .decimal; f.maximumFractionDigits = 2; return f }() }
extension Double { var clean: String { String(format: "%.1f", self) }; var editable: String { let s = String(format: "%.2f", self); if s.hasSuffix(".00") { return String(s.dropLast(3)) }; if s.hasSuffix("0") { return String(s.dropLast()) }; return s } }
