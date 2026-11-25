import SwiftUI
import UserNotifications

@main
struct GiftIdeasApp: App {
    @UIApplicationDelegateAdaptor(NotificationDelegate.self) private var delegate
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .onAppear { model.start(); delegate.model = model }
                .onChange(of: phase) { _, p in
                    if p == .active { model.reloadFromDisk(); Task { await model.reschedule() } }
                }
        }
    }
}

final class NotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    weak var model: AppModel?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let s = response.notification.request.content.userInfo["person"] as? String, let id = UUID(uuidString: s) else { return }
        await MainActor.run {
            guard let model, model.person(id) != nil else { return }
            model.route = nil
            model.path = [id]
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack(path: $model.path) {
            HomeView()
                .navigationDestination(for: UUID.self) { PersonView(id: $0) }
        }
        .tint(Theme.accentDeep)
        .foregroundStyle(Theme.ink)
        .sheet(item: $model.route) { route in
            sheet(route).environmentObject(model)
        }
        .overlay(alignment: .top) {
            if let n = model.notice {
                HStack(spacing: 10) {
                    Text(n).font(.subheadline.weight(.semibold)).multilineTextAlignment(.center).testID("app.notice")
                    if model.undoable != nil {
                        Button(L.t("action.undo")) { model.undoDelete() }.font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.accentDeep).frame(minWidth: 44, minHeight: 44).testID("app.undo")
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Theme.paper, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.line))
                .shadow(color: Theme.shadow, radius: 12, x: 0, y: 4)
                .padding(.top, 6).padding(.horizontal, 16)
                .task(id: n) {
                    try? await Task.sleep(for: .seconds(model.undoable == nil ? 3 : 8))
                    if model.notice == n { model.notice = nil; model.undoable = nil }
                }
            }
        }
    }

    @ViewBuilder private func sheet(_ route: Route) -> some View {
        switch route {
        case .person(let id): PersonEditor(id: id)
        case .idea(let p, let i): IdeaEditor(personID: p, ideaID: i)
        case .settings: SettingsView()
        case .paywall: PaywallView(store: model.purchases)
        case .shareCard: ShareCardView()
        case .milestone: MilestoneView()
        case .shareDemo:
            ShareSaveView(draft: ShareParse.draft(title: L.t("demo.shareTitle"), url: URL(string: "https://shop.example.com/flask"),
                                                  text: L.t("demo.shareText")),
                          people: model.state.sorted(model.today),
                          onSave: { d, p in
                              var idea = Idea(title: d.title, price: d.price, link: d.link, added: model.today)
                              if idea.linkURL == nil { idea.link = "" }
                              model.state.addIdea(idea, to: p)
                              model.persist()
                          },
                          onCancel: { model.route = nil })
        }
    }
}

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var adding: UUID?
    @State private var text = ""
    @FocusState private var focused: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let people = model.state.sorted(model.today)
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.groupSpacing) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L.t("app.name")).font(.largeTitle.bold()).testID("home.title")
                        .accessibilityAddTraits(.isHeader)
                    Text(L.t("home.subtitle")).font(.subheadline).foregroundStyle(Theme.muted)
                }
                if people.isEmpty {
                    empty
                } else {
                    upcoming(people)
                }
                actions
                if !people.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(title: L.t("home.people"))
                        ForEach(Array(people.enumerated()), id: \.element.id) { i, p in
                            row(p, index: i)
                        }
                    }
                }
            }
            .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background.ignoresSafeArea())
    }

    private var actions: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: typeSize.isAccessibilitySize ? 1 : 2)
        return LazyVGrid(columns: columns, spacing: 10) {
            Button { model.requestNewPerson() } label: {
                IconTile(title: L.t("person.newTitle"), icon: "person.badge.plus")
            }
            .buttonStyle(.plain).testID("home.addPerson")
            Button { model.route = .settings } label: {
                IconTile(title: L.t("settings.title"), icon: "gearshape", tone: .brown)
            }
            .buttonStyle(.plain).accessibilityLabel(L.t("settings.title")).testID("home.settings")
        }
    }

    private func upcoming(_ people: [Person]) -> some View {
        let next = people.compactMap { person -> (person: Person, occasion: Occasion)? in
            guard let occasion = person.occasions(from: model.today).first(where: { $0.kind != .anniversary }) else { return nil }
            return (person, occasion)
        }.min { $0.occasion.day < $1.occasion.day }

        return HeroCard(symbol: next == nil ? "calendar" : "calendar.badge.clock") {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(title: L.t("home.upcoming"))
                if let next {
                    let days = model.today.days(until: next.occasion.day)
                    Text(L.f("home.upcomingEvent", next.person.displayName, next.occasion.kind.name))
                        .font(.body.weight(.semibold))
                    Text(next.occasion.day.monthDayLabel).font(.footnote).foregroundStyle(Theme.muted)
                    Text(DaysChip.label(days))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .monospacedDigit().foregroundStyle(Theme.accentDeep)
                        .minimumScaleFactor(0.75)
                    ProgressView(value: Double(max(0, model.state.leadDays - days)), total: Double(model.state.leadDays))
                        .progressViewStyle(.linear).tint(Theme.accentDeep).accessibilityHidden(true)
                    StatusPill(text: L.f("home.wantedCount", next.person.wanted.count), tone: .cream, icon: "gift.fill")
                } else {
                    Text(L.t("home.noUpcoming")).font(.title2.bold())
                }
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 14) {
            HeroCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L.t("home.emptyTitle")).font(.title2.bold())
                    Text(L.t("home.emptyBody")).font(.subheadline).foregroundStyle(Theme.muted)
                }
            }
            PrimaryButton(title: L.t("home.addFirst"), id: "home.addFirst", icon: "person.badge.plus") {
                model.requestNewPerson()
            }
            Text(L.t("home.emptyNote")).font(.footnote).foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private func row(_ p: Person, index: Int) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 12) {
                    Avatar(person: p)
                    let layout = typeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 5))
                        : AnyLayout(HStackLayout(alignment: .center, spacing: 6))
                    layout {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(p.displayName).font(.headline).testID("person.name.\(index)")
                            Text(subtitle(p)).font(.footnote).foregroundStyle(Theme.muted).testID("person.sub.\(index)")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        if let o = p.nextOccasion(from: model.today) {
                            let d = model.today.days(until: o.day)
                            DaysChip(days: d, text: DaysChip.label(d))
                        } else {
                            StatusPill(text: L.t("home.noDate"), tone: .brown)
                        }
                    }
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .onTapGesture { model.path = [p.id] }
                .accessibilityElement(children: .combine).accessibilityAddTraits(.isButton)
                .testID("person.\(index)")
                Button {
                    text = ""
                    withAnimation(.snappy) { adding = adding == p.id ? nil : p.id }
                    Task { try? await Task.sleep(for: .milliseconds(150)); focused = adding != nil }
                } label: {
                    IconBadge(icon: adding == p.id ? "xmark" : "plus", circular: true, decorative: false)
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityLabel(L.f("home.addIdeaFor", p.displayName)).testID("person.add.\(index)")
            }
            .padding(.vertical, 10).padding(.leading, 14).padding(.trailing, 10)
            if adding == p.id {
                Divider().padding(.horizontal, 14)
                TextField(L.f("home.quickPrompt", p.displayName), text: $text)
                    .focused($focused).submitLabel(.done)
                    .padding(.horizontal, 14).frame(minHeight: 50)
                    .onSubmit {
                        model.addIdea(text, to: p.id)
                        if !text.trimmingCharacters(in: .whitespaces).isEmpty { model.notice = L.f("home.added", p.displayName) }
                        text = ""
                        withAnimation(.snappy) { adding = nil }
                    }
                    .testID("quick.field")
            }
        }
        .card()
    }

    private func subtitle(_ p: Person) -> String {
        let n = p.wanted.count
        let ideas = n == 0 ? L.t("home.noIdeas") : L.f("home.ideas", n)
        guard let o = p.nextOccasion(from: model.today) else { return ideas }
        return o.kind.name + " · " + ideas
    }
}
