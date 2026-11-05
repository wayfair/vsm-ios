//
//  ViewStateStoreTests.swift
//  VSMTests
//
//  Tests for ViewStateStore and HostedViewState.
//

import Foundation
import Testing

@testable import VSM

@Suite
struct ViewStateStoreTests {
    enum RowState: Sendable, Equatable {
        case initial(Int)
        case loaded(Int)
    }

    enum OtherRowState: Sendable, Equatable {
        case initial
    }

    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
    @MainActor
    final class WeakRefs {
        var containers: [WeakContainer] = []

        struct WeakContainer {
            weak var value: AsyncStateContainer<RowState>?
        }

        func track(_ container: AsyncStateContainer<RowState>) {
            containers.append(WeakContainer(value: container))
        }

        var liveCount: Int { containers.filter { $0.value != nil }.count }
    }

    // MARK: - Identity

    @Test("Same id and state type return the identical container")
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
    @MainActor
    func sameIdReturnsSameInstance() {
        let store = ViewStateStore()
        let first = store.container(for: "a", initialState: RowState.initial(1))
        let second = store.container(for: "a", initialState: RowState.initial(2))

        #expect(first === second)
        #expect(second.state == .initial(1), "The second call must not replace the existing container's state")
        #expect(store.count == 1)
    }

    @Test("Different ids return distinct containers")
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
    @MainActor
    func differentIdsReturnDistinctInstances() {
        let store = ViewStateStore()
        let a = store.container(for: "a", initialState: RowState.initial(1))
        let b = store.container(for: "b", initialState: RowState.initial(1))

        #expect(a !== b)
        #expect(store.count == 2)
    }

    @Test("Same id with different state types returns distinct containers")
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
    @MainActor
    func differentStateTypesReturnDistinctInstances() {
        let store = ViewStateStore()
        let row = store.container(for: "a", initialState: RowState.initial(1))
        let other = store.container(for: "a", initialState: OtherRowState.initial)

        #expect(row.state == .initial(1))
        #expect(other.state == .initial)
        #expect(store.count == 2)
    }

    @Test("initialState is evaluated only when no container exists")
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
    @MainActor
    func initialStateEvaluatedOnlyOnMiss() {
        let store = ViewStateStore()
        var evaluations = 0
        func makeState() -> RowState {
            evaluations += 1
            return .initial(evaluations)
        }

        _ = store.container(for: 1, initialState: makeState())
        _ = store.container(for: 1, initialState: makeState())
        _ = store.container(for: 1, initialState: makeState())
        #expect(evaluations == 1)

        _ = store.container(for: 2, initialState: makeState())
        #expect(evaluations == 2)
    }

    @Test("A container keeps the state it reached across lookups")
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
    @MainActor
    func containerRetainsReachedState() {
        let store = ViewStateStore()
        store.container(for: "a", initialState: RowState.initial(1)).observe(RowState.loaded(1))

        #expect(store.container(for: "a", initialState: RowState.initial(1)).state == .loaded(1))
    }

    // MARK: - Release

    @Test("retainOnly releases containers whose ids are not listed")
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
    @MainActor
    func retainOnlyReleasesOthers() {
        let store = ViewStateStore()
        let refs = WeakRefs()
        for id in ["a", "b", "c"] {
            refs.track(store.container(for: id, initialState: RowState.initial(0)))
        }
        #expect(refs.liveCount == 3)

        store.retainOnly(["a", "c"])

        #expect(store.count == 2)
        #expect(refs.containers[0].value != nil)
        #expect(refs.containers[1].value == nil)
        #expect(refs.containers[2].value != nil)
    }

    @Test("removeContainer releases only the matching id and state type")
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
    @MainActor
    func removeContainerReleasesOne() {
        let store = ViewStateStore()
        let refs = WeakRefs()
        refs.track(store.container(for: "a", initialState: RowState.initial(0)))
        refs.track(store.container(for: "b", initialState: RowState.initial(0)))
        _ = store.container(for: "a", initialState: OtherRowState.initial)

        store.removeContainer(for: "a", as: RowState.self)

        #expect(refs.containers[0].value == nil)
        #expect(refs.containers[1].value != nil)
        #expect(store.count == 2, "b/RowState and a/OtherRowState remain")
        #expect(store.container(for: "a", initialState: RowState.initial(9)).state == .initial(9), "A removed id restarts from a fresh initial state")
    }

    @Test("removeAll releases every container")
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
    @MainActor
    func removeAllReleasesEverything() {
        let store = ViewStateStore()
        let refs = WeakRefs()
        for id in 0..<5 {
            refs.track(store.container(for: id, initialState: RowState.initial(id)))
        }

        store.removeAll()

        #expect(store.count == 0)
        #expect(refs.liveCount == 0)
    }

    // MARK: - HostedViewState

    @Test("HostedViewState projects the injected container and tracks its state")
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
    @MainActor
    func hostedViewStateTracksContainer() {
        let container = AsyncStateContainer(state: RowState.initial(1), logger: .disabled)
        let hosted = HostedViewState(container: container)

        #expect(hosted.projectedValue === container)
        #expect(hosted.container === container)
        #expect(hosted.wrappedValue == .initial(1))

        hosted.projectedValue.observe(RowState.loaded(1))

        #expect(hosted.wrappedValue == .loaded(1))
        #expect(hosted.wrappedValue == container.state)
    }
}
