import XCTest
import SwiftUI
import DynamicUICore
@testable import Forma

@MainActor final class ProductModelTests: XCTestCase {
    func testRegistryRegistersOnceAcrossReloadsAndScenarioChanges() async {
        var registrations = 0
        var builds = 0
        // Use a purchase-only contract so all required nodes are registered.
        let source = PurchaseOnlySource()
        let testModel = ProductModel(source: source, registryFactory: { _ in
            registrations += 1
            var registry = Registry<RenderedSection>()
            try registry.register("purchase", props: PurchaseProps.self) { props in
                builds += 1
                return RenderedSection(body: AnyView(EmptyView()), purchase: props)
            }
            return registry
        })
        XCTAssertEqual(registrations, 0)
        for scenario in Scenario.allCases {
            testModel.scenario = scenario
            await testModel.load()
            XCTAssertNil(testModel.error)
        }
        XCTAssertEqual(registrations, 1)
        XCTAssertEqual(builds, 3)
    }

    func testRegistrySetupFailureIsCachedOnRetry() async {
        var registrations = 0
        let model = ProductModel(registryFactory: { _ in
            registrations += 1
            throw ContractError.duplicateRegistration
        })
        await model.load()
        await model.load()
        XCTAssertEqual(registrations, 1)
        XCTAssertNotNil(model.error)
        XCTAssertFalse(model.loading)
    }
    func testCancelledRefreshRetainsProductAndFinishesLoading() async throws {
        let source = ControlledSource()
        let model = ProductModel(source: source)
        let initial = Task { await model.load() }
        await source.waitForRequest(0)
        await source.complete(0, with: .success(try Scenario.standard.data()))
        await initial.value
        model.selectedSize = "M"
        let originalIDs = model.sections.map(\.id)

        let refresh = Task { await model.load() }
        await source.waitForRequest(1)
        XCTAssertTrue(model.loading)
        XCTAssertEqual(model.sections.map(\.id), originalIDs)
        refresh.cancel()
        // A source that ignores cancellation must not strand the loading state either.
        await source.complete(1, with: .success(try Scenario.sale.data()))
        await refresh.value

        XCTAssertFalse(model.loading)
        XCTAssertNil(model.error)
        XCTAssertEqual(model.sections.map(\.id), originalIDs)
        XCTAssertEqual(model.selectedSize, "M")
        XCTAssertNotNil(model.purchase)
    }

    func testCancellationErrorFinishesLoadingWithoutFailureMessage() async {
        let source = ControlledSource()
        let model = ProductModel(source: source)
        let request = Task { await model.load() }
        await source.waitForRequest(0)
        request.cancel()
        await source.complete(0, with: .failure(CancellationError()))
        await request.value
        XCTAssertFalse(model.loading)
        XCTAssertNil(model.error)
    }

    func testStaleRequestCannotStopNewerLoadingOrReplaceItsProduct() async throws {
        let source = ControlledSource()
        let model = ProductModel(source: source)
        let first = Task { await model.load() }
        await source.waitForRequest(0)
        model.scenario = .soldOut
        let second = Task { await model.load() }
        await source.waitForRequest(1)
        await source.complete(0, with: .success(try Scenario.standard.data()))
        await first.value
        XCTAssertTrue(model.loading)
        XCTAssertTrue(model.sections.isEmpty)
        await source.complete(1, with: .success(try Scenario.soldOut.data()))
        await second.value
        XCTAssertFalse(model.loading)
        XCTAssertEqual(model.purchase?.action, "notifyMe")
    }

    func testRepeatedReloadsFinishWithProduct() async {
        let model = ProductModel()
        for _ in 0..<3 {
            await model.load()
            XCTAssertFalse(model.loading)
            XCTAssertFalse(model.sections.isEmpty)
            XCTAssertNotNil(model.purchase)
        }
    }
    func testAllCompositionsAndActions() async {
        let model = ProductModel()
        model.buy()
        XCTAssertNil(model.message)
        for scenario in Scenario.allCases {
            model.scenario = scenario
            await model.load()
            XCTAssertNil(model.error)
            XCTAssertFalse(model.loading)
            XCTAssertFalse(model.sections.isEmpty)
            XCTAssertNotNil(model.purchase)
            model.buy()
            XCTAssertNotNil(model.message)
            model.selectedSize = "M"
            model.buy()
            XCTAssertTrue(model.message?.contains("Demo:") == true)
        }
    }
    func testSourceFailure() async {
        struct Broken: ScreenSource { func fetch(_ scenario: Scenario) async throws -> Data { throw ContractError.invalidScreen } }
        let model = ProductModel(source: Broken())
        await model.load()
        XCTAssertNotNil(model.error)
        XCTAssertNil(model.purchase)
        XCTAssertTrue(model.sections.isEmpty)
        XCTAssertFalse(model.loading)
    }
    func testUnknownRequiredComponentFailsScreen() async {
        struct Unknown: ScreenSource {
            func fetch(_ scenario: Scenario) async throws -> Data {
                Data("{\"schemaVersion\":1,\"revision\":\"x\",\"components\":[{\"id\":\"x\",\"type\":\"future\",\"version\":1,\"required\":true,\"props\":{}}]}".utf8)
            }
        }
        let model = ProductModel(source: Unknown())
        await model.load()
        XCTAssertNotNil(model.error)
    }
}

private struct PurchaseOnlySource: ScreenSource {
    func fetch(_ scenario: Scenario) async throws -> Data {
        Data("{\"schemaVersion\":1,\"revision\":\"test\",\"components\":[{\"id\":\"purchase\",\"type\":\"purchase\",\"version\":1,\"required\":true,\"props\":{\"title\":\"Add to bag\",\"action\":\"addToBag\"}}]}".utf8)
    }
}

private actor ControlledSource: ScreenSource {
    private var nextID = 0
    private var pending: [Int: CheckedContinuation<Data, Error>] = [:]
    func fetch(_ scenario: Scenario) async throws -> Data {
        let id = nextID
        nextID += 1
        return try await withCheckedThrowingContinuation { pending[id] = $0 }
    }
    func waitForRequest(_ id: Int) async {
        while pending[id] == nil { await Task.yield() }
    }
    func complete(_ id: Int, with result: Result<Data, Error>) {
        pending.removeValue(forKey: id)?.resume(with: result)
    }
}
