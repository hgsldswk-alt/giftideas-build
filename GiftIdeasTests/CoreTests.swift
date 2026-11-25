import XCTest

final class CoreTests: XCTestCase {
    private let today = Day(year: 2026, month: 11, day: 24)


    func testFeb29BirthdayFallsOnFeb28InCommonYears() {
        let b = MonthDay(month: 2, day: 29)
        XCTAssertEqual(b.next(onOrAfter: today), Day(year: 2027, month: 2, day: 28))
        XCTAssertEqual(b.next(onOrAfter: Day(year: 2028, month: 1, day: 1)), Day(year: 2028, month: 2, day: 29))
    }

    func testBirthdayTodayCountsAsToday() {
        let b = MonthDay(month: 11, day: 24)
        XCTAssertEqual(b.next(onOrAfter: today), today)
        XCTAssertEqual(MonthDay(month: 11, day: 23).next(onOrAfter: today), Day(year: 2027, month: 11, day: 23))
        XCTAssertFalse(MonthDay(month: 2, day: 30).valid)
        XCTAssertFalse(MonthDay(month: 13, day: 1).valid)
    }

    func testHolidayDates() {
        XCTAssertEqual(Holiday.mothersDay.date(in: 2026), Day(year: 2026, month: 5, day: 10))
        XCTAssertEqual(Holiday.fathersDay.date(in: 2026), Day(year: 2026, month: 6, day: 21))
        XCTAssertEqual(Holiday.mothersDay.date(in: 2027), Day(year: 2027, month: 5, day: 9))
        XCTAssertEqual(Holiday.springFestival.date(in: 2026), Day(year: 2026, month: 2, day: 17))
        XCTAssertEqual(Holiday.springFestival.date(in: 2027), Day(year: 2027, month: 2, day: 6))
        XCTAssertEqual(Holiday.midAutumn.date(in: 2026), Day(year: 2026, month: 9, day: 25))
        XCTAssertEqual(Holiday.christmas.next(onOrAfter: today), Day(year: 2026, month: 12, day: 25))
        XCTAssertEqual(Holiday.springFestival.next(onOrAfter: today), Day(year: 2027, month: 2, day: 6))
        for h in Holiday.allCases { for y in 2026...2040 { XCTAssertNotNil(h.date(in: y), "\(h) \(y)") } }
    }

    func testNextOccasionAndHomeOrder() {
        var s = AppState()
        var a = Person(name: "Ann"); a.holidays = [.christmas]
        var b = Person(name: "Bob"); b.holidays = []; b.birthday = MonthDay(month: 12, day: 1)
        var c = Person(name: "Cid"); c.holidays = []
        for p in [a, b, c] { s.addPerson(p) }
        XCTAssertEqual(s.sorted(today).map(\.name), ["Bob", "Ann", "Cid"])
        XCTAssertEqual(s.people[1].nextOccasion(from: today)?.kind, .birthday)
        XCTAssertNil(s.people[2].nextOccasion(from: today))
    }


    func testBoughtThenGivenAfterTheDayAndUndo() {
        var s = AppState()
        var p = Person(name: "Mom"); p.holidays = []; p.birthday = MonthDay(month: 12, day: 6)
        s.addPerson(p)
        let pid = s.people[0].id
        s.addIdea(Idea(title: "  Mug  ", added: today), to: pid)
        XCTAssertEqual(s.people[0].ideas[0].title, "Mug")
        let iid = s.people[0].ideas[0].id
        s.toggleBought(iid, of: pid, today: today)
        XCTAssertEqual(s.people[0].ideas[0].boughtFor, Day(year: 2026, month: 12, day: 6))
        XCTAssertTrue(s.people[0].wanted.isEmpty)
        XCTAssertEqual(s.people[0].waiting(today).count, 1)
        let later = Day(year: 2026, month: 12, day: 7)
        XCTAssertEqual(s.people[0].given(later).first?.year, 2026)
        XCTAssertTrue(s.people[0].waiting(later).isEmpty)
        s.toggleBought(iid, of: pid, today: today)
        XCTAssertEqual(s.people[0].wanted.count, 1)
        XCTAssertNil(s.people[0].ideas[0].boughtOn)
    }

    func testEmptyTitleIgnoredMilestoneAtTenDeleteRestoreAndMove() {
        var s = AppState()
        s.addPerson(Person(name: "A")); s.addPerson(Person(name: "B"))
        let a = s.people[0].id, b = s.people[1].id
        XCTAssertFalse(s.addIdea(Idea(title: "   "), to: a))
        XCTAssertEqual(s.totalIdeas, 0)
        var hit = 0
        for i in 1...12 { if s.addIdea(Idea(title: "Idea \(i)"), to: a) { hit += 1 } }
        XCTAssertEqual(hit, 1)
        let first = s.people[0].ideas[0]
        let removed = s.deleteIdea(first.id, of: a)
        XCTAssertEqual(removed, first)
        s.restore(first, to: a)
        s.restore(first, to: a)
        XCTAssertEqual(s.people[0].ideas.filter { $0.id == first.id }.count, 1)
        let third = s.people[0].ideas[2]
        let r = s.removeIdea(third.id, of: a)
        XCTAssertEqual(r?.1, 2)
        s.restore(third, to: a, at: r?.1 ?? 0)
        XCTAssertEqual(s.people[0].ideas[2], third)
        s.restore(Idea(title: "far"), to: a, at: 999)
        XCTAssertEqual(s.people[0].ideas.last?.title, "far")
        s.update(first, of: a, moveTo: b)
        XCTAssertNil(s.people[0].index(first.id))
        XCTAssertNotNil(s.people[1].index(first.id))
        s.again(first.id, of: b, today: today)
        XCTAssertEqual(s.people[1].ideas.count, 2)
    }

    func testFreeLimitThreePeople() {
        var s = AppState()
        for n in ["A", "B", "C"] { XCTAssertTrue(s.canAdd(hasPro: false)); s.addPerson(Person(name: n)) }
        XCTAssertFalse(s.canAdd(hasPro: false))
        XCTAssertTrue(s.canAdd(hasPro: true))
        var e = Entitlement(); e.firstOpen = Date(timeIntervalSince1970: 0)
        XCTAssertFalse(e.hasPro(at: Date(timeIntervalSince1970: 31 * 86_400)))
        XCTAssertTrue(e.hasPro(at: Date(timeIntervalSince1970: 29 * 86_400)))
    }


    func testTransferRoundTripOnlyWantedAndMerge() throws {
        var mom = Person(name: "Mom")
        var bought = Idea(title: "Scarf", added: today); bought.boughtFor = today
        mom.ideas = [Idea(title: "Mug", price: "$29", link: "https://shop.example.com/m", note: "secret", added: today), bought]
        let code = "hey 👋 " + Transfer.code(for: mom) + " thanks"
        let got = try Transfer.person(from: code, today: today)
        XCTAssertEqual(got.name, "Mom")
        XCTAssertEqual(got.ideas.map(\.title), ["Mug"])
        XCTAssertEqual(got.ideas[0].price, "$29")
        XCTAssertEqual(got.ideas[0].link, "https://shop.example.com/m")
        XCTAssertEqual(got.ideas[0].note, "")   // 备注不外传

        var s = AppState()
        var mine = Person(name: " mom "); mine.ideas = [Idea(title: "MUG", added: today)]
        s.addPerson(mine)
        var extra = got; extra.ideas.append(Idea(title: "Book", added: today))
        let r = s.importPerson(extra, hasPro: false)
        XCTAssertEqual(r?.1, 1)
        XCTAssertEqual(s.people.count, 1)
    }

    func testSizesTravelWithCodeAndDoNotOverwrite() throws {
        var mom = Person(name: "Mom"); mom.sizes = "  Shirt M · Shoe 8  "
        mom.ideas = [Idea(title: "Mug", added: today)]
        let got = try Transfer.person(from: Transfer.code(for: mom), today: today)
        XCTAssertEqual(got.sizes, "Shirt M · Shoe 8")

        var s = AppState()
        s.addPerson(Person(name: "Mom"))
        _ = s.importPerson(got, hasPro: true)
        XCTAssertEqual(s.people[0].sizes, "Shirt M · Shoe 8")
        var other = got; other.sizes = "Shirt L"
        _ = s.importPerson(other, hasPro: true)
        XCTAssertEqual(s.people[0].sizes, "Shirt M · Shoe 8")

        let old = try Transfer.person(from: "GFT1:eyJuIjoiR3JhbmRtYSIsImkiOlt7InQiOiJUZWEgc2V0IiwicCI6IiQ0MCJ9XX0", today: today)
        XCTAssertEqual(old.sizes, "")
        var long = Person(name: "X"); long.sizes = String(repeating: "s", count: 900)
        XCTAssertEqual(try Transfer.person(from: Transfer.code(for: long), today: today).sizes.count, Transfer.maxSizes)

        let data = try JSONEncoder().encode(mom)
        XCTAssertEqual(try JSONDecoder().decode(Person.self, from: data).sizes, mom.sizes)
    }

    func testTransferRejectsBadAndClampsHostile() throws {
        XCTAssertThrowsError(try Transfer.person(from: "no code here"))
        XCTAssertThrowsError(try Transfer.person(from: "GFT1:@@@"))
        XCTAssertThrowsError(try Transfer.person(from: "GFT1:"))
        let hostile = Transfer.Payload(n: String(repeating: "N", count: 500),
                                       i: (0..<120).map { Transfer.Item(t: $0 == 0 ? "  " : String(repeating: "x", count: 100), p: String(repeating: "9", count: 30), u: "javascript:alert(1)") })
        let data = try JSONEncoder().encode(hostile)
        let code = Transfer.prefix + data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        let p = try Transfer.person(from: code, today: today)
        XCTAssertEqual(p.name.count, 40)
        XCTAssertEqual(p.ideas.count, Transfer.maxIdeas - 1)
        XCTAssertTrue(p.ideas.allSatisfy { $0.title.count == 80 && $0.price.count == 20 && $0.link.isEmpty })
    }

    func testImportNewPersonBlockedAtFreeLimit() throws {
        var s = AppState()
        for n in ["A", "B", "C"] { s.addPerson(Person(name: n)) }
        XCTAssertNil(s.importPerson(Person(name: "D"), hasPro: false))
        XCTAssertNotNil(s.importPerson(Person(name: "a"), hasPro: false))  // 同名补充不占名额
    }


    func testShareDraftFromShopPage() {
        let d = ShareParse.draft(title: "Insulated Travel Mug 16 oz – Cream | Amazon.com", url: URL(string: "https://www.amazon.com/dp/B0TEST"), text: "Only $29.99 today")
        XCTAssertEqual(d.title, "Insulated Travel Mug 16 oz – Cream")
        XCTAssertEqual(d.price, "$29.99")
        XCTAssertEqual(d.link, "https://www.amazon.com/dp/B0TEST")
    }

    func testShareDraftFromChineseTextWithLink() {
        let d = ShareParse.draft(title: nil, url: nil, text: "【淘宝】真空保温杯 500ml 奶白 到手价￥1,299\nhttps://m.tb.cn/h.abc123 复制打开")
        XCTAssertEqual(d.link, "https://m.tb.cn/h.abc123")
        XCTAssertEqual(d.price, "￥1,299")
        XCTAssertTrue(d.title.contains("保温杯"), d.title)
        XCTAssertFalse(d.title.contains("http"), d.title)
        XCTAssertEqual(ShareParse.price(in: "1,980円"), "1,980円")
        XCTAssertEqual(ShareParse.price(in: "售价 129元"), "129元")
        XCTAssertNil(ShareParse.price(in: "no price"))
    }

    func testShareDraftOnlyURLUsesHost() {
        let d = ShareParse.draft(title: nil, url: URL(string: "https://www.etsy.com/listing/123"), text: nil)
        XCTAssertEqual(d.title, "etsy.com")
        XCTAssertEqual(d.price, "")
    }


    func testCSVEscapesFormulasAndQuotes() {
        XCTAssertEqual(CSVExport.cell("=HYPERLINK(1)"), "'=HYPERLINK(1)")
        XCTAssertEqual(CSVExport.cell("a,\"b\""), "\"a,\"\"b\"\"\"")
        var s = AppState(); s.addPerson(Person(name: "Mom"))
        s.addIdea(Idea(title: "Mug", added: today), to: s.people[0].id)
        let csv = CSVExport.text(s, today: today)
        XCTAssertTrue(csv.hasPrefix("\u{FEFF}Person,Idea"))
        XCTAssertTrue(csv.contains("Mom,Mug,,,,wanted,2026-11-24,"))
    }

    func testDecodesOldOrPartialData() throws {
        let json = #"{"people":[{"name":"Mom","holidays":["christmas","futureHoliday"],"ideas":[{"title":"Mug"}]}],"leadDays":999}"#
        let s = try Store.decoder.decode(AppState.self, from: Data(json.utf8))
        XCTAssertEqual(s.people[0].holidays, [.christmas])
        XCTAssertEqual(s.people[0].ideas[0].title, "Mug")
        XCTAssertEqual(s.leadDays, AppState.leadRange.upperBound)
        let again = try Store.decoder.decode(AppState.self, from: Store.encoder.encode(s))
        XCTAssertEqual(again.people, s.people)
        XCTAssertEqual(again.leadDays, s.leadDays)
    }

    func testRemindersPlanLeadDaysAndWindow() {
        var s = AppState(); s.leadDays = 14
        var p = Person(name: "Mom"); p.holidays = [.christmas]; p.birthday = MonthDay(month: 12, day: 1)
        s.addPerson(p)
        let plan = ReminderPlan.items(s, today: today)
        XCTAssertEqual(plan.map(\.fire), [Day(year: 2026, month: 12, day: 11)])
    }

    func testLocalizedKeysExist() {
        for k in ["app.name", "remind.title", "holiday.springFestival", "card.big"] {
            XCTAssertNotEqual(L.t(k), k, k)
        }
    }
}
