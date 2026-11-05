//
//  ProductFeedView.swift
//  LazyHostedStateDemo
//

import SwiftUI
import VSM

struct ProductFeedView: View {
    @ViewState var state: ProductFeedViewState

    /// Owns every card's container in Hosted mode. It lives here, outside the LazyVStack.
    @State private var rowStates = ViewStateStore()

    /// Bumped on a timer when "Simulate purge" is on. Applied as `.id(generation)` to each row, which
    /// makes SwiftUI rebuild the row and discard its `@State`, the way iOS 27 is expected to for
    /// rows that scroll out of a lazy container.
    @State private var generation = 0
    @State private var frameMonitor = FrameMonitor()

    let settings: DemoSettings

    init(repository: any ProductRepository, settings: DemoSettings) {
        self.settings = settings
        _state = ViewState(
            wrappedValue: .initialized(ProductFeedLoaderModel(repository: repository)),
            observedViewType: ProductFeedView.self,
            signpostsEnabled: true
        )
    }

    var body: some View {
        content
            .overlay(alignment: .bottom) {
                DebugOverlay(mode: settings.mode, storeCount: { rowStates.count })
            }
            .task(id: settings.purge) { await runPurgeTimer() }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .initialized(let loaderModel):
            ProgressView()
                .onAppear { $state.observe(loaderModel.load()) }

        case .loading:
            ProgressView("Loading products…")

        case .loaded(let model):
            productList(model)

        case .loadingError(let errorModel):
            ContentUnavailableView {
                Label("Couldn't load products", systemImage: "exclamationmark.triangle")
            } description: {
                Text(errorModel.message)
            } actions: {
                Button("Try Again") { $state.observe(errorModel.retry()) }
            }
        }
    }

    private func productList(_ model: ProductFeedLoadedModel) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(model.products) { product in
                        card(for: product, repository: model.repository)
                            .id(settings.purge ? generation : 0)
                    }
                }
                .padding()
            }
            .accessibilityIdentifier("feed-scroll")
            .refreshable { [container = $state, rowStates] in
                rowStates.removeAll()
                await container.refresh(state: { await model.refreshed() })
            }
            .onChange(of: model.productIDs, initial: true) { _, ids in
                rowStates.retainOnly(ids)
            }
            .task(id: settings.autoscroll) {
                guard settings.autoscroll else { return }
                frameMonitor.start()
                await runScrollScript(proxy: proxy, ids: model.productIDs)
                let frames = frameMonitor.finish()
                await reportSettledState(totalProducts: model.products.count, frames: frames)
            }
        }
    }

    @ViewBuilder
    private func card(for product: ProductSummary, repository: any ProductRepository) -> some View {
        switch settings.mode {
        case .baseline:
            BaselineCardView(summary: product, repository: repository)

        case .hosted:
            HostedCardView(
                container: rowStates.container(
                    for: product.id,
                    initialState: ProductCardViewState.initialized(
                        ProductCardLoaderModel(summary: product, repository: repository)
                    ),
                    observedViewType: HostedCardView.self,
                    signpostsEnabled: true
                )
            )
        }
    }

    // MARK: - Simulated purge

    private func runPurgeTimer() async {
        guard settings.purge else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(settings.purgeInterval))
            guard !Task.isCancelled else { return }
            generation += 1
        }
    }

    // MARK: - Scroll script for profiling runs (-autoscroll 1)

    /// Mirrors the UI-test scroll script: step down through the feed, jump back to the top, repeat.
    private func runScrollScript(proxy: ScrollViewProxy, ids: [ProductSummary.ID]) async {
        guard let first = ids.first else { return }
        let step = 12
        try? await Task.sleep(for: .seconds(2))
        for _ in 0..<settings.cycles {
            for index in stride(from: 0, to: ids.count, by: step) {
                guard !Task.isCancelled else { return }
                withAnimation(.linear(duration: 0.2)) { proxy.scrollTo(ids[index], anchor: .top) }
                try? await Task.sleep(for: .milliseconds(250))
            }
            withAnimation(.linear(duration: 0.8)) { proxy.scrollTo(first, anchor: .top) }
            try? await Task.sleep(for: .seconds(1))
        }
    }

    /// Writes counters once the script ends, then again after the app has been idle for a few seconds.
    private func reportSettledState(totalProducts: Int, frames: FrameMonitor.Result) async {
        func report() -> RunReport.Report {
            RunReport.Report(
                mode: settings.mode.rawValue,
                purge: settings.purge,
                storeCount: rowStates.count,
                totalProducts: totalProducts,
                metrics: DemoMetrics.shared.snapshot,
                frames: frames
            )
        }
        RunReport.write(named: "autoscroll-done.json", report())
        // Stop purging while idle so the settled numbers reflect steady state.
        try? await Task.sleep(for: .seconds(6))
        RunReport.write(named: "metrics-settled.json", report())
    }
}
