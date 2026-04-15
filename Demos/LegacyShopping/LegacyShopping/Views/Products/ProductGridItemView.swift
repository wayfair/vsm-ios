//
//  ProductGridItemView.swift
//  Shopping
//
//  Created by Albert Bori on 2/14/22.
//

import SwiftUI

struct ProductGridItemView: View {
    typealias Dependencies = ProductView.Dependencies & UIFrameworkDependency
    let dependencies: Dependencies
    let product: GridProduct
    @State private(set) var showProductDetailView: Bool = false
        
    var body: some View {
        NavigationLink(destination: productView(for: product.id), isActive: $showProductDetailView) {
            VStack {
                AsyncImage(url: product.imageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    ProgressView()
                }
                .accessibilityIdentifier("\(product.name) Image")
                Text(product.name).bold()
            }
        }
        .accessibilityIdentifier(product.name)
    }
    
    @ViewBuilder
    func productView(for id: Int) -> some View {
        switch dependencies.frameworkProvider.framework {
        case .swiftUI:
            ProductView(dependencies: dependencies, productId: product.id)
        case .uiKit:
            ProductUIKitView(dependencies: dependencies, productId: product.id)
        }
    }
}

struct ProductGridItemView_Previews: PreviewProvider {
    static var previews: some View {
        ProductGridItemView(dependencies: MockAppDependencies.noOp, product: GridProduct(id: 1, name: "Test", imageURL: ProductDatabase.allProducts.first!.imageURL))
    }
}
