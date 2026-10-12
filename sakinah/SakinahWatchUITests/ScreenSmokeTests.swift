import XCTest

/// Smoke test: launch, clear permission prompts, open every screen.
/// Set TEST_RUNNER_SHOT_DIR to save a PNG per screen.
final class ScreenSmokeTests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = true
        app.launch()
    }

    func testEveryScreenOpens() {
        clearPrompts()
        XCTAssertTrue(app.staticTexts["NEXT PRAYER"].waitForExistence(timeout: 10))
        // Prayer times need a location; give it time to arrive.
        let awaiting = app.staticTexts["Awaiting location…"]
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: awaiting)
        wait(for: [gone], timeout: 20)
        shot("1-home")

        open("Qurʾan"); shot("2-quran"); back()

        open("Duʿas"); shot("2b-duas")
        app.staticTexts["Anger"].firstMatch.tap(); sleep(1)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'When angry'")).firstMatch.tap(); sleep(1)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Bukhari'")).firstMatch.waitForExistence(timeout: 5), "du'a shows its source")
        shot("2c-dua-reading"); back(); back(); back()

        open("Adhkar"); shot("2d-adhkar")
        app.staticTexts["Tasbih counter"].firstMatch.tap(); sleep(1)
        let counter = app.buttons.matching(NSPredicate(format: "label ENDSWITH ' of 33'")).firstMatch
        XCTAssertTrue(counter.waitForExistence(timeout: 5))
        counter.tap(); counter.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH '2 of'")).firstMatch.waitForExistence(timeout: 5), "tasbih counts taps")
        shot("2e-tasbih"); back(); back()

        open("Wudu"); shot("3-wudu")
        let next = app.buttons["Next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5), "Wudu Next button")
        next.tap(); shot("3b-wudu-after-next"); back()

        open("Salah"); shot("4-salah-start")
        let start = app.buttons["Start"]
        for _ in 0..<6 where !(start.exists && start.isHittable) { app.swipeUp(); sleep(1) }
        start.tap()
        let ring = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Rakah 1 of'")).firstMatch
        XCTAssertTrue(ring.waitForExistence(timeout: 5), "manual tracker shows rakah 1")
        ring.tap(); ring.tap()   // two sajdahs complete rakah 1
        let rakah2 = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Rakah 2 of'")).firstMatch
        XCTAssertTrue(rakah2.waitForExistence(timeout: 5), "two taps complete a rakah")
        shot("4b-salah-manual")
        app.buttons["Undo"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Rakah 1 of'")).firstMatch.waitForExistence(timeout: 5), "undo")
        app.buttons["Finish"].tap()
        XCTAssertTrue(app.staticTexts["Review"].waitForExistence(timeout: 5), "review after finishing")
        shot("4c-salah-review")
        back(); back()

        open("Mosques"); sleep(6); shot("5-mosques")
        let firstMosque = app.buttons.matching(NSPredicate(format: "label CONTAINS ' m'")).firstMatch
        if firstMosque.waitForExistence(timeout: 10) {
            firstMosque.tap(); sleep(6)
            XCTAssertTrue(app.staticTexts["Walking"].waitForExistence(timeout: 5), "mosque detail shows walking time")
            shot("5b-mosque-detail")
            back()
        }
        back()

        open("Qibla"); sleep(2)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Qibla '")).firstMatch.waitForExistence(timeout: 10),
                      "qibla bearing shown")
        shot("5c-qibla"); back()

        // Timetable shows sunrise; changing the method in Settings moves Fajr.
        open("Timetable"); shot("6-timetable")
        XCTAssertTrue(app.staticTexts["Sunrise"].waitForExistence(timeout: 5))
        let fajrBefore = fajrLabel()
        back()

        open("Settings"); shot("7-settings")
        app.staticTexts["Method"].firstMatch.tap()
        sleep(2); shot("7a-method-list")
        let egyptian = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Egyptian'")).firstMatch
        for _ in 0..<8 where !(egyptian.exists && egyptian.isHittable) { app.swipeUp(); sleep(1) }
        egyptian.tap()
        sleep(1); shot("7b-settings-egyptian"); back()

        open("Timetable")
        XCTAssertNotEqual(fajrLabel(), fajrBefore, "changing method recalculates Fajr")
        back()

        open("History"); shot("8-history")
        let missed = app.buttons["Fajr missed"].firstMatch
        missed.tap(); sleep(1)
        XCTAssertTrue(missed.isSelected, "Fajr marked missed")
        let owed = app.descendants(matching: .any)["qada-owed"]
        for _ in 0..<12 where !(owed.exists && owed.isHittable) { nudgeUp(); sleep(1) }
        shot("8b-history-qada")
        XCTAssertTrue(owed.label.contains("1") || "\(owed.value ?? "")".contains("1"), "missing a prayer adds one qada: \(owed.label)")
        for _ in 0..<6 { app.swipeDown() }
        missed.tap()
        back()

        XCTAssertEqual(app.state, .runningForeground, "app still running")
    }

    private func open(_ tile: String) {
        let b = app.buttons.containing(.staticText, identifier: tile).firstMatch
        // Home's tile grid is lazy: scroll from the top in small steps until
        // the tile exists and sits clear of the title bar.
        let h = app.frame.height
        for _ in 0..<4 { app.swipeDown(velocity: .fast) }
        for _ in 0..<16 {
            if b.exists, b.frame.midY > h * 0.25, b.frame.midY < h * 0.9 { break }
            if b.exists, b.frame.midY <= h * 0.25 {
                app.swipeDown(velocity: .slow)
            } else {
                app.swipeUp(velocity: .slow)
            }
            sleep(1)
        }
        XCTAssertTrue(b.exists, "tile \(tile)")
        b.tap()
        sleep(2)
    }

    /// A short drag: scrolls about a third of the screen.
    private func nudgeUp() {
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
        from.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)))
    }

    private func back() {
        let b = app.navigationBars.buttons.firstMatch
        if b.waitForExistence(timeout: 3) { b.tap() } else { app.buttons["BackButton"].tap() }
        sleep(1)
    }

    private func clearPrompts() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.Carousel")
        for _ in 0..<4 {
            sleep(3)
            for label in ["Allow While Using App", "Allow Once", "Allow"] {
                let b = springboard.buttons[label]
                if b.exists { b.tap() }
                let a = app.buttons[label]
                if a.exists { a.tap() }
            }
            // First launch asks for the calculation method.
            if app.staticTexts["Prayer times"].exists || app.buttons["Continue"].exists {
                shot("0-method-prompt")
                let cont = app.buttons["Continue"]
                for _ in 0..<8 where !(cont.exists && cont.isHittable) { app.swipeUp() }
                cont.tap()
            }
        }
    }

    private func fajrLabel() -> String {
        let fajr = app.staticTexts.matching(identifier: "time-fajr").firstMatch
        if fajr.waitForExistence(timeout: 3) { return fajr.label }
        return app.otherElements["row-fajr"].label
    }

    private func shot(_ name: String) {
        let png = app.screenshot().pngRepresentation
        add(XCTAttachment(data: png, uniformTypeIdentifier: "public.png"))
        if let dir = ProcessInfo.processInfo.environment["SHOT_DIR"] {
            try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }
}
