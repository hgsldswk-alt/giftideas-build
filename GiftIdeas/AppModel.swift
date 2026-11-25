import CoreImage
import StoreKit
import SwiftUI
import UIKit
import UserNotifications

enum Route: Identifiable, Equatable {
    case person(UUID?), idea(UUID, UUID?), settings, paywall, shareCard, milestone, shareDemo
    var id: String {
        switch self {
        case .person(let id): return "person-\(id?.uuidString ?? "new")"
        case .idea(let p, let i): return "idea-\(p)-\(i?.uuidString ?? "new")"
        case .settings: return "settings"
        case .paywall: return "paywall"
        case .shareCard: return "shareCard"
        case .milestone: return "milestone"
        case .shareDemo: return "shareDemo"
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var state = AppState()
    @Published var route: Route?
    @Published var path: [UUID] = []
    @Published var notice: String?
    @Published var undoable: (idea: Idea, person: UUID, at: Int)?
    @Published var notificationsDenied = false
    let purchases = StoreModel()
    private var loaded = false

    var today: Day { .today }
    var now: Date { Launch.testFlag("-expired") ? state.entitlement.firstOpen.addingTimeInterval(40 * 86_400) : Date() }
    var hasPro: Bool { state.entitlement.hasPro(at: now) }

    func start() {
        guard !loaded else { return }
        loaded = true
        if Launch.testFlag("-reset") { Store.reset() }
        if let saved = Store.load() {
            state = saved
        } else {
            state = AppState()
            state.entitlement.firstOpen = Launch.testing ? Date() : TrialAnchor.firstOpen(Date())
            if Launch.testFlag("-demo") { state = Demo.state(base: state, today: today) }
        }
        if Launch.testFlag("-paid") { state.entitlement.purchasedPro = true }
        markOpen()
        persist()
        purchases.start(applyPurchase)
        Task { await reschedule() }
        if Launch.testFlag("-paywall") { route = .paywall }
        if Launch.testFlag("-share-demo") { route = .shareDemo }
        if Launch.testFlag("-open-first"), let first = state.sorted(today).first { path = [first.id] }
    }

    func reloadFromDisk() {
        guard loaded, route == nil, let saved = Store.load(), saved != state else { return }
        state = saved
    }

    func persist() {
        do { try Store.save(state) } catch { notice = GiftError.save.message }
    }

    func person(_ id: UUID) -> Person? { state.person(id) }


    func requestNewPerson() {
        guard state.canAdd(hasPro: hasPro) else { notice = GiftError.limit.message; route = .paywall; return }
        route = .person(nil)
    }

    func savePerson(_ p: Person) {
        if let i = state.index(p.id) {
            var p = p
            p.name = String(p.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
            state.people[i] = p
        } else {
            guard state.canAdd(hasPro: hasPro) else { route = .paywall; return }
            state.addPerson(p)
        }
        persist()
        Task { await reschedule() }
    }

    func deletePerson(_ id: UUID) {
        if let p = person(id) { for i in p.ideas where i.hasPhoto { Photos.remove(i.id) } }
        path.removeAll { $0 == id }
        state.deletePerson(id)
        persist()
        Task { await reschedule() }
    }

    func importCode(_ text: String) -> Bool {
        do {
            let incoming = try Transfer.person(from: text, today: today)
            guard let (id, n) = state.importPerson(incoming, hasPro: hasPro) else {
                notice = GiftError.limit.message
                return false
            }
            persist()
            notice = L.f("import.done", incoming.displayName, n)
            path = [id]
            Task { await reschedule() }
            return true
        } catch {
            notice = (error as? GiftError ?? .badCode).message
            return false
        }
    }


    func addIdea(_ title: String, to personID: UUID) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let milestone = withAnimation { state.addIdea(Idea(title: t, added: today), to: personID) }
        persist()
        if !Launch.testing { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        if milestone { Task { try? await Task.sleep(for: .milliseconds(500)); if route == nil { route = .milestone } } }
    }

    func saveIdea(_ idea: Idea, of personID: UUID, moveTo target: UUID?, photo: Data?, isNew: Bool) {
        var idea = idea
        if let photo { Photos.save(photo, for: idea.id); idea.hasPhoto = true }
        if isNew {
            if state.addIdea(idea, to: personID) { Task { try? await Task.sleep(for: .milliseconds(700)); if route == nil { route = .milestone } } }
            if let target, target != personID { state.update(idea, of: personID, moveTo: target) }
        } else {
            state.update(idea, of: personID, moveTo: target)
        }
        persist()
    }

    func toggleBought(_ ideaID: UUID, of personID: UUID) {
        let wasWanted = person(personID)?.ideas.first { $0.id == ideaID }?.boughtFor == nil
        withAnimation(.easeOut(duration: 0.25)) { state.toggleBought(ideaID, of: personID, today: today) }
        persist()
        if wasWanted {
            if !Launch.testing { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            askReviewIfReady()
        }
    }

    func again(_ ideaID: UUID, of personID: UUID) {
        withAnimation { state.again(ideaID, of: personID, today: today) }
        persist()
        notice = L.t("idea.againDone")
    }

    func deleteIdea(_ ideaID: UUID, of personID: UUID) {
        guard let r = withAnimation(.easeOut(duration: 0.2), { state.removeIdea(ideaID, of: personID) }) else { return }
        persist()
        undoable = (r.0, personID, r.1)
        notice = L.t("idea.deleted")
    }

    func undoDelete() {
        guard let u = undoable else { return }
        withAnimation { state.restore(u.idea, to: u.person, at: u.at) }
        persist()
        undoable = nil
        notice = nil
    }


    func reschedule() async {
        notificationsDenied = await Reminders.sync(state, today: today)
    }

    func setLead(_ days: Int) {
        state.leadDays = min(max(days, AppState.leadRange.lowerBound), AppState.leadRange.upperBound)
        persist()
        Task { await reschedule() }
    }


    func applyPurchase(_ pro: Bool?, _ trial: Date?) async throws {
        if let pro { state.entitlement.purchasedPro = pro }
        if let trial { state.entitlement.trialClaimedAt = min(state.entitlement.trialClaimedAt ?? trial, trial) }
        try Store.save(state)
    }


    private func markOpen() {
        let d = today.iso
        if !state.openDays.contains(d) { state.openDays = Array((state.openDays + [d]).suffix(10)) }
    }

    private func askReviewIfReady() {
        guard !state.reviewAsked, state.openDays.count >= 3, !Launch.testing || Launch.testFlag("-review") else { return }
        state.reviewAsked = true
        persist()
        if Launch.testing { notice = "review.requested"; return }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard route == nil else { return }
            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                AppStore.requestReview(in: scene)
            }
        }
    }
}

enum Photos {
    static var folder: URL {
        let f = Store.root.appendingPathComponent("photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: f, withIntermediateDirectories: true)
        return f
    }
    static func url(_ id: UUID) -> URL { folder.appendingPathComponent("\(id.uuidString).jpg") }

    static func save(_ data: Data, for id: UUID) {
        guard let img = UIImage(data: data) else { return }
        let scale = min(1, 1200 / max(img.size.width, img.size.height))
        let size = CGSize(width: img.size.width * scale, height: img.size.height * scale)
        let out = UIGraphicsImageRenderer(size: size).jpegData(withCompressionQuality: 0.8) { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
        try? out.write(to: url(id), options: .atomic)
    }

    static func image(_ id: UUID) -> UIImage? { UIImage(contentsOfFile: url(id).path) }
    static func remove(_ id: UUID) { try? FileManager.default.removeItem(at: url(id)) }
}

enum Reminders {
    static func sync(_ state: AppState, today: Day) async -> Bool {
        if Launch.testFlag("-notifications-denied") { return !state.people.isEmpty }
        guard !Launch.testing else { return false }
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        let items = ReminderPlan.items(state, today: today)
        guard !items.isEmpty else { return false }
        var settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
            settings = await center.notificationSettings()
        }
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return true }
        for item in items {
            guard let date = item.fire.local(hour: 9), date > Date() else { continue }
            let content = UNMutableNotificationContent()
            let days = item.fire.days(until: item.occasion.day)
            content.title = L.f("remind.title", item.person.displayName, item.occasion.kind.name, days)
            let n = item.person.wanted.count
            content.body = n > 0 ? L.f("remind.body", n) : L.t("remind.bodyEmpty")
            content.sound = .default
            content.userInfo = ["person": item.person.id.uuidString]
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: "\(item.person.id)-\(item.occasion.day.iso)", content: content, trigger: trigger))
        }
        return false
    }
}

enum QR {
    static func image(_ text: String, size: CGFloat = 220) -> UIImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(text.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let out = filter.outputImage else { return nil }
        let scaled = out.transformed(by: CGAffineTransform(scaleX: size / out.extent.width, y: size / out.extent.height))
        guard let cg = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

enum Demo {
    static func state(base: AppState, today: Day) -> AppState {
        var s = base
        func idea(_ k: String, price: String = "", link: String = "", note: String = "", ago: Int) -> Idea {
            Idea(title: L.t("demo." + k), price: price.isEmpty ? "" : L.t("demo." + k + ".price"), link: link, note: note.isEmpty ? "" : L.t("demo." + k + ".note"), added: today.adding(days: -ago))
        }
        var mom = Person(name: L.t("demo.mom"))
        mom.birthday = MonthDay(today.adding(days: 12))
        mom.holidays = [.mothersDay]
        mom.sizes = L.t("demo.momSizes")
        mom.ideas = [idea("flask", note: "y", ago: 21), idea("flask2", price: "y", link: "https://shop.example.com/flask", ago: 9), idea("opera", note: "y", ago: 40)]
        var scarf = idea("scarf", price: "y", ago: 30)
        scarf.boughtOn = today.adding(days: -4); scarf.boughtFor = mom.birthday?.next(onOrAfter: today)
        var massager = idea("massager", ago: 400); massager.boughtFor = Day(year: today.year - 1, month: mom.birthday!.month, day: mom.birthday!.day)
        var glasses = idea("glasses", ago: 400); glasses.boughtFor = massager.boughtFor
        var quilt = idea("quilt", ago: 760); quilt.boughtFor = Day(year: today.year - 2, month: mom.birthday!.month, day: mom.birthday!.day)
        mom.ideas += [scarf, massager, glasses, quilt]
        var lily = Person(name: L.t("demo.lily"))
        lily.holidays = [.christmas]
        lily.ideas = [idea("record", price: "y", ago: 15), idea("plant", ago: 50)]
        var dad = Person(name: L.t("demo.dad"))
        dad.holidays = [.fathersDay]
        dad.ideas = [idea("knife", price: "y", ago: 70)]
        var sam = Person(name: L.t("demo.sam"))
        sam.birthday = MonthDay(today.adding(days: 248))
        sam.holidays = []
        for p in [mom, lily, dad, sam] { s.addPerson(p) }
        s.totalIdeas = s.ideaCount
        s.milestonesShown = ["ten"]
        return s
    }
}
