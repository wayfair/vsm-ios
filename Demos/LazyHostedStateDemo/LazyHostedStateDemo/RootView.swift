//
//  RootView.swift
//  LazyHostedStateDemo
//

import SwiftUI

struct RootView: View {
    @State private var settings = DemoSettings()
    @State private var feedResetToken = 0
    private let repository = MockProductRepository()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                controls
                ProductFeedView(repository: repository, settings: settings)
                    // A fresh feed (and ViewStateStore) whenever the ownership mode changes.
                    .id("\(settings.mode.rawValue)-\(feedResetToken)")
            }
            .navigationTitle("Products")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            Picker("Card state ownership", selection: $settings.mode) {
                ForEach(CardStateOwnership.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("mode-picker")

            HStack {
                Toggle("Simulate purge", isOn: $settings.purge)
                    .accessibilityIdentifier("purge-toggle")
                Button("Reset") {
                    DemoMetrics.shared.reset()
                    feedResetToken += 1
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("reset-button")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
