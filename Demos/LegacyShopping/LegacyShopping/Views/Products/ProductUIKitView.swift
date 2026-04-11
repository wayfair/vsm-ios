//
//  ProductUIKitView.swift
//  Shopping
//
//  Created by Albert Bori on 1/27/23.
//

import SwiftUI
import UIKit

struct ProductUIKitView: UIViewControllerRepresentable {
    typealias Dependencies = ProductView.Dependencies
    let dependencies: Dependencies
    let productId: Int
    
    func makeUIViewController(context: Context) -> ProductViewController {
        ProductViewController(dependencies: dependencies, productId: productId)
    }
    
    func updateUIViewController(_ uiViewController: ProductViewController, context: Context) { }
}
