//
//  ProductGridItemView.swift
//  Shopping
//
//  Created by Albert Bori on 2/14/22.
//

import SwiftUI

struct ProductGridItemView: View {
    let product: GridProduct
        
    var body: some View {
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
        }.accessibilityIdentifier(product.name)
    }
}

struct ProductGridItemView_Previews: PreviewProvider {
    static var previews: some View {
        ProductGridItemView(product: GridProduct(
            id: 1,
            name: "Test",
            imageURL: ProductDatabase.allProducts.first!.imageURL)
        )
    }
}
