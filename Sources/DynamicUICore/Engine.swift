import Foundation

public enum ContractError: Error, Equatable {
    case invalidScreen, duplicateRegistration, unsupportedComponent(String), invalidProps, unsupportedAction
}

public struct Node: Codable, Identifiable, Equatable {
    public let id: String
    public let type: String
    public let version: Int
    public let required: Bool
    public let props: [String: JSONValue]
    public func decode<P: Decodable>(_ type: P.Type) throws -> P {
        try JSONDecoder().decode(type, from: JSONEncoder().encode(props))
    }
}

public enum JSONValue: Codable, Equatable {
    case string(String), number(Double), bool(Bool), array([JSONValue]), object([String: JSONValue]), null
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }
}

public struct Screen: Codable, Equatable {
    public let schemaVersion: Int
    public let revision: String
    public let components: [Node]
    public static func decode(_ data: Data) throws -> Screen {
        guard data.count <= 262_144 else { throw ContractError.invalidScreen }
        let screen = try JSONDecoder().decode(Screen.self, from: data)
        guard screen.schemaVersion == 1, !screen.revision.isEmpty,
              !screen.components.isEmpty, screen.components.count <= 50,
              Set(screen.components.map(\.id)).count == screen.components.count,
              screen.components.allSatisfy({ !$0.id.isEmpty && $0.id.count <= 100 })
        else { throw ContractError.invalidScreen }
        return screen
    }
}

/// One registration owns both typed decoding and construction; the engine has no component switch.
public struct Registry<Output> {
    private var factories: [String: (Node) throws -> Output] = [:]
    public init() {}
    public mutating func register<P: Decodable>(_ type: String, version: Int = 1, props: P.Type,
                                                build: @escaping (P) throws -> Output) throws {
        let key = "\(type):\(version)"
        guard factories[key] == nil else { throw ContractError.duplicateRegistration }
        factories[key] = { try build($0.decode(P.self)) }
    }
    public func resolve(_ node: Node) throws -> Output? {
        guard let factory = factories["\(node.type):\(node.version)"] else {
            if node.required { throw ContractError.unsupportedComponent(node.type) }
            return nil
        }
        // Known malformed components fail closed, even when optional.
        return try factory(node)
    }
}

public struct HeroProps: Codable { public let image: String; public let label: String }
public struct ProductProps: Codable { public let name: String; public let subtitle: String; public let price: String; public let originalPrice: String? }
public struct BannerProps: Codable { public let title: String; public let message: String }
public struct VariantProps: Codable { public let sizes: [String]; public let color: String }
public struct DetailsProps: Codable { public let title: String; public let body: String }
public struct PurchaseProps: Codable { public let title: String; public let action: String }

public enum Scenario: String, CaseIterable, Identifiable {
    case standard, sale, soldOut
    public var id: String { rawValue }
    public var title: String { self == .soldOut ? "Sold out" : rawValue.capitalized }
    public func data() throws -> Data {
        guard let url = Bundle.module.url(forResource: rawValue, withExtension: "json") else { throw ContractError.invalidScreen }
        return try Data(contentsOf: url)
    }
}

public protocol ScreenSource { func fetch(_ scenario: Scenario) async throws -> Data }
public struct FixtureSource: ScreenSource {
    public init() {}
    public func fetch(_ scenario: Scenario) async throws -> Data { try scenario.data() }
}

public enum PurchaseResult: Equatable { case added(String), notificationRequested }
public struct ActionRegistry {
    private var handlers: [String: (String?) throws -> PurchaseResult] = [:]
    public init() {}
    public mutating func register(_ name: String, handler: @escaping (String?) throws -> PurchaseResult) throws {
        guard handlers[name] == nil else { throw ContractError.duplicateRegistration }
        handlers[name] = handler
    }
    public func perform(_ name: String, size: String?) throws -> PurchaseResult {
        guard let handler = handlers[name] else { throw ContractError.unsupportedAction }
        return try handler(size)
    }
    public static func demo() throws -> Self {
        var registry = Self()
        try registry.register("addToBag") { size in
            guard let size, !size.isEmpty else { throw ContractError.invalidProps }
            return .added(size)
        }
        try registry.register("notifyMe") { _ in .notificationRequested }
        return registry
    }
}
