import Foundation

enum ReminderPlan {
    static func items(_ state: AppState, today: Day) -> [(person: Person, occasion: Occasion, fire: Day)] {
        var out: [(person: Person, occasion: Occasion, fire: Day)] = []
        for p in state.people {
            for o in p.occasions(from: today) {
                let fire = o.day.adding(days: -state.leadDays)
                let ahead = today.days(until: fire)
                if ahead >= 0, ahead <= 60 { out.append((p, o, fire)) }
            }
        }
        return Array(out.sorted { $0.fire < $1.fire }.prefix(60))
    }
}
