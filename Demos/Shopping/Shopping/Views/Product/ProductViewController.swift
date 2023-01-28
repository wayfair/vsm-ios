//
//  ProductViewController.swift
//  Shopping
//
//  Created by Albert Bori on 1/27/23.
//

import Combine
import SwiftUI
import UIKit
import VSM

class ProductViewController: UIViewController {
    typealias Dependencies = ProductDetailLoaderModel.Dependencies & ProductDetailView.Dependencies & CartButtonView.Dependencies
    let dependencies: Dependencies
    let productId: Int
    var container: StateContainer<ProductViewState>
    private var stateSubscription: AnyCancellable?
    
    lazy var activityIndicatorView: UIActivityIndicatorView = UIActivityIndicatorView.init()
    private var productDetailViewController: ProductDetailViewController?
        
    init(dependencies: Dependencies, productId: Int) {
        self.dependencies = dependencies
        self.productId = productId
        let initializedModel = ProductDetailLoaderModel(
            dependencies: dependencies,
            productId: productId
        )
        container = .init(state: ProductViewState.initialized(initializedModel))
        super.init(nibName: nil, bundle: nil)
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
        
        view.addSubview(activityIndicatorView)
        activityIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            activityIndicatorView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            activityIndicatorView.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        if case .initialized(let initializedModel) = container.state {
            container.observe(initializedModel.loadProductDetail())
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let cartButtonViewController = UIHostingController(rootView: CartButtonView(dependencies: dependencies))
        parent?.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: cartButtonViewController.view)
    }
    
    func render(_ state: ProductViewState) {
        switch state {
        case .initialized, .loading:
            activityIndicatorView.isHidden = false
            activityIndicatorView.startAnimating()
        case .loaded(let productDetail):
            activityIndicatorView.stopAnimating()
            activityIndicatorView.isHidden = true
            parent?.navigationItem.title = productDetail.name
            let contentViewController = UIStoryboard(name: "ProductDetail", bundle: nil)
                .instantiateInitialViewController { coder in
                    ProductDetailViewController(dependencies: self.dependencies, productDetail: productDetail, coder: coder)
                }
            guard let contentViewController else {
                showErrorAlert(message: "Cannot show product", button: (title: "OK", action: { }))
                return
            }
            contentViewController.willMove(toParent: self)
            view.addSubview(contentViewController.view)
            addChild(contentViewController)
            contentViewController.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                contentViewController.view.heightAnchor.constraint(equalTo: view.heightAnchor),
                contentViewController.view.widthAnchor.constraint(equalTo: view.widthAnchor),
                contentViewController.view.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                contentViewController.view.centerXAnchor.constraint(equalTo: view.centerXAnchor)
            ])
            productDetailViewController = contentViewController
            contentViewController.didMove(toParent: self)            
        case .error(message: let message, retry: let retry):
            showErrorAlert(message: message,
                           button: (title: "Retry", action: { [weak self] in
                               self?.container.observe(retry())
                           }))
        }
    }
    
    func showErrorAlert(message: String, button: (title: String, action: () -> Void)) {
        let alertViewController = UIAlertController(title: "Oops!", message: message, preferredStyle: .alert)
        alertViewController.addAction(
            .init(title: button.title,
                  style: .default,
                  handler: { action in
                      button.action()
                  }))
        present(alertViewController, animated: true)
    }
}
