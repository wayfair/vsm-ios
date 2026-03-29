# Working with Data in VSM

A guide for building async data sources for VSM 2.0

## Overview

VSM is a reactive architecture. Views observe and render a stream of view states. The source of these view states are async operations and data streams which are transformed into the desired view states within the VSM models.

**Data sources** are types that manage data and business logic (API clients, database managers, or business logic state machines). When data sources are shared between VSM views, they help reduce the volume of code required to keep data in sync between views and communicate changes in data state.

VSM 2.0 is built on Swift's native async/await concurrency model, providing type-safe, thread-safe state management with `@MainActor` isolation and `Sendable` requirements. This ensures all state updates happen on the main thread while allowing data fetching to occur on background threads.

This guide covers:

- Defining view states and creating state models
- Building and structuring data sources
- Using dependency injection (CPDI) to connect everything together

## What Changed in VSM 2.0

VSM 2.0 represents a major architectural shift from Combine to Swift's async/await:

- **Async/Await First**: Models use async methods instead of returning Combine Publishers
- **StateSequence**: Multi-step state transitions (e.g., loading → loaded/error) using the `StateSequence` type
- **AsyncStream Support**: Complex operations with multiple intermediate states
- **Thread Safety**: All state types must conform to `Sendable` for Swift 6 concurrency safety
- **@MainActor Isolation**: State updates automatically happen on the main thread
- **@ViewState Property Wrapper**: New SwiftUI property wrapper for observing state changes
- **Legacy Combine Support**: Optional backward compatibility via the `observe(_ publisher:)` API on ``AsyncStateContainer``

## Defining View State

A common approach for defining view states in VSM is to use an enum with associated values representing different states. For example:

```swift
enum UserBioViewState: Sendable {
    case initialized(LoaderModel)
    case loading
    case loaded(LoadedModel)
    case error(message: String, retry: @Sendable () async -> UserBioViewState)
}
```

Key characteristics:

- **Sendable Conformance**: Required for thread-safe concurrency
- **State-Specific Models**: Each case has relevant data and actions
- **Async Closures**: Error retry actions use `@Sendable () async -> State` closures

## Creating State Models

Models contain the data and actions for each state:

```swift
struct LoaderModel: Sendable {
    typealias Dependencies = UserDataStoreDependency
    let dependencies: Dependencies

    @StateSequenceBuilder
    func loadUserData() -> StateSequence<UserBioViewState> {
        UserBioViewState.loading
        Next { await fetchUserData() }
    }
    
    @concurrent
    private func fetchUserData() async -> UserBioViewState {
        do {
            let userData = try await dependencies.userDataStore.load()
            return .loaded(LoadedModel(userData: userData, dependencies: dependencies))
        } catch {
            return .error(
                message: error.localizedDescription,
                retry: { await fetchUserData() }
            )
        }
    }
}

struct LoadedModel: Sendable {
    let userData: UserData
    let dependencies: LoaderModel.Dependencies
    
    func refresh() async -> UserBioViewState {
        do {
            let userData = try await dependencies.userDataStore.load()
            return .loaded(LoadedModel(userData: userData, dependencies: dependencies))
        } catch {
            return .error(
                message: "Failed to refresh: \(error)",
                retry: { await self.refresh() }
            )
        }
    }
}
```

Models can return states in three ways:

1. **Direct State**: `func action() async -> State` - Single state result from an async operation
2. **StateSequence**: `func action() -> StateSequence<State>` - Multi-step state transitions (see below for usage)
3. **AsyncStream**: `func action() -> AsyncStream<State>` - Advanced multi-step flows (see below for usage)

## Observing State in Views

Use the `@ViewState` property wrapper to manage and observe state in SwiftUI:

```swift
struct UserBioView: View {
    typealias Dependencies = LoaderModel.Dependencies
    let dependencies: Dependencies
    
    @ViewState var state: UserBioViewState
    
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        let loaderModel = LoaderModel(dependencies: dependencies)
        _state = .init(wrappedValue: .initialized(loaderModel))
    }
    
    var body: some View {
        Group {
            switch state {
            case .initialized, .loading:
                ProgressView()
            case .loaded(let loadedModel):
                loadedView(loadedModel)
            case .error(let message, let retryAction):
                errorView(message: message, retryAction: {
                    $state.observe { await retryAction() }
                })
            }
        }
        .onAppear {
            if case .initialized(let loaderModel) = state {
                $state.observe(loaderModel.loadUserData())
            }
        }
    }
    
    @ViewBuilder
    func loadedView(_ model: LoadedModel) -> some View {
        VStack {
            Text(model.userData.name)
            Button("Refresh") {
                $state.observe { await model.refresh() }
            }
        }
    }
    
    func errorView(message: String, retryAction: @escaping () -> Void) -> some View {
        VStack {
            Text("Error: \(message)")
            Button("Retry", action: retryAction)
        }
    }
}
```

The `@ViewState` property wrapper provides:

- Automatic view updates when state changes
- The `$state.observe()` method to trigger state transitions
- Thread-safe state management via `@MainActor` isolation

## Using StateSequence for Multi-Step Transitions

`StateSequence` enables clean multi-step state transitions and is the **recommended approach for 90% of your actions**. Use StateSequence when you have a **finite, predictable** number of states.

### When to Use StateSequence

Use StateSequence for common patterns with known state flows:

- **Loading data**: `.loading` → `.loaded` or `.error`
- **Deleting items**: `.deleting` → `.deleted` or `.error`  
- **Saving changes**: `.saving` → `.saved` or `.error`
- **Refreshing content**: `.refreshing` → `.loaded` or `.error`

StateSequence is easier to implement and reason about than AsyncStream. If you can predict the sequence of states upfront, use StateSequence.

### How StateSequence Works

The recommended way to create a `StateSequence` is with `@StateSequenceBuilder`. Plain state values listed before any `Next` expression are applied **synchronously** by the container, and `Next` closures run asynchronously:

```swift
@StateSequenceBuilder
func loadUserData() -> StateSequence<UserBioViewState> {
    UserBioViewState.loading               // Synchronous first state
    Next { await fetchUserData() }         // Async state after first
}
```

The sequence executes in order:

1. Plain state values before any `Next` are applied synchronously, setting the state to `.loading`
2. `Next` closures execute asynchronously in order, each returning the next state

This pattern is perfect for "optimistic UI updates" where the loading state appears in the first frame, then updates with results once the async work completes.

## Using AsyncStream for Complex Operations

`AsyncStream` is an **advanced pattern** for complex workflows where the number of state emissions is **unknown or highly variable**. Only use AsyncStream when StateSequence's limitations become apparent—the added flexibility comes with implementation complexity.

### When to Use AsyncStream

Use AsyncStream (sparingly) for advanced scenarios:

- **Multi-step checkout**: `.validating` → `.processing` → `.confirmingPayment` → `.complete` → display receipt
- **Complex workflows** with branching logic and multiple possible paths
- **Operations with variable states** where you can't predict the exact sequence upfront

**Important**: If you find yourself using AsyncStream frequently, reconsider your state design. Most operations can be modeled with StateSequence.

### How AsyncStream Works

```swift
struct CheckoutModel: Sendable {
    let dependencies: Dependencies
    let cart: Cart
    
    func checkout() -> AsyncStream<CartViewState> {
        AsyncStream { continuation in
            Task {
                continuation.yield(.checkingOut)
                await performCheckout(continuation)
                continuation.finish()
            }
        }
    }
    
    @concurrent
    private func performCheckout(_ continuation: AsyncStream<CartViewState>.Continuation) async {
        do {
            try await dependencies.cartStore.checkout()
            continuation.yield(.orderComplete)
            
            try? await Task.sleep(for: .seconds(2))
            continuation.yield(.loadedEmpty)
            
        } catch {
            continuation.yield(.checkoutError(message: "\(error)"))
        }
    }
}
```

This pattern allows emitting multiple states during a single operation:

1. `.checkingOut` - Show checkout progress
2. `.orderComplete` - Show success message  
3. `.loadedEmpty` - Clear cart after delay

The continuation gives you fine-grained control over when each state is emitted, allowing for complex multi-step flows.

Observe AsyncStream in views using `$state.observe()`:

```swift
Button("Checkout") {
    $state.observe(model.checkout())
}
```

## Sharing Actions Across States with Protocols

**Generally, actions should be unique to each state.** Most of the time, different states represent different contexts with different available operations. However, there are specific UX patterns where sharing actions across multiple states makes sense.

### When to Share Actions

Consider sharing actions when:

- **Pull-to-refresh** is available in multiple states (loaded, empty)
- **Retry logic** is identical across error scenarios
- **Background sync** behaves the same way regardless of current state

**Example scenario:** Imagine a shopping cart that syncs with a RESTful service across multiple user sessions:

1. User opens the app and sees an empty cart (`.loadedEmpty` state)
2. User closes the app
3. User adds items to cart via website
4. User reopens the app—the cart still shows empty because it hasn't refreshed yet

The solution is pull-to-refresh on the cart view. But now you have a problem: both `.loaded` and `.loadedEmpty` states need the same refresh logic. This is where shared actions shine.

### How to Share Actions

Use protocols with default implementations to share action logic:

```swift
protocol CartReloadable: Sendable {
    var dependencies: CartLoadedModel.Dependencies { get }
}

extension CartReloadable {
    @StateSequenceBuilder
    func reloadCart() -> StateSequence<CartViewState> {
        CartViewState.loading
        Next { await getCartProducts() }
    }
    
    @concurrent
    private func getCartProducts() async -> CartViewState {
        do {
            let cart = try await dependencies.cartStore.getCartProducts()
            if cart.products.isEmpty {
                return .loadedEmpty(CartLoadedEmptyModel(dependencies: dependencies))
            }
            return .loaded(CartLoadedModel(dependencies: dependencies, cart: cart))
        } catch {
            return .error(message: "\(error)", retry: { await getCartProducts() })
        }
    }
}

struct CartLoadedModel: CartReloadable, Sendable {
    let dependencies: Dependencies
    let cart: Cart
    
    // Can also have state-specific actions
    func removeItem(id: UUID) async -> CartViewState {
        // Only available in loaded state
    }
}

struct CartLoadedEmptyModel: CartReloadable, Sendable {
    let dependencies: Dependencies
    // Only has the shared reloadCart() action
}
```

Now both states can call `reloadCart()` with identical behavior:

```swift
.refreshable {
    await $state.refresh(state: { 
        switch state {
        case .loaded(let model), .loadedEmpty(let model):
            return await model.reloadCart()
        default:
            return state
        }
    })
}
```

**Important**: Don't overuse this pattern. If you find yourself sharing many actions across states, reconsider your state design. Each state should have a clear, distinct purpose with mostly unique actions.

## Data Sources

Now that you understand how to define view states and create state models, let's explore how to build the data layer that powers your VSM features.

### What is a Data Source?

A **data source** is a type that manages data and business logic in your application. Data sources provide a clean separation between your view state logic and data access concerns, making your code more testable and maintainable.

Data sources can take several forms:

- **API Client**: Encapsulates interactions with a RESTful API, handling HTTP requests and responses
- **Database Manager**: Handles read/write operations to local databases (Core Data, SQLite, Realm, etc.)
- **Business Logic State Machine**: Contains only business logic and rules, managing state transitions without external I/O

### Defining Data Source Protocols

Always define data sources as **protocol abstractions** rather than concrete types. This enables easy mocking for unit tests and allows you to swap implementations without changing your view state logic.

```swift
protocol ProductStore: Sendable {
    func getProducts() async throws -> [Product]
    func getProduct(id: UUID) async throws -> Product
    func createProduct(_ product: Product) async throws
    func deleteProduct(id: UUID) async throws
}

protocol ProductStoreDependency: Sendable {
    var productStore: ProductStore { get }
}
```

The data source protocol defines the contract for data operations. The dependency protocol allows for protocol composition in dependency injection (CPDI).

**Why use protocol abstractions?**

1. **Testability**: Easily create mock implementations for unit tests
2. **Flexibility**: Swap between different implementations (in-memory, network, database)
3. **Decoupling**: View state models depend on protocols, not concrete types
4. **Clear Contracts**: Protocols document exactly what operations are available

### Implementing Data Sources

#### Stateless Data Sources (Structs/Classes)

When your data source doesn't maintain mutable state—it simply provides methods to interact with external services—use a struct or class.

**RESTful API Client Example:**

```swift
struct ProductAPIClient: ProductStore {
    let baseURL: URL
    let session: URLSession
    
    func getProducts() async throws -> [Product] {
        let url = baseURL.appendingPathComponent("/products")
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode([Product].self, from: data)
    }
    
    func createProduct(_ product: Product) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("/products"))
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(product)
        let _ = try await session.data(for: request)
    }
}
```

**Database Query Interface Example:**

```swift
struct CoreDataProductStore: ProductStore {
    let context: NSManagedObjectContext
    
    func getProducts() async throws -> [Product] {
        let request = ProductEntity.fetchRequest()
        let entities = try context.fetch(request)
        return entities.map { $0.toDomainModel() }
    }
    
    func saveProduct(_ product: Product) async throws {
        let entity = ProductEntity(context: context)
        entity.update(from: product)
        try context.save()
    }
}
```

#### Stateful Data Sources (Actors)

When your data source needs to maintain its own mutable state, use an actor to ensure thread-safe access.

**Cart Data Source Example:**

```swift
actor CartDatabase: CartStore {
    private var items: [CartItem] = []
    
    func addItem(_ item: CartItem) {
        items.append(item)
    }
    
    func getItems() -> [CartItem] {
        items
    }
    
    func removeItem(id: UUID) {
        items.removeAll { $0.id == id }
    }
    
    func checkout() async throws {
        // Process checkout with current items
        items = []  // Clear cart after successful checkout
    }
}
```

**Favorites Data Source Example:**

```swift
actor FavoritesDatabase: FavoritesStore {
    private var favoriteIDs: Set<UUID> = []
    
    func addFavorite(productID: UUID) {
        favoriteIDs.insert(productID)
    }
    
    func removeFavorite(productID: UUID) {
        favoriteIDs.remove(productID)
    }
    
    func isFavorite(productID: UUID) -> Bool {
        favoriteIDs.contains(productID)
    }
    
    func getFavorites() -> Set<UUID> {
        favoriteIDs
    }
}
```

**In-Memory Cache Example:**

```swift
actor ProductCache: ProductStore {
    private var cachedProducts: [Product] = []
    private var lastFetchTime: Date?
    private let cacheTimeout: TimeInterval = 300 // 5 minutes
    
    func getProducts() async throws -> [Product] {
        if let lastFetch = lastFetchTime, 
           Date().timeIntervalSince(lastFetch) < cacheTimeout,
           !cachedProducts.isEmpty {
            return cachedProducts
        }
        
        let products = try await fetchFromNetwork()
        cachedProducts = products
        lastFetchTime = Date()
        return products
    }
}
```

#### Choosing Between Actors and Structs/Classes

Ask yourself: **"Does this data source need to maintain its own mutable state?"**

- **Yes** → Use an `actor` to ensure thread-safe access to that mutable state
  - Examples: Shopping cart, favorites list, in-memory cache, user session
- **No** → Use a `struct` or `class` because the state lives elsewhere (server, database, etc.)
  - Examples: API clients, database query interfaces, pure validators

Actors add overhead for synchronization. Only use them when you genuinely need to protect mutable state from concurrent access.

### Creating Mock Data Sources for Testing

Protocol abstractions make it trivial to create mock implementations for unit testing:

```swift
struct MockProductStore: ProductStore {
    var productsToReturn: [Product] = []
    var errorToThrow: Error?
    var getProductsCalled = false
    
    func getProducts() async throws -> [Product] {
        getProductsCalled = true
        if let error = errorToThrow {
            throw error
        }
        return productsToReturn
    }
    
    func getProduct(id: UUID) async throws -> Product {
        if let error = errorToThrow {
            throw error
        }
        guard let product = productsToReturn.first(where: { $0.id == id }) else {
            throw ProductError.notFound
        }
        return product
    }
}
```

Use mocks in your tests to verify view state behavior without real network calls or database access:

```swift
@Test func testProductsLoad() async {
    let mockStore = MockProductStore(productsToReturn: [
        Product(id: UUID(), name: "Widget")
    ])
    let dependencies = MockDependencies(productStore: mockStore)
    let model = LoaderModel(dependencies: dependencies)
    
    let stateSequence = model.loadProducts()
    // Verify loading then loaded states...
}
```

For comprehensive examples of testing VSM features with mock data sources, see <doc:UnitTesting>.

### Dependency Injection with CPDI

When considering how to share data sources across your app, we recommend _Composed Protocol Dependency Injection_ (CPDI). CPDI is type-safe, follows the least-knowledge architectural principle, and has zero runtime crashes.

#### Step 1: Define Dependency Protocols

Create a dependency protocol for each data source:

```swift
protocol ProductStoreDependency: Sendable {
    var productStore: ProductStore { get }
}

protocol CartStoreDependency: Sendable {
    var cartStore: CartStore { get }
}

protocol FavoritesStoreDependency: Sendable {
    var favoritesStore: FavoritesStore { get }
}
```

#### Step 2: Compose Dependencies in Models

Use the `&` operator to compose only the dependencies each model needs:

```swift
struct ProductsLoaderModel: Sendable {
    typealias Dependencies = ProductStoreDependency
    let dependencies: Dependencies
    
    @StateSequenceBuilder
    func loadProducts() -> StateSequence<ProductsViewState> {
        ProductsViewState.loading
        Next { await fetchProducts() }
    }
}

struct CartLoadedModel: Sendable {
    typealias Dependencies = CartStoreDependency & ProductStoreDependency
    let dependencies: Dependencies
    let cart: Cart
    
    func addProduct(id: UUID) async -> CartViewState {
        // Can access both cartStore and productStore
    }
}
```

#### Step 3: Compose Dependencies in Views

Views aggregate the dependencies of all their models:

```swift
struct ProductsView: View {
    typealias Dependencies = ProductsLoaderModel.Dependencies
                           & ProductDetailView.Dependencies
    let dependencies: Dependencies
}
```

> Tip: Rather than passing dependencies into each model at initialization time, an alternative is to let the view hold the dependencies and pass them directly into action functions at call time. This can simplify how models are constructed, at the cost of threading dependencies through any private helper functions the action calls. See <doc:ModelStyles> for a detailed comparison of both approaches.

#### Step 4: Create Concrete Dependencies

Implement all dependency protocols at the app root:

```swift
final class AppDependencies: MainView.Dependencies {
    let productStore: ProductStore
    let cartStore: CartStore
    let favoritesStore: FavoritesStore
    
    init(
        productStore: ProductStore,
        cartStore: CartStore,
        favoritesStore: FavoritesStore
    ) {
        self.productStore = productStore
        self.cartStore = cartStore
        self.favoritesStore = favoritesStore
    }
}
```

#### Step 5: Inject at App Launch

```swift
@main
struct ShoppingApp: App {
    var body: some Scene {
        WindowGroup {
            MainView(dependencies: AppDependencies(
                productStore: ProductAPIClient(baseURL: apiURL),
                cartStore: CartDatabase(),
                favoritesStore: FavoritesDatabase()
            ))
        }
    }
}
```

#### Async Dependency Initialization

For data sources that require async initialization, use a provider pattern:

```swift
protocol DependenciesProviding: Sendable {
    @MainActor
    func buildDependencies() async -> MainView.Dependencies
}

struct DependenciesProvider: DependenciesProviding {
    @MainActor
    func buildDependencies() async -> MainView.Dependencies {
        // Perform async initialization
        let productStore = ProductAPIClient(baseURL: await fetchAPIURL())
        let cartStore = CartDatabase()
        
        return AppDependencies(
            productStore: productStore,
            cartStore: cartStore,
            favoritesStore: FavoritesDatabase()
        )
    }
}
```

**Benefits of CPDI:**

- **Type Safety**: Compiler ensures all dependencies are satisfied
- **Least Knowledge**: Each model only sees the dependencies it needs
- **No Runtime Crashes**: Unlike service locator patterns, missing dependencies are compile-time errors
- **Easy Testing**: Inject mock dependencies for isolated unit tests
- **Single Parameter**: All dependencies aggregated into one parameter per view/model

## Thread Safety and Concurrency

VSM 2.0 leverages Swift 6's concurrency features for safe, predictable state management:

### Sendable Requirement

All state types must conform to `Sendable`:

```swift
enum ProductsViewState: Sendable {
    case loaded(ProductsLoadedModel)
}

struct ProductsLoadedModel: Sendable {
    let products: [Product]  // Product must also be Sendable
    let dependencies: Dependencies
}
```

This ensures state can be safely passed across concurrency boundaries.

### @MainActor Isolation

The `@ViewState` property wrapper and `AsyncStateContainer` use `@MainActor` isolation to ensure all state updates happen on the main thread:

- State reads and writes are thread-safe
- No manual dispatch to main queue needed
- SwiftUI updates automatically happen on main thread

### @concurrent Attribute

Use the `@concurrent` attribute on helper methods that produce state:

```swift
@concurrent
private func fetchProducts() async -> ProductsViewState {
    do {
        let products = try await dependencies.productStore.getProducts()
        return .loaded(ProductsLoadedModel(products: products))
    } catch {
        return .error(message: "\(error)")
    }
}
```

This allows the method to be called from any context while maintaining thread safety.

## Advanced Patterns

### Handling Rapidly-Changing Input

For fields where the user types quickly — like a search bar or an auto-saving form — calling `$state.observe()` on every keystroke would spam `AsyncStateContainer` with new async work, causing excessive state churn and redundant network or processing calls.

The recommended approach combines three techniques:

1. **Focused local state**: Store the text field's value in a `@State` property on the view, completely decoupled from VSM. This lets SwiftUI's text field bind directly to local state, so keystrokes never touch `AsyncStateContainer`.
2. **`@FocusState`**: Transition the view state into an "editing" mode only when the user actually focuses the field — not on every character change.
3. **`onChange(of:debounce:)`**: VSM's debounced `onChange` modifier fires only after the user pauses for a specified interval. This is the single point where local state "crosses the boundary" into VSM.

```swift
struct ProfileView: View {
    @ViewState var state: ProfileViewState

    // Local state drives the text field — VSM is never called on every keystroke
    @State private var username: String = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        switch state {
        case .loaded, .editing:
            loadedView()
                .onAppear {
                    // Seed local state from the model on first appearance
                    guard case .loaded(let loadedModel) = state else { return }
                    username = loadedModel.fetchedUsername
                }
                .onChange(of: isTextFieldFocused) { _, focused in
                    // Enter editing state only when focus begins
                    if focused {
                        guard case .loaded(let loadedModel) = state else { return }
                        $state.observe(loadedModel.startEditing())
                    }
                }
        // ...
        }
    }

    func loadedView() -> some View {
        TextField("User Name", text: $username)
            .focused($isTextFieldFocused)
            // Only cross into VSM after the user pauses typing
            .onChange(of: username, debounce: .seconds(0.5)) { _, newValue in
                if case .editing(let editingModel) = state {
                    $state.observe(editingModel.save(username: newValue))
                }
            }
    }
}
```

The model can add a second layer of protection with an early-exit equality check, so that even if the debounce fires, no real work is done if the value hasn't meaningfully changed:

```swift
func save(username: String) -> StateSequence<ProfileViewState> {
    // Skip the save if the user typed and deleted back to the original value
    guard username != self.username else {
        return StateSequence({ .editing(self) })
    }
    guard !username.isEmpty else {
        return StateSequence({
            .editing(self.copy(mutating: { $0.editingState = .error(Errors.emptyUsername) }))
        })
    }
    return StateSequence(
        { .editing(self.copy(mutating: { $0.editingState = .saving })) },
        { /* perform network save... */ }
    )
}
```

Together, `@FocusState` prevents premature state transitions, `onChange(of:debounce:)` gates all VSM calls behind a quiet period, and the model's equality guard prevents redundant async work — so `AsyncStateContainer` only receives observations when there is genuinely something new to do.

> Note: **Migrating from VSM 1.0?** Earlier versions of VSM included `observe(_:debounced:)` overloads directly on `AsyncStateContainer`. These have been removed in VSM 2.0 because the debounce belonged at the _view_ layer, not the state container layer. Keeping the debounce in the view (via `onChange(of:debounce:)`) gives you full control over the quiet period for each individual input, avoids coupling async scheduling to the container, and makes the intent of the code easier to follow.

### State Bindings

Create SwiftUI bindings from state properties:

```swift
let nameBinding = $state.bind(
    \.userName,
    to: { state, newValue in
        await model.updateName(newValue)
    }
)

TextField("Name", text: nameBinding)
```

### Refreshable Support

VSM supports SwiftUI's `refreshable` modifier with the `refresh(state:)` method, which suspends the task until state production completes:

```swift
.refreshable {
    await $state.refresh(state: { await model.reload() })
}
```

**Why does `refresh` block?**

The `refresh(state:)` method is designed to work seamlessly with SwiftUI's Pull to Refresh control. The Pull to Refresh control itself provides the loading state UX—it displays a spinner and keeps the refresh gesture visible while the async work is in progress.

When you use `await $state.refresh(state:)`:

1. The Pull to Refresh control appears and shows its loading spinner
2. The `refresh(state:)` method suspends, waiting for `model.reload()` to complete
3. Your state production happens asynchronously (fetching data, etc.)
4. Once the closure completes and returns the new state, `refresh(state:)` returns
5. The Pull to Refresh control automatically animates smoothly back into place

There's no need to transition to a `.loading` view state because the Pull to Refresh control already provides that visual feedback. The blocking behavior ensures the control stays visible until your data is fully loaded, creating a smooth, intuitive user experience.

**Contrast with `observe`:**

For other user interactions (like button taps), use `observe` instead because you'll want to show loading state in your view:

```swift
Button("Load Data") {
    $state.observe(model.loadData())  // Non-blocking, UI updates via state changes
}
```

With `observe`, your state transitions to `.loading` as your action emits it, updating your UI to show a progress view or skeleton screen. For initial-load flows that must show loading in the first frame, prefer `@StateSequenceBuilder` with plain state values before any `Next` expressions. With `refresh`, the Pull to Refresh control handles that UX automatically.

## Legacy Combine Support

VSM 2.0 maintains backward compatibility with Combine for gradual migration using `observe(_ publisher:)` on ``AsyncStateContainer``:

```swift
import Combine

func observeLegacyPublisher() {
    let publisher: AnyPublisher<ProductsViewState, Never> = ...
    $state.observe(publisher)
}
```

However, we recommend using async/await for new code:

- Simpler error handling with `try`/`catch`
- Better cancellation support via `Task`
- Native Swift concurrency integration
- Improved compiler checking

## Best Practices

1. **Keep Models Simple**: Models should be value types (structs) containing data and actions
2. **Use Sendable**: Ensure all state types conform to `Sendable` for thread safety
3. **Prefer StateSequence**: Use `StateSequence` for most actions-it's easier to implement and reason about. Only reach for AsyncStream when you need the flexibility for complex, multi-step workflows with unknown state counts
4. **Start with Protocol Abstractions**: Always define data sources as protocols for easy testing and flexibility
5. **Choose the Right Data Source Type**: Use actors only when maintaining shared mutable state; use structs/classes for stateless operations
6. **Dependency Composition**: Use protocol composition (CPDI) for type-safe, flexible, testable dependencies
7. **Async All The Way**: Avoid mixing async/await with Combine in new code

## Common Patterns

### Loading → Loaded/Error Flow

```swift
@StateSequenceBuilder
func loadData() -> StateSequence<ViewState> {
    ViewState.loading
    Next { await fetchData() }
}

@concurrent
private func fetchData() async -> ViewState {
    do {
        let data = try await dataStore.getData()
        return .loaded(LoadedModel(data: data))
    } catch {
        return .error(message: "\(error)", retry: { await fetchData() })
    }
}
```

### Optimistic Updates

```swift
func deleteItem(id: UUID) -> StateSequence<ViewState> {
    StateSequence(
        { .deleting(id: id) },          // Optimistic UI
        { await performDelete(id: id) }  // Actual deletion
    )
}
```

### Multi-Step Checkout Flow

```swift
func checkout() -> AsyncStream<CartViewState> {
    AsyncStream { continuation in
        Task {
            continuation.yield(.validating)
            guard await validate() else {
                continuation.yield(.validationError)
                continuation.finish()
                return
            }
            
            continuation.yield(.processing)
            try? await processPayment()
            
            continuation.yield(.complete)
            continuation.finish()
        }
    }
}
```

## Up Next

### Unit Testing VSM features

Now that you know how to use async data sources to power VSM features, you can learn how to write unit tests to validate the requirements of VSM features in <doc:UnitTesting>.

#### Support this Project

If you find anything wrong with this guide, or have suggestions on how to improve it, feel free to [create an issue in our GitHub repo](https://github.com/wayfair-incubator/vsm-ios/issues/new/choose).
