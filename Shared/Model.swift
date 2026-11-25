import Foundation

extension Day {
    var monthDayLabel: String {
        utcDate.formatted(Date.FormatStyle(timeZone: TimeZone(identifier: "UTC")!).month(.abbreviated).day())
    }
}

struct MonthDay: Codable, Hashable {
    var month: Int
    var day: Int

    static func isLeap(_ y: Int) -> Bool { (y % 4 == 0 && y % 100 != 0) || y % 400 == 0 }
    static func daysIn(_ m: Int, _ y: Int) -> Int { [31, isLeap(y) ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][m - 1] }

    var valid: Bool { (1...12).contains(month) && day >= 1 && day <= Self.daysIn(month, 2024) }

    func occurrence(in year: Int) -> Day {
        Day(year: year, month: month, day: min(day, Self.daysIn(month, year)))
    }

    func next(onOrAfter today: Day) -> Day {
        let d = occurrence(in: today.year)
        return d < today ? occurrence(in: today.year + 1) : d
    }

    init(month: Int, day: Int) { self.month = month; self.day = day }
    init(_ d: Day) { self.init(month: d.month, day: d.day) }
}

enum Holiday: String, Codable, CaseIterable, Identifiable {
    case christmas, valentine, mothersDay, fathersDay, springFestival, qixi, midAutumn
    var id: String { rawValue }

    func date(in year: Int) -> Day? {
        switch self {
        case .christmas: return Day(year: year, month: 12, day: 25)
        case .valentine: return Day(year: year, month: 2, day: 14)
        case .mothersDay: return Self.nthSunday(2, month: 5, year: year)
        case .fathersDay: return Self.nthSunday(3, month: 6, year: year)
        case .springFestival: return Self.lunar(month: 1, day: 1, year: year)
        case .qixi: return Self.lunar(month: 7, day: 7, year: year)
        case .midAutumn: return Self.lunar(month: 8, day: 15, year: year)
        }
    }

    func next(onOrAfter today: Day) -> Day? {
        if let d = date(in: today.year), !(d < today) { return d }
        return date(in: today.year + 1)
    }

    static func nthSunday(_ n: Int, month: Int, year: Int) -> Day {
        let first = Day(year: year, month: month, day: 1)
        let weekday = Day.calendar.component(.weekday, from: first.utcDate)
        let firstSunday = 1 + (8 - weekday) % 7
        return Day(year: year, month: month, day: firstSunday + 7 * (n - 1))
    }

    static func lunar(month: Int, day: Int, year: Int) -> Day? {
        guard let zone = TimeZone(identifier: "Asia/Shanghai") else { return nil }
        var chinese = Calendar(identifier: .chinese)
        chinese.timeZone = zone
        var greg = Calendar(identifier: .gregorian)
        greg.timeZone = zone
        guard let start = greg.date(from: DateComponents(year: year, month: 1, day: 1)) else { return nil }
        var want = DateComponents()
        want.month = month
        want.day = day
        want.isLeapMonth = false
        guard let found = chinese.nextDate(after: start.addingTimeInterval(-1), matching: want, matchingPolicy: .strict) else { return nil }
        let d = Day(found, calendar: greg)
        return d.year == year ? d : nil
    }

    static var defaults: [Holiday] {
        (Locale.current.language.languageCode?.identifier ?? "en") == "zh" ? [.springFestival] : [.christmas]
    }
}

enum OccasionKind: Hashable {
    case birthday, anniversary, holiday(Holiday)

    var name: String {
        switch self {
        case .birthday: return L.t("occasion.birthday")
        case .anniversary: return L.t("occasion.anniversary")
        case .holiday(let h): return L.t("holiday." + h.rawValue)
        }
    }
}

struct Occasion: Hashable {
    var kind: OccasionKind
    var day: Day
}

struct Idea: Codable, Identifiable, Equatable {
    var id = UUID()
    var title = ""
    var price = ""
    var link = ""
    var note = ""
    var hasPhoto = false
    var added = Day(year: 2026, month: 1, day: 1)
    var boughtOn: Day?
    var boughtFor: Day?

    init(title: String = "", price: String = "", link: String = "", note: String = "", added: Day = .today) {
        self.title = title; self.price = price; self.link = link; self.note = note; self.added = added
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        price = try c.decodeIfPresent(String.self, forKey: .price) ?? ""
        link = try c.decodeIfPresent(String.self, forKey: .link) ?? ""
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        hasPhoto = try c.decodeIfPresent(Bool.self, forKey: .hasPhoto) ?? false
        added = try c.decodeIfPresent(Day.self, forKey: .added) ?? .today
        boughtOn = try c.decodeIfPresent(Day.self, forKey: .boughtOn)
        boughtFor = try c.decodeIfPresent(Day.self, forKey: .boughtFor)
    }

    var linkURL: URL? {
        guard let u = URL(string: link.trimmingCharacters(in: .whitespaces)),
              ["http", "https"].contains(u.scheme?.lowercased() ?? ""), u.host != nil else { return nil }
        return u
    }
    var host: String? { linkURL?.host?.replacingOccurrences(of: "www.", with: "") }
    func given(on today: Day) -> Bool { boughtFor.map { $0 < today } ?? false }
}

struct Person: Codable, Identifiable, Equatable {
    var id = UUID()
    var name = ""
    var birthday: MonthDay?
    var anniversary: MonthDay?
    var holidays: [Holiday] = Holiday.defaults
    var ideas: [Idea] = []
    var color = 0
    var sizes = ""

    enum CodingKeys: String, CodingKey { case id, name, birthday, anniversary, holidays, ideas, color, sizes }

    init(name: String = "", color: Int = 0) { self.name = name; self.color = color }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        birthday = try c.decodeIfPresent(MonthDay.self, forKey: .birthday)
        anniversary = try c.decodeIfPresent(MonthDay.self, forKey: .anniversary)
        holidays = ((try? c.decodeIfPresent([String].self, forKey: .holidays)) ?? []).compactMap(Holiday.init(rawValue:))
        ideas = try c.decodeIfPresent([Idea].self, forKey: .ideas) ?? []
        color = try c.decodeIfPresent(Int.self, forKey: .color) ?? 0
        sizes = try c.decodeIfPresent(String.self, forKey: .sizes) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(birthday, forKey: .birthday)
        try c.encodeIfPresent(anniversary, forKey: .anniversary)
        try c.encode(holidays.map(\.rawValue), forKey: .holidays)
        try c.encode(ideas, forKey: .ideas)
        try c.encode(color, forKey: .color)
        if !sizes.isEmpty { try c.encode(sizes, forKey: .sizes) }
    }

    var displayName: String {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? L.t("person.unnamed") : n
    }
    var initial: String { String(displayName.prefix(1)).uppercased() }

    func occasions(from today: Day) -> [Occasion] {
        var out: [Occasion] = []
        if let b = birthday, b.valid { out.append(Occasion(kind: .birthday, day: b.next(onOrAfter: today))) }
        if let a = anniversary, a.valid { out.append(Occasion(kind: .anniversary, day: a.next(onOrAfter: today))) }
        for h in holidays { if let d = h.next(onOrAfter: today) { out.append(Occasion(kind: .holiday(h), day: d)) } }
        return out.sorted { $0.day < $1.day }
    }

    func nextOccasion(from today: Day) -> Occasion? { occasions(from: today).first }

    var wanted: [Idea] { ideas.filter { $0.boughtFor == nil } }
    func waiting(_ today: Day) -> [Idea] { ideas.filter { $0.boughtFor != nil && !$0.given(on: today) } }
    func given(_ today: Day) -> [(year: Int, ideas: [Idea])] {
        let g = Dictionary(grouping: ideas.filter { $0.given(on: today) }) { $0.boughtFor?.year ?? 0 }
        return g.keys.sorted(by: >).map { ($0, g[$0] ?? []) }
    }

    func index(_ ideaID: UUID) -> Int? { ideas.firstIndex { $0.id == ideaID } }
}

struct Entitlement: Codable, Equatable {
    var firstOpen = Date()
    var trialClaimedAt: Date?
    var purchasedPro = false

    var trialStart: Date { min(firstOpen, trialClaimedAt ?? firstOpen) }
    var trialEnd: Date { trialStart.addingTimeInterval(30 * 86_400) }
    func hasPro(at now: Date) -> Bool {
        Launch.freePeriod || purchasedPro || (now >= trialStart && now < trialEnd)
    }
}

struct AppState: Codable, Equatable {
    var people: [Person] = []
    var entitlement = Entitlement()
    var leadDays = 14
    var openDays: [String] = []
    var reviewAsked = false
    var milestonesShown: [String] = []
    var totalIdeas = 0

    static let leadRange = 1...60
    static let avatarCount = 5

    enum CodingKeys: String, CodingKey { case people, entitlement, leadDays, openDays, reviewAsked, milestonesShown, totalIdeas }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        people = try c.decodeIfPresent([Person].self, forKey: .people) ?? []
        entitlement = try c.decodeIfPresent(Entitlement.self, forKey: .entitlement) ?? Entitlement()
        let lead = try c.decodeIfPresent(Int.self, forKey: .leadDays) ?? 14
        leadDays = min(max(lead, Self.leadRange.lowerBound), Self.leadRange.upperBound)
        openDays = try c.decodeIfPresent([String].self, forKey: .openDays) ?? []
        reviewAsked = try c.decodeIfPresent(Bool.self, forKey: .reviewAsked) ?? false
        milestonesShown = try c.decodeIfPresent([String].self, forKey: .milestonesShown) ?? []
        totalIdeas = try c.decodeIfPresent(Int.self, forKey: .totalIdeas) ?? 0
    }

    func canAdd(hasPro: Bool) -> Bool { hasPro || people.count < Launch.freeLimit }
    func index(_ id: UUID) -> Int? { people.firstIndex { $0.id == id } }
    func person(_ id: UUID) -> Person? { people.first { $0.id == id } }

    func sorted(_ today: Day) -> [Person] {
        people.sorted { a, b in
            let x = a.nextOccasion(from: today)?.day, y = b.nextOccasion(from: today)?.day
            if let x, let y, x != y { return x < y }
            if x != nil, y == nil { return true }
            if x == nil, y != nil { return false }
            return a.displayName.localizedStandardCompare(b.displayName) == .orderedAscending
        }
    }

    mutating func addPerson(_ p: Person) {
        var p = p
        p.name = String(p.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        p.color = people.count % Self.avatarCount
        people.append(p)
    }

    @discardableResult
    mutating func addIdea(_ idea: Idea, to personID: UUID) -> Bool {
        guard let i = index(personID) else { return false }
        var idea = idea
        idea.title = String(idea.title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        guard !idea.title.isEmpty else { return false }
        people[i].ideas.insert(idea, at: 0)
        totalIdeas += 1
        if totalIdeas >= 10, !milestonesShown.contains("ten") { milestonesShown.append("ten"); return true }
        return false
    }

    mutating func toggleBought(_ ideaID: UUID, of personID: UUID, today: Day) {
        guard let p = index(personID), let i = people[p].index(ideaID) else { return }
        if people[p].ideas[i].boughtFor == nil {
            people[p].ideas[i].boughtOn = today
            people[p].ideas[i].boughtFor = people[p].nextOccasion(from: today)?.day ?? today
        } else {
            people[p].ideas[i].boughtOn = nil
            people[p].ideas[i].boughtFor = nil
        }
    }

    mutating func again(_ ideaID: UUID, of personID: UUID, today: Day) {
        guard let p = index(personID), let i = people[p].index(ideaID) else { return }
        let old = people[p].ideas[i]
        addIdea(Idea(title: old.title, price: old.price, link: old.link, note: old.note, added: today), to: personID)
    }

    mutating func update(_ idea: Idea, of personID: UUID, moveTo target: UUID? = nil) {
        guard let p = index(personID), let i = people[p].index(idea.id) else { return }
        var idea = idea
        idea.title = String(idea.title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        if idea.title.isEmpty { idea.title = people[p].ideas[i].title }
        if let target, target != personID, let t = index(target) {
            people[p].ideas.remove(at: i)
            people[t].ideas.insert(idea, at: 0)
        } else {
            people[p].ideas[i] = idea
        }
    }

    @discardableResult
    mutating func deleteIdea(_ ideaID: UUID, of personID: UUID) -> Idea? {
        guard let p = index(personID), let i = people[p].index(ideaID) else { return nil }
        return people[p].ideas.remove(at: i)
    }

    mutating func restore(_ idea: Idea, to personID: UUID, at position: Int = 0) {
        guard let p = index(personID), people[p].index(idea.id) == nil else { return }
        people[p].ideas.insert(idea, at: min(max(position, 0), people[p].ideas.count))
    }

    mutating func removeIdea(_ ideaID: UUID, of personID: UUID) -> (Idea, Int)? {
        guard let p = index(personID), let i = people[p].index(ideaID) else { return nil }
        return (people[p].ideas.remove(at: i), i)
    }

    mutating func deletePerson(_ id: UUID) { people.removeAll { $0.id == id } }

    mutating func importPerson(_ incoming: Person, hasPro: Bool) -> (UUID, Int)? {
        let key = Self.norm(incoming.name)
        if let i = people.firstIndex(where: { Self.norm($0.name) == key }) {
            var have = Set(people[i].ideas.map { Self.norm($0.title) })
            var fresh: [Idea] = []
            for idea in incoming.ideas where !have.contains(Self.norm(idea.title)) {
                have.insert(Self.norm(idea.title))
                fresh.append(idea)
            }
            people[i].ideas.insert(contentsOf: fresh, at: 0)
            if people[i].sizes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { people[i].sizes = incoming.sizes }
            totalIdeas += fresh.count
            return (people[i].id, fresh.count)
        }
        guard canAdd(hasPro: hasPro) else { return nil }
        addPerson(incoming)
        totalIdeas += incoming.ideas.count
        return (people[people.count - 1].id, incoming.ideas.count)
    }

    static func norm(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .components(separatedBy: .whitespacesAndNewlines).joined()
    }

    var ideaCount: Int { people.reduce(0) { $0 + $1.ideas.count } }
}

enum GiftError: Error, Equatable {
    case save, store, badCode, limit

    var message: String {
        switch self {
        case .save: return L.t("error.save")
        case .store: return L.t("error.store")
        case .badCode: return L.t("error.badCode")
        case .limit: return L.f("error.limit", Launch.freeLimit)
        }
    }
}
