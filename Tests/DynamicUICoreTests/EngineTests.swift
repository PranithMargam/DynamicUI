import XCTest
@testable import DynamicUICore

final class EngineTests: XCTestCase {
    func node(_ type: String = "banner", required: Bool = true, version: Int = 1, props: String = "{\"title\":\"Hello\",\"message\":\"World\"}") throws -> Node {
        try JSONDecoder().decode(Node.self, from: Data("{\"id\":\"a\",\"type\":\"\(type)\",\"version\":\(version),\"required\":\(required),\"props\":\(props)}".utf8))
    }
    func testAllFixturesAndSource() async throws {
        for scenario in Scenario.allCases {
            let screen = try Screen.decode(await FixtureSource().fetch(scenario))
            XCTAssertEqual(screen.schemaVersion, 1)
            XCTAssertFalse(screen.revision.isEmpty)
            XCTAssertEqual(scenario.id, scenario.rawValue)
            XCTAssertFalse(scenario.title.isEmpty)
            for n in screen.components {
                switch n.type {
                case "hero": XCTAssertEqual(try n.decode(HeroProps.self).image, "product")
                case "product": XCTAssertFalse(try n.decode(ProductProps.self).price.isEmpty)
                case "variants": XCTAssertFalse(try n.decode(VariantProps.self).sizes.isEmpty)
                case "banner": XCTAssertFalse(try n.decode(BannerProps.self).title.isEmpty)
                case "details": XCTAssertFalse(try n.decode(DetailsProps.self).body.isEmpty)
                case "purchase": XCTAssertFalse(try n.decode(PurchaseProps.self).action.isEmpty)
                default: XCTFail("Unexpected component")
                }
            }
        }
    }
    func testTypedRegistryAndDuplicateProtection() throws {
        var registry = Registry<String>()
        try registry.register("banner", props: BannerProps.self) { $0.title }
        XCTAssertEqual(try registry.resolve(node()), "Hello")
        XCTAssertThrowsError(try registry.register("banner", props: BannerProps.self) { $0.title })
        XCTAssertThrowsError(try registry.resolve(node(props: "{}")))
        XCTAssertNil(try registry.resolve(node("future", required: false)))
        XCTAssertThrowsError(try registry.resolve(node("future")))
        XCTAssertThrowsError(try registry.resolve(node(version: 2)))
        try registry.register("banner", version: 2, props: BannerProps.self) { $0.message }
        XCTAssertEqual(try registry.resolve(node(version: 2)), "World")
    }
    func testScreenValidation() throws {
        XCTAssertThrowsError(try Screen.decode(Data(repeating: 0, count: 262_145)))
        XCTAssertThrowsError(try Screen.decode(Data("invalid".utf8)))
        let valid = try JSONSerialization.jsonObject(with: Scenario.standard.data()) as! [String: Any]
        for (key, value) in [("schemaVersion", 2 as Any), ("revision", "" as Any), ("components", [] as Any)] {
            var changed = valid; changed[key] = value
            XCTAssertThrowsError(try Screen.decode(JSONSerialization.data(withJSONObject: changed)))
        }
        var changed = valid
        var nodes = valid["components"] as! [[String: Any]]
        nodes.append(nodes[0]); changed["components"] = nodes
        XCTAssertThrowsError(try Screen.decode(JSONSerialization.data(withJSONObject: changed)))
        nodes = valid["components"] as! [[String: Any]]
        nodes[0]["id"] = ""; changed["components"] = nodes
        XCTAssertThrowsError(try Screen.decode(JSONSerialization.data(withJSONObject: changed)))
        nodes[0]["id"] = String(repeating: "a", count: 101); changed["components"] = nodes
        XCTAssertThrowsError(try Screen.decode(JSONSerialization.data(withJSONObject: changed)))
        changed["components"] = Array(repeating: nodes[0], count: 51)
        XCTAssertThrowsError(try Screen.decode(JSONSerialization.data(withJSONObject: changed)))
    }
    func testJSONRoundTrip() throws {
        let data = Data("{\"string\":\"s\",\"number\":1.2,\"bool\":true,\"array\":[null],\"object\":{}}".utf8)
        let value = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(value, try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(value)))
        XCTAssertThrowsError(try JSONDecoder().decode(JSONValue.self, from: Data("!".utf8)))
    }
    func testActions() throws {
        let registry = try ActionRegistry.demo()
        XCTAssertEqual(try registry.perform("addToBag", size: "M"), .added("M"))
        XCTAssertEqual(try registry.perform("notifyMe", size: nil), .notificationRequested)
        XCTAssertThrowsError(try registry.perform("addToBag", size: nil))
        XCTAssertThrowsError(try registry.perform("addToBag", size: ""))
        XCTAssertThrowsError(try registry.perform("openURL", size: nil))
        var duplicate = ActionRegistry()
        try duplicate.register("a") { _ in .notificationRequested }
        XCTAssertThrowsError(try duplicate.register("a") { _ in .notificationRequested })
    }
}
