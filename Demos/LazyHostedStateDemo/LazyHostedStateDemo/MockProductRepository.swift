//
//  MockProductRepository.swift
//  LazyHostedStateDemo
//

import Foundation

struct ProductSummary: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
}

struct ProductDetails: Sendable {
    let priceText: String
    let ratingText: String
    let isFavorite: Bool
}

protocol ProductRepository: Sendable {
    func fetchFeed() async throws -> [ProductSummary]
    func fetchDetails(for productID: ProductSummary.ID) async throws -> ProductDetails
    func setFavorite(_ isFavorite: Bool, for productID: ProductSummary.ID) async throws
}

/// 320 products, randomized detail latency. Counts every detail fetch it starts, completes and sees cancelled.
struct MockProductRepository: ProductRepository {
    static let productCount = 320

    let metrics: DemoMetrics

    init(metrics: DemoMetrics = .shared) {
        self.metrics = metrics
    }

    func fetchFeed() async throws -> [ProductSummary] {
        try await Task.sleep(for: .milliseconds(600))
        return (1...Self.productCount).map { ProductSummary(id: "SKU-\($0)", name: "Product \($0)") }
    }

    func fetchDetails(for productID: ProductSummary.ID) async throws -> ProductDetails {
        metrics.fetchStarted()
        do {
            try await Task.sleep(for: .milliseconds(Int.random(in: 300...1200)))
        } catch {
            metrics.fetchCancelled()
            throw error
        }
        metrics.fetchCompleted()
        let number = Int(productID.dropFirst(4)) ?? 0
        return ProductDetails(
            priceText: "$\(20 + number % 80).99",
            ratingText: "★ \(3 + number % 2).\(number % 10)",
            isFavorite: false
        )
    }

    func setFavorite(_ isFavorite: Bool, for productID: ProductSummary.ID) async throws {
        try await Task.sleep(for: .milliseconds(250))
    }
}
