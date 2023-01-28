//
//  ProductDetailViewController.swift
//  Shopping
//
//  Created by Albert Bori on 1/27/23.
//

import Combine
import SwiftUI
import UIKit
import VSM

class ProductDetailViewController: UIViewController, ViewStateRendering {
    typealias Dependencies = AddToCartModel.Dependencies & FavoriteButtonView.Dependencies
    
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var favoriteButtonContainerView: UIView!
    @IBOutlet weak var productImage: UIImageView!
    @IBOutlet weak var productDetailLabel: UILabel!
    @IBOutlet weak var addToCartButton: UIButton!
    @IBOutlet weak var confirmationView: UIView!
    @IBOutlet weak var confirmationLabel: UILabel!
    @IBOutlet weak var errorView: UIView!
    @IBOutlet weak var errorLabel: UILabel!
    
    lazy var priceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter
    }()
    
    let dependencies: Dependencies
    let productDetail: ProductDetail
    var container: StateContainer<ProductDetailViewState>
    private var stateSubscription: AnyCancellable?
        
    init?(dependencies: Dependencies, productDetail: ProductDetail, coder: NSCoder) {
        self.dependencies = dependencies
        self.productDetail = productDetail
        let addToCartModel = AddToCartModel(dependencies: dependencies, productId: productDetail.id)
        container = .init(state: .viewing(addToCartModel))
        super.init(coder: coder)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        stateSubscription = container.$state
            .sink { [weak self] newState in
                self?.render(newState)
            }
        
        // create a FavoriteButtonView and add it to the favoriteButtonContainerView
        let favoriteButtonViewController = UIHostingController(rootView: FavoriteButtonView(dependencies: dependencies, productId: productDetail.id, productName: productDetail.name))
        favoriteButtonContainerView.addSubview(favoriteButtonViewController.view)
        favoriteButtonViewController.view.translatesAutoresizingMaskIntoConstraints = false
        favoriteButtonViewController.view.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        NSLayoutConstraint.activate([
            favoriteButtonViewController.view.topAnchor.constraint(equalTo: favoriteButtonContainerView.topAnchor),
            favoriteButtonViewController.view.leadingAnchor.constraint(equalTo: favoriteButtonContainerView.leadingAnchor),
            favoriteButtonViewController.view.trailingAnchor.constraint(equalTo: favoriteButtonContainerView.trailingAnchor),
            favoriteButtonViewController.view.bottomAnchor.constraint(equalTo: favoriteButtonContainerView.bottomAnchor)
        ])
        
        // add an action to the addToCartButton to call addToCart on the addToCartModel
        let action = UIAction() { [weak self] action in
            guard let strongSelf = self else { return }
            switch strongSelf.state {
            case .viewing(let addToCartModel), .addedToCart(let addToCartModel), .addToCartError(message: _, let addToCartModel):
                self?.container.observe(addToCartModel.addToCart())
            default:
                break
            }
        }
        addToCartButton.addAction(action, for: .touchUpInside)
        addToCartButton.setTitleColor(.white.withAlphaComponent(0.5), for: .disabled)
        
        priceLabel.text = priceFormatter.string(from: productDetail.price as NSNumber)
        loadProductImage(from: productDetail.imageURL)
        productImage.accessibilityIdentifier = "\(productDetail.name) Image"
        productDetailLabel.text = productDetail.description
        confirmationView.isHidden = true
        errorView.isHidden = true
    }
    
    func render(_ state: ProductDetailViewState) {
        switch state {
        case .viewing:
            // update the UI with the product details
            configureButton(saving: false)
            confirmationView.isHidden = true
            errorView.isHidden = true
        case .addingToCart:
            // handle the addingToCart state, e.g. show a loading spinner on the addToCartButton
            configureButton(saving: true)
            confirmationView.isHidden = true
            errorView.isHidden = true
        case .addedToCart:
            // handle the addedToCart state, e.g. show a success message and update the addToCartButton
            configureButton(saving: false)
            confirmationView.isHidden = false
            confirmationLabel.text = "✅ Added \(productDetail.name) to cart."
            errorView.isHidden = true
        case .addToCartError(let message, _):
            // handle the addToCartError state, e.g. show an error message and update the addToCartButton
            configureButton(saving: false)
            errorView.isHidden = false
            errorLabel.text = message
        }
    }
    
    func configureButton(saving: Bool) {
        addToCartButton.isEnabled = !saving
        addToCartButton.setTitle(saving ? "Adding to Cart..." : "Add to Cart", for: .normal)
    }

    func loadProductImage(from url: URL) {
        guard productImage.image == nil else { return }
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.productImage.image = image
                }
            }
        }
        task.resume()
    }
}
