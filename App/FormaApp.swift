import SwiftUI
import DynamicUICore

@main struct FormaApp: App {
    var body: some Scene { WindowGroup { ProductScreen() } }
}

@MainActor final class ProductModel: ObservableObject {
    @Published var sections: [RenderedSection] = []
    @Published var purchase: PurchaseProps?
    @Published var selectedSize: String?
    @Published var scenario = Scenario.standard
    @Published var message: String?
    @Published var details: DetailsPresentation?
    @Published var error: String?
    @Published var loading = false
    @Published var favorite = false
    private var generation = 0
    let source: any ScreenSource
    private let registryFactory: (ProductModel) throws -> Registry<RenderedSection>
    // Cache setup success or failure once; payload refreshes reuse the registered factories.
    private lazy var componentRegistry: Result<Registry<RenderedSection>, Error> = Result {
        try registryFactory(self)
    }
    init(source: any ScreenSource = FixtureSource(),
         registryFactory: ((ProductModel) throws -> Registry<RenderedSection>)? = nil) {
        self.source = source
        self.registryFactory = registryFactory ?? { try $0.makeRegistry() }
    }

    func load() async {
        guard !Task.isCancelled else { return }
        generation += 1
        let request = generation
        loading = true
        error = nil
        // Older requests must not finish a newer request's loading state.
        defer {
            if request == generation { loading = false }
        }
        do {
            let screen = try Screen.decode(await source.fetch(scenario))
            let registry = try componentRegistry.get()
            let rendered = try screen.components.compactMap { node -> RenderedSection? in
                guard let component = try registry.resolve(node) else { return nil }
                return RenderedSection(id: node.id, body: component.body, purchase: component.purchase)
            }
            guard request == generation, !Task.isCancelled else { return }
            selectedSize = nil
            sections = rendered.filter { $0.purchase == nil }
            purchase = rendered.compactMap(\.purchase).first
        } catch {
            guard request == generation, !Task.isCancelled, !(error is CancellationError) else { return }
            self.error = "We couldn't load this product. Please try again."
        }
    }

    func buy() {
        guard let purchase else { return }
        do {
            let result = try ActionRegistry.demo().perform(purchase.action, size: selectedSize)
            switch result {
            case .added(let size): message = "Demo: size \(size) added to your bag. No purchase was made."
            case .notificationRequested: message = "Demo: restock request received. No notification service is connected."
            }
        } catch { message = "Choose a size to continue." }
    }

    private func makeRegistry() throws -> Registry<RenderedSection> {
        var r = Registry<RenderedSection>()
        try r.register("hero", props: HeroProps.self) { p in
            guard p.image == "product", !p.label.isEmpty else { throw ContractError.invalidProps }
            let image = Bundle.main.path(forResource: "product", ofType: "jpg").flatMap { UIImage(contentsOfFile: $0) } ?? UIImage()
            return RenderedSection(body: AnyView(Image(uiImage: image).resizable().scaledToFit()
                .accessibilityLabel(p.label).padding(.bottom, 8)))
        }
        try r.register("product", props: ProductProps.self) { p in
            RenderedSection(body: AnyView(VStack(alignment: .leading, spacing: 10) {
                Text("THE PERMANENT COLLECTION").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(p.name).font(.system(.largeTitle, design: .serif)).accessibilityAddTraits(.isHeader)
                Text(p.subtitle).font(.subheadline).foregroundStyle(.secondary)
                HStack { Text(p.price).font(.title3.weight(.semibold))
                    if let original = p.originalPrice { Text(original).strikethrough().foregroundStyle(.secondary).accessibilityLabel("Original price \(original)") }
                }
            }.sectionPadding()))
        }
        try r.register("variants", props: VariantProps.self) { [weak self] p in
            guard !p.sizes.isEmpty, Set(p.sizes).count == p.sizes.count else { throw ContractError.invalidProps }
            return RenderedSection(body: AnyView(VariantView(props: p, model: self).sectionPadding()))
        }
        try r.register("banner", props: BannerProps.self) { p in
            RenderedSection(body: AnyView(HStack(alignment: .top, spacing: 12) {
                Image(systemName: "shippingbox").accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(p.title).font(.subheadline.weight(.semibold))
                    Text(p.message).font(.footnote).foregroundStyle(.secondary)
                }
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Color.accentColor.opacity(0.07)).padding(.horizontal, 24).padding(.vertical, 8)))
        }
        try r.register("details", props: DetailsProps.self) { [weak self] p in
            RenderedSection(body: AnyView(Button { self?.details = DetailsPresentation(title: p.title, body: p.body) } label: {
                HStack { Text(p.title); Spacer(); Image(systemName: "plus") }
                    .frame(minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(.plain).sectionPadding()))
        }
        try r.register("purchase", props: PurchaseProps.self) { p in
            guard ["addToBag", "notifyMe"].contains(p.action) else { throw ContractError.unsupportedAction }
            return RenderedSection(body: AnyView(EmptyView()), purchase: p)
        }
        return r
    }
}

struct RenderedSection: Identifiable {
    var id = UUID().uuidString
    var body: AnyView
    var purchase: PurchaseProps? = nil
}
struct DetailsPresentation: Identifiable { let id = UUID(); let title: String; let body: String }

struct VariantView: View {
    let props: VariantProps
    @ObservedObject var model: ProductModel
    init(props: VariantProps, model: ProductModel?) { self.props = props; self.model = model ?? ProductModel() }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(props.color, systemImage: "circle.lefthalf.filled").font(.subheadline)
            Text("Select size").font(.subheadline.weight(.semibold))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 52))], spacing: 10) {
                ForEach(props.sizes, id: \.self) { size in
                    Button { model.selectedSize = size } label: {
                        Text(size).font(.body.weight(.medium)).frame(maxWidth: .infinity, minHeight: 48)
                            .background(model.selectedSize == size ? Color.primary : Color.clear)
                            .foregroundStyle(model.selectedSize == size ? Color(uiColor: .systemBackground) : .primary)
                            .overlay(Rectangle().stroke(Color.primary.opacity(0.25)))
                    }.buttonStyle(.plain).accessibilityLabel("Size \(size)")
                        .accessibilityAddTraits(model.selectedSize == size ? .isSelected : [])
                }
            }
        }
    }
}

struct ProductScreen: View {
    @StateObject private var model = ProductModel()
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if model.loading && model.sections.isEmpty { ProgressView("Loading product").padding(60) }
                    if let error = model.error {
                        ContentUnavailableView { Label("Product unavailable", systemImage: "wifi.exclamationmark") }
                        description: { Text(error) } actions: { Button("Retry") { Task { await model.load() } } }
                    }
                    ForEach(model.sections) { $0.body }
                    Text("Thoughtfully made. Worn on repeat.").font(.system(.title3, design: .serif))
                        .foregroundStyle(.secondary).padding(32)
                }.frame(maxWidth: 650).frame(maxWidth: .infinity)
            }
            .navigationTitle("FORMA").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu { Picker("Product scenario", selection: $model.scenario) {
                        ForEach(Scenario.allCases) { Text($0.title).tag($0) }
                    } } label: { Image(systemName: "slider.horizontal.3").frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("Demo scenarios")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { model.favorite.toggle() } label: { Image(systemName: model.favorite ? "heart.fill" : "heart").frame(minWidth: 44, minHeight: 44) }
                        .accessibilityLabel(model.favorite ? "Remove from favorites" : "Save to favorites")
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let purchase = model.purchase {
                    Button(action: model.buy) {
                        HStack { Text(purchase.title).fontWeight(.semibold); Spacer(); Image(systemName: purchase.action == "notifyMe" ? "bell" : "bag") }
                            .padding(18).foregroundStyle(.white).background(Color.accentColor)
                    }.accessibilityIdentifier("purchase").padding(.horizontal, 24).padding(.vertical, 12).background(.bar)
                }
            }
            .task(id: model.scenario) { await model.load() }
            .refreshable { await model.load() }
            .sheet(item: $model.details) { details in
                NavigationStack {
                    ScrollView { Text(details.body).frame(maxWidth: .infinity, alignment: .leading).padding(24) }
                        .navigationTitle(details.title).navigationBarTitleDisplayMode(.inline)
                        .toolbar { Button("Done") { model.details = nil } }
                }.presentationDetents([.medium, .large])
            }
            .alert("FORMA Demo", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
                Button("OK") { model.message = nil }
            } message: { Text(model.message ?? "") }
        }.tint(Color(red: 0.12, green: 0.30, blue: 0.25))
    }
}

private extension View {
    func sectionPadding() -> some View { padding(.horizontal, 24).padding(.vertical, 16).frame(maxWidth: .infinity, alignment: .leading) }
}
