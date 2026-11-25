import Foundation

struct Day: Codable, Hashable, Comparable {
    var year: Int
    var month: Int
    var day: Int

    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    init(year: Int, month: Int, day: Int) {
        self.year = year; self.month = month; self.day = day
    }

    init(_ date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year ?? 2000, month: c.month ?? 1, day: c.day ?? 1)
    }

    var utcDate: Date { Self.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))! }

    func local(hour: Int, calendar: Calendar = .current) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))
    }

    func adding(days: Int) -> Day {
        Day(Self.calendar.date(byAdding: .day, value: days, to: utcDate)!, calendar: Self.calendar)
    }

    func days(until other: Day) -> Int {
        Self.calendar.dateComponents([.day], from: utcDate, to: other.utcDate).day ?? 0
    }

    static func < (a: Day, b: Day) -> Bool { (a.year, a.month, a.day) < (b.year, b.month, b.day) }

    static var today: Day {
        if Launch.testing, let i = Launch.arguments.firstIndex(of: "-today"), i + 1 < Launch.arguments.count,
           let d = Day(iso: Launch.arguments[i + 1]) { return d }
        return Day(Date())
    }

    init?(iso: String) {
        let p = iso.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3, (1900...2200).contains(p[0]), (1...12).contains(p[1]), (1...31).contains(p[2]) else { return nil }
        let d = Day(year: p[0], month: p[1], day: p[2])
        guard Day(d.utcDate, calendar: Self.calendar) == d else { return nil }
        self = d
    }

    var iso: String { String(format: "%04d-%02d-%02d", year, month, day) }
    var label: String { utcDate.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, timeZone: TimeZone(identifier: "UTC")!)) }
}

