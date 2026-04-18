//
//  HTTPClient.swift
//  Shopping
//
//  Created by Albert Bori on 2/9/22.
//

import Foundation

protocol ProductRepository: Actor {
    func getGridProducts() async throws -> [GridProduct]
    func getProductDetail(id: Int) async throws -> ProductDetail
}

protocol ProductRepositoryDependency {
    var productRepository: ProductRepository { get }
}

struct GridProduct: Decodable {
    let id: Int
    let name: String
    let imageURL: URL
}

struct ProductDetail: Decodable {
    let id: Int
    let name: String
    let price: Decimal
    let imageURL: URL
    let description: String
}

//MARK: - Implementation

actor ProductDatabase: ProductRepository {
    static let allProducts: [ProductDetail] = [
        .init(id: 1,
              name: "Ottoman",
              price: 199.99,
              imageURL: URL(string: "https://secure.img1-fg.wfcdn.com/im/03696184/c_crop_resize_zoom-h300-w300%5Ecompr-r85/5729/57294814/default_name.jpg")!,
              description: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Integer ornare sit amet lacus eget vehicula."),
        .init(id: 2,
              name: "TV Stand",
              price: 299.99,
              imageURL: URL(string: "https://secure.img1-fg.wfcdn.com/im/59900886/c_crop_resize_zoom-h300-w300%5Ecompr-r85/1035/103577775/default_name.jpg")!,
              description: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Integer ornare sit amet lacus eget vehicula."),
        .init(id: 3,
              name: "Couch",
              price: 599.99,
              imageURL: URL(string: "https://secure.img1-fg.wfcdn.com/im/97286012/resize-h310-w310%5Ecompr-r85/3796/37963904/Bedfordshire+77%27%27+Rolled+Arm+Sofa+with+Reversible+Cushions.jpg")!,
              description: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Integer ornare sit amet lacus eget vehicula.")
    ]
    
    func getGridProducts() async throws -> [GridProduct] {
        try await Task.sleep(for: AppConstants.simulatedAsyncNetworkDelay)
        return Self.allProducts.map({ .init(id: $0.id, name: $0.name, imageURL: $0.imageURL) })
    }
    
    func getProductDetail(id: Int) async throws -> ProductDetail {
        struct NotFoundError: Error { }
        
        try await Task.sleep(for: AppConstants.simulatedAsyncNetworkDelay)
        guard let productDetail = Self.allProducts.first(where: { $0.id == id }) else {
            throw NotFoundError()
        }
        
        return productDetail
    }
}

//MARK: Test Support

/// Test and preview stand-in; stub closures run on this actor’s executor.
actor MockProductRepository: ProductRepository {
    init(
        getGridProductsImpl: @escaping () async throws -> [GridProduct],
        getProductsDetailImpl: @escaping (Int) async throws -> ProductDetail
    ) {
        self.getGridProductsImpl = getGridProductsImpl
        self.getProductsDetailImpl = getProductsDetailImpl
    }
    
    nonisolated static func noOp() -> MockProductRepository {
        MockProductRepository(
            getGridProductsImpl: { [] },
            getProductsDetailImpl: { _ in
                struct MockNoProductError: Error { }
                throw MockNoProductError()
            }
        )
    }
    
    let getGridProductsImpl: () async throws -> [GridProduct]
    let getProductsDetailImpl: (Int) async throws -> ProductDetail
    
    func getGridProducts() async throws -> [GridProduct] {
        try await getGridProductsImpl()
    }
    
    func getProductDetail(id: Int) async throws -> ProductDetail {
        try await getProductsDetailImpl(id)
    }
}
