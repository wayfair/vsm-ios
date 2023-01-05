//
//  ProductGridItemView.swift
//  Shopping
//
//  Created by Albert Bori on 2/14/22.
//

import SwiftUI

struct ProductGridItemView: View {
    typealias Dependencies = ProductView.Dependencies
    let dependencies: Dependencies
    let product: GridProduct
    @State private(set) var showProductDetailView: Bool = false
        
    var body: some View {
        NavigationLink(destination: ProductView(dependencies: dependencies, productId: product.id), isActive: $showProductDetailView) {
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
}

struct ProductGridItemView_Previews: PreviewProvider {
    static var previews: some View {
        ProductGridItemView(dependencies: MockAppDependencies.noOp, product: GridProduct(id: 1, name: "Test", imageURL: ProductDatabase.allProducts.first!.imageURL))
    }
}
