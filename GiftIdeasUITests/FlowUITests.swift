import XCTest

final class FlowUITests: XCTestCase {
    private let app = XCUIApplication()
    private let grandmaCode = "GFT1:eyJuIjoiR3JhbmRtYSIsImkiOlt7InQiOiJUZWEgc2V0IiwicCI6IiQ0MCJ9XX0"

    override func setUp() {
        continueAfterFailure = false
        executionTimeAllowance = 900
    }

    func testFirstRunAddPersonThenQuickIdeaInTwoTaps() {
        launch()
        tap("home.addFirst")
        let name = wait("personEditor.name")
        name.tap()
        name.typeText("Mom\n")
        XCTAssertEqual(wait("person.title").label, "Mom")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        tap("person.add.0")
        let field = wait("quick.field")
        if !(field.value(forKey: "hasKeyboardFocus") as? Bool ?? false) { field.tap() }
        field.typeText("Travel mug\n")
        XCTAssertTrue(wait("app.notice").label.contains("Mom"))
        XCTAssertTrue(waitLabel("person.0", contains: "1 saved"), element("person.0").label)
    }

    func testShareSheetSavesWithOneTap() {
        launch(["-demo", "-share-demo"])
        XCTAssertEqual(wait("share.title").value as? String, "Insulated Travel Mug 16 oz – Cream")
        XCTAssertEqual(element("share.price").value as? String, "$29.99")
        tap("share.person.Mom")
        XCTAssertTrue(wait("share.done").exists)
        let close = app.buttons.matching(identifier: "share.cancel").firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 8))
        close.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        tap("person.0")
        XCTAssertEqual(wait("want.0.title").label, "Insulated Travel Mug 16 oz – Cream")
    }

    func testMarkBoughtAndBackAndGivenYears() {
        launch(["-demo", "-open-first"])
        XCTAssertEqual(wait("person.title").label, "Mom")
        XCTAssertTrue(wait("person.sizes").label.contains("Shoe 7.5"))
        XCTAssertTrue(wait("person.next").label.contains("12"))
        let first = wait("want.0.title").label
        tap("want.0.toggle")
        XCTAssertTrue(wait("bought.1.title").exists)
        XCTAssertNotEqual(element("want.0.title").label, first)
        tap("bought.0.toggle")
        XCTAssertTrue(waitLabel("want.0.title", contains: first), element("want.0.title").label)
        XCTAssertTrue(wait("given.2025", scrollIn: app).exists)
        XCTAssertTrue(wait("given.2024", scrollIn: app).exists)
    }

    func testDeleteIdeaAndUndo() {
        launch(["-demo", "-open-first"])
        let first = wait("want.0.title").label
        element("want.0.title").swipeLeft()
        app.buttons["Delete"].firstMatch.tap()
        XCTAssertTrue(wait("app.undo").exists)
        XCTAssertNotEqual(element("want.0.title").label, first)
        tap("app.undo")
        XCTAssertTrue(waitLabel("want.0.title", contains: first), element("want.0.title").label)
    }

    func testAddIdeaWithEditor() {
        launch(["-demo", "-open-first"])
        tap("person.addIdea")
        let title = wait("idea.title")
        title.tap()
        title.typeText("Garden gloves")
        let price = element("idea.price")
        price.tap()
        price.typeText("$18")
        tap("idea.done")
        XCTAssertEqual(wait("want.0.title").label, "Garden gloves")
    }

    func testFreeLimitKeepsPeopleAndShowsPaywall() {
        launch(["-demo", "-expired"])
        XCTAssertTrue(wait("person.3").exists)
        tap("home.addPerson")
        XCTAssertTrue(wait("paywall.status").exists)
    }

    func testImportFamilyCode() {
        launch(["-demo", "-paid"])
        tap("home.addPerson")
        let field = wait("personEditor.code", scrollIn: app)
        field.tap()
        field.typeText("Here you go " + grandmaCode)
        tap("personEditor.import")
        XCTAssertEqual(wait("person.title", timeout: 10).label, "Grandma")
        XCTAssertEqual(wait("want.0.title").label, "Tea set")
    }

    func testBadCodeShowsNotice() {
        launch(["-demo", "-paid"])
        tap("home.addPerson")
        let field = wait("personEditor.code", scrollIn: app)
        field.tap()
        field.typeText("GFT1:@@@")
        tap("personEditor.import")
        XCTAssertTrue(wait("app.notice").exists)
        XCTAssertTrue(wait("personEditor.name").exists)
    }

    func testSettingsLeadNotificationsExportAndCard() {
        launch(["-demo", "-notifications-denied"])
        tap("home.settings")
        let settingsScroll = app.scrollViews.firstMatch
        XCTAssertTrue(wait("settings.lead", scrollIn: settingsScroll).label.contains("14"))
        XCTAssertTrue(wait("settings.denied", scrollIn: settingsScroll).exists)
        XCTAssertTrue(wait("settings.export", scrollIn: settingsScroll).exists)
        tap("settings.shareCard", scrollIn: settingsScroll)
        XCTAssertTrue(wait("share.card", timeout: 15).exists)
        XCTAssertTrue(wait("share.image", timeout: 15).exists)
    }

    func testStoreScreenshots() {
        for language in ["en", "zh-Hans", "zh-Hant"] {
            launch(["-demo"], language: language)
            XCTAssertTrue(wait("person.0").exists)
            shot("store-\(language)-01-home")

            launch(["-demo", "-share-demo"], language: language)
            XCTAssertTrue(wait("share.title").exists)
            Thread.sleep(forTimeInterval: 0.8)
            shot("store-\(language)-02-share")

            launch(["-demo", "-open-first"], language: language)
            XCTAssertTrue(wait("want.0.title").exists)
            shot("store-\(language)-03-person")
            tap("person.edit")
            XCTAssertTrue(wait("personEditor.hasBirthday").exists)
            Thread.sleep(forTimeInterval: 0.8)
            shot("store-\(language)-04-dates")
            tap("personEditor.cancel")
            tap("person.shareCard", scrollIn: app)
            XCTAssertTrue(wait("share.image", timeout: 15).exists)
            shot("store-\(language)-05-card")
        }
        launch(["-demo", "-paywall"])
        XCTAssertTrue(wait("paywall.status").exists)
        shot("paid-01-paywall")
    }


    private func launch(_ flags: [String] = [], language: String = "en") {
        if app.state != .notRunning { app.terminate() }
        let locale = language == "zh-Hans" ? "zh_CN" : language == "zh-Hant" ? "zh_TW" : "en_US"
        app.launchArguments = ["-ui-testing", "-reset", "-today", "2026-11-24", "-AppleLanguages", "(\(language))", "-AppleLocale", locale] + flags
        app.launch()
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func waitLabel(_ id: String, contains text: String, timeout: TimeInterval = 8) -> Bool {
        let item = element(id)
        let ok = NSPredicate { _, _ in item.exists && item.label.contains(text) }
        return XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: ok, object: nil)], timeout: timeout) == .completed
    }

    @discardableResult
    private func wait(_ id: String, timeout: TimeInterval = 8, scrollIn scrollView: XCUIElement? = nil, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let item = element(id)
        _ = item.waitForExistence(timeout: scrollView == nil ? timeout : min(timeout, 3))
        if let scrollView {
            for _ in 0..<6 {
                if item.exists && item.isHittable { break }
                scrollView.swipeUp()
                Thread.sleep(forTimeInterval: 1.2)
            }
        }
        XCTAssertTrue(item.exists, id, file: file, line: line)
        return item
    }

    private func tap(_ id: String, scrollIn scrollView: XCUIElement? = nil, file: StaticString = #filePath, line: UInt = #line) {
        let item = wait(id, scrollIn: scrollView, file: file, line: line)
        let ready = NSPredicate { _, _ in item.exists && item.isHittable && item.isEnabled }
        if XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: ready, object: nil)], timeout: 10) == .completed {
            item.tap()
            return
        }
        XCTAssertTrue(item.exists && item.isEnabled, id, file: file, line: line)
        item.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
