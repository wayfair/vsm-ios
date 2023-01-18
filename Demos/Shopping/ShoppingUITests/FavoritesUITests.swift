//
//  FavoritesUITests.swift
//  ShoppingUITests
//
//  Created by Albert Bori on 1/4/23.
//

import XCTest

class FavoritesUITests: UITestCase {
    
    func testToggleFavoriteButton() {
        // Test that the favorite toggle button toggles and retains its value between navigations
        mainPage
            .defaultTab()
            .tapProductCell(for: .ottoman)
            .tapFavoriteButton()
            .tapUnfavoriteButton()
            .tapFavoriteButton()
            .tapBackButton()
            .tapProductCell(for: .ottoman)
            .tapUnfavoriteButton()
            .tapBackButton()
            .tapProductCell(for: .ottoman)
            .assertFavoriteButtonExists()
    }
    
    func testSynchronizedFavoriteState() {
        // Tests that the favorites state is synchronized between views if changed in one place
        let productView = mainPage
            .defaultTab()
            .tapProductCell(for: .ottoman)
        
        productView
            .tapFavoriteButton()
            .tapAccountsTab()
            .tapFavorites()
            .unfavorite(product: .ottoman)
            .assertEmptyFavorites()
            .tapProductsTab(expectingView: productView)
            .assertFavoriteButtonExists()
    }
    
    func testAddAndRemoveManyFavorites() {
        // Tests that the add/remove many behavior works
        mainPage
            .defaultTab()
            .tapProductCell(for: .ottoman)
            .tapFavoriteButton()
            .tapBackButton()
            .tapProductCell(for: .tvStand)
            .tapFavoriteButton()
            .tapBackButton()
            .tapProductCell(for: .couch)
            .tapFavoriteButton()
            .tapAccountsTab()
            .tapFavorites()
            .unfavorite(product: .tvStand)
            .unfavorite(product: .ottoman)
            .unfavorite(product: .couch)
            .assertEmptyFavorites()
    }
}
