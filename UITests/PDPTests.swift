import XCTest
final class PDPTests: XCTestCase {
    func testPullToRefreshKeepsProductAvailable() {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.buttons["purchase"].waitForExistence(timeout: 10))
        let scroll = app.scrollViews.firstMatch
        for _ in 0..<2 {
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
                .press(forDuration: 0.1, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)))
            XCTAssertTrue(app.buttons["purchase"].waitForExistence(timeout: 5))
            XCTAssertFalse(app.staticTexts["Loading product"].exists)
        }
        app.buttons["purchase"].tap()
        XCTAssertTrue(app.alerts["FORMA Demo"].waitForExistence(timeout: 3))
    }
    func testPurchaseAndDetails() {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.buttons["purchase"].waitForExistence(timeout: 10))
        app.buttons["purchase"].tap()
        XCTAssertTrue(app.alerts["FORMA Demo"].exists)
        app.alerts.buttons["OK"].tap()
        app.swipeUp()
        app.buttons["Size M"].tap()
        app.buttons["purchase"].tap()
        XCTAssertTrue(app.alerts.staticTexts["Demo: size M added to your bag. No purchase was made."].exists)
        app.alerts.buttons["OK"].tap()
        app.buttons["Materials & care"].tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()
    }
    func testSoldOutComposition() {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.buttons["purchase"].waitForExistence(timeout: 10))
        // iOS 17 Menu exposes an AX scroll action that fails despite a visible toolbar item.
        app.buttons["Demo scenarios"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons["Sold out"].tap()
        XCTAssertTrue(app.buttons["Notify me"].waitForExistence(timeout: 5))
        app.buttons["purchase"].tap()
        XCTAssertTrue(app.alerts["FORMA Demo"].exists)
    }
}
