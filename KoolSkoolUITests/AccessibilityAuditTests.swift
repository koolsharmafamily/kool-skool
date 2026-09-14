import XCTest

/// Walks the main screens, runs Xcode's accessibility audit on each, and keeps a
/// screenshot of every one — at the default text size and at XXL.
///
/// The project is written on Windows with no simulator, so these screenshots
/// are how anyone working on it sees a screen at all. Each screen's audit
/// findings are saved as text beside its screenshot.
final class AccessibilityAuditTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Walks

    @MainActor
    func testMainScreensAtDefaultSize() throws {
        try walkMainScreens(textSize: nil, tag: "default")
    }

    @MainActor
    func testMainScreensAtXXL() throws {
        try walkMainScreens(textSize: "UICTContentSizeCategoryXXL", tag: "xxl")
    }

    @MainActor
    func testOnboardingAtDefaultSize() throws {
        try walkOnboarding(textSize: nil, tag: "default")
    }

    @MainActor
    func testOnboardingAtXXL() throws {
        try walkOnboarding(textSize: "UICTContentSizeCategoryXXL", tag: "xxl")
    }

    @MainActor
    private func walkMainScreens(textSize: String?, tag: String) throws {
        let app = launch(textSize: textSize)

        XCTAssertTrue(button(app, containing: "Just start").waitForExistence(timeout: 30), "Today never appeared")
        try record(app, "today", tag)

        // Settings, one of its groups, and export.
        button(app, containing: "Settings").tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10), "Settings never appeared")
        try record(app, "settings", tag)

        button(app, containing: "Focus and time").tap()
        XCTAssertTrue(app.navigationBars["Focus and time"].waitForExistence(timeout: 10), "Focus and time never appeared")
        try record(app, "settings-focus", tag)
        goBack(app)

        let data = button(app, containing: "Your data")
        scrollTo(data, in: app)
        data.tap()
        XCTAssertTrue(app.navigationBars["Your data"].waitForExistence(timeout: 10), "Export never appeared")
        try record(app, "settings-data", tag)
        goBack(app)
        goBack(app)

        // Insights, with three weeks of seeded history.
        button(app, containing: "Insights").tap()
        XCTAssertTrue(app.navigationBars["Insights"].waitForExistence(timeout: 10), "Insights never appeared")
        try record(app, "insights", tag)
        goBack(app)

        // A session, and the screen after one.
        let justStart = button(app, containing: "Just start")
        XCTAssertTrue(justStart.waitForExistence(timeout: 10))
        justStart.tap()
        let endEarly = button(app, containing: "End early")
        XCTAssertTrue(endEarly.waitForExistence(timeout: 10), "The session screen never appeared")
        try record(app, "session", tag)

        // Past the ten-second floor, so the session is kept and the completion
        // screen appears instead of the session being discarded as a mis-tap.
        sleep(11)
        endEarly.tap()
        let endNow = app.buttons["End now"]
        XCTAssertTrue(endNow.waitForExistence(timeout: 10), "The end-early confirmation never appeared")
        endNow.tap()
        let done = button(app, containing: "Done")
        XCTAssertTrue(done.waitForExistence(timeout: 10), "The completion screen never appeared")
        try record(app, "session-complete", tag)
        done.tap()

        // The stillness layer: the library, then a paced breath practice.
        let stillness = button(app, containing: "Stillness")
        XCTAssertTrue(stillness.waitForExistence(timeout: 10))
        scrollTo(stillness, in: app)
        stillness.tap()
        XCTAssertTrue(app.navigationBars["Stillness"].waitForExistence(timeout: 10), "The practice library never appeared")
        try record(app, "stillness-library", tag)

        button(app, containing: "Box Breathing").tap()
        let oneMinute = button(app, containing: "Start Box Breathing, 1 min")
        XCTAssertTrue(oneMinute.waitForExistence(timeout: 10), "The practice lengths never appeared")
        oneMinute.tap()
        XCTAssertTrue(button(app, containing: "End").waitForExistence(timeout: 10), "The sit never started")
        try record(app, "sit", tag)
    }

    @MainActor
    private func walkOnboarding(textSize: String?, tag: String) throws {
        let app = launch(textSize: textSize, onboarding: true)

        XCTAssertTrue(app.staticTexts["What do you want to focus on?"].waitForExistence(timeout: 30), "Onboarding never appeared")
        try record(app, "onboarding-focus", tag)
        button(app, containing: "Skip for now").tap()

        XCTAssertTrue(app.staticTexts["When do you work best?"].waitForExistence(timeout: 10))
        try record(app, "onboarding-rhythm", tag)
        button(app, containing: "Skip for now").tap()

        // Only shown while the permission question is unanswered, which it is on
        // a fresh simulator — but that is the system's call, not the test's.
        if app.staticTexts["Want a nudge when time's up?"].waitForExistence(timeout: 10) {
            try record(app, "onboarding-notifications", tag)
            button(app, containing: "Not now").tap()
        }

        XCTAssertTrue(app.staticTexts["Five minutes. That's it."].waitForExistence(timeout: 10))
        try record(app, "onboarding-start", tag)
    }

    // MARK: Helpers

    @MainActor
    private func launch(textSize: String?, onboarding: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-KSUITesting"]
        if onboarding {
            app.launchArguments += ["-KSUITestingOnboarding"]
        }
        if let textSize {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", textSize]
        }
        app.launch()
        return app
    }

    @MainActor
    private func button(_ app: XCUIApplication, containing text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
    }

    @MainActor
    private func goBack(_ app: XCUIApplication) {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    @MainActor
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        var attempts = 0
        while !element.isHittable && attempts < 8 {
            app.swipeUp()
            attempts += 1
        }
    }

    /// A screenshot, plus every audit finding on the screen as text.
    ///
    /// Findings are recorded, not failed on, for this first pass: the point is
    /// to see what the audit reports before deciding what counts as a failure.
    @MainActor
    private func record(_ app: XCUIApplication, _ screen: String, _ tag: String) throws {
        let name = "\(tag)-\(screen)"

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)

        var findings: [String] = []
        try app.performAccessibilityAudit(for: .all) { issue in
            let element = issue.element.map { "type \($0.elementType.rawValue) '\($0.label)'" } ?? "no element"
            findings.append("\(Self.name(of: issue.auditType)): \(issue.compactDescription) — \(element)")
            return true
        }

        // Also written to the test log, so the findings can be read straight
        // from CI without downloading anything.
        print("[audit] \(name): \(findings.count) finding\(findings.count == 1 ? "" : "s")")
        for finding in findings {
            print("[audit] \(name): \(finding)")
        }

        let report = XCTAttachment(string: findings.isEmpty ? "No findings." : findings.joined(separator: "\n"))
        report.name = "\(name)-audit"
        report.lifetime = .keepAlways
        add(report)
    }

    private static func name(of type: XCUIAccessibilityAuditType) -> String {
        switch type {
        case .contrast: "contrast"
        case .elementDetection: "element-detection"
        case .hitRegion: "hit-region"
        case .sufficientElementDescription: "description"
        case .dynamicType: "dynamic-type"
        case .textClipped: "text-clipped"
        case .trait: "trait"
        default: "other-\(type.rawValue)"
        }
    }
}
