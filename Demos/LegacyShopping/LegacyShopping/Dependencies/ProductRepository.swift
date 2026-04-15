//
//  HTTPClient.swift
//  Shopping
//
//  Created by Albert Bori on 2/9/22.
//

import Combine
import Foundation

protocol ProductRepository {
    func getGridProducts() -> AnyPublisher<[GridProduct], Error>
    func getProductDetail(id: Int) -> AnyPublisher<ProductDetail, Error>
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

class ProductDatabase: ProductRepository {
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
    
    func getGridProducts() -> AnyPublisher<[GridProduct], Error> {
        return Future { promise in
            DispatchQueue.global().asyncAfter(deadline: AppConstants.simulatedNetworkDelay) {
                promise(.success(Self.allProducts.map({ .init(id: $0.id, name: $0.name, imageURL: $0.imageURL) })))
            }
        }.eraseToAnyPublisher()
    }
    
    func getProductDetail(id: Int) -> AnyPublisher<ProductDetail, Error> {
        struct NotFoundError: Error { }
        return Future { promise in
            DispatchQueue.global().asyncAfter(deadline: AppConstants.simulatedNetworkDelay) {
                guard let productDetail = Self.allProducts.first(where: { $0.id == id }) else {
                    return promise(.failure(NotFoundError()))
                }
                promise(.success(productDetail))
            }
        }.eraseToAnyPublisher()
    }
}

//MARK: Test Support

struct MockProductRepository: ProductRepository {
    static var noOp: Self {
        Self.init(
            getGridProductsImpl: { .empty() },
            getProductsDetailImpl: { _ in .empty() }
        )
    }
    
    var getGridProductsImpl: () -> AnyPublisher<[GridProduct], Error>
    func getGridProducts() -> AnyPublisher<[GridProduct], Error> {
        getGridProductsImpl()
    }
    
    var getProductsDetailImpl: (Int) -> AnyPublisher<ProductDetail, Error>
    func getProductDetail(id: Int) -> AnyPublisher<ProductDetail, Error> {
        getProductsDetailImpl(id)
    }
}
