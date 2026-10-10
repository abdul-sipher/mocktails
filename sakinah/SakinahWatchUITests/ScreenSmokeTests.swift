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

        open("Ayah"); shot("2-ayah"); back()

        open("Wudu"); shot("3-wudu")
        let next = app.buttons["Next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5), "Wudu Next button")
        next.tap(); shot("3b-wudu-after-next"); back()

        open("Salah"); shot("4-salah-start")
        app.buttons["Start"].tap()
        XCTAssertTrue(app.staticTexts["Rakah 1 / 4"].waitForExistence(timeout: 5))
        app.buttons["Add"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Rakah 2 / 4"].waitForExistence(timeout: 5), "+ rakah")
        app.buttons["Remove"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Rakah 1 / 4"].waitForExistence(timeout: 5), "− rakah")
        shot("4b-salah-live"); back(); back()

        open("Mosques"); sleep(5); shot("5-mosques"); back()

        XCTAssertEqual(app.state, .runningForeground, "app still running")
    }

    private func open(_ tile: String) {
        let b = app.buttons.containing(.staticText, identifier: tile).firstMatch
        // Home's tile grid is lazy: scroll from the top until the tile exists
        // and sits clear of the title bar.
        let h = app.frame.height
        for _ in 0..<4 { app.swipeDown() }
        for _ in 0..<8 {
            if b.exists, b.frame.midY > h * 0.3, b.frame.midY < h * 0.85 { break }
            if b.exists, b.frame.midY <= h * 0.3 { app.swipeDown() } else { app.swipeUp() }
            sleep(1)
        }
        XCTAssertTrue(b.exists, "tile \(tile)")
        b.tap()
        sleep(2)
    }

    private func back() {
        let b = app.navigationBars.buttons.firstMatch
        if b.waitForExistence(timeout: 3) { b.tap() } else { app.buttons["BackButton"].tap() }
        sleep(1)
    }

    private func clearPrompts() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.Carousel")
        for pass in 0..<4 {
            sleep(3)
            for label in ["Allow While Using App", "Allow Once", "Allow"] {
                let b = springboard.buttons[label]
                if b.exists { b.tap() }
                let a = app.buttons[label]
                if a.exists { a.tap() }
            }
            // HealthKit sheet is a system overlay outside the app's element
            // tree: tap its X by position. The app continues without HR.
            if pass == 0 {
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.16, dy: 0.15)).tap()
            }
        }
    }

    private func shot(_ name: String) {
        let png = app.screenshot().pngRepresentation
        add(XCTAttachment(data: png, uniformTypeIdentifier: "public.png"))
        if let dir = ProcessInfo.processInfo.environment["SHOT_DIR"] {
            try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }
}
