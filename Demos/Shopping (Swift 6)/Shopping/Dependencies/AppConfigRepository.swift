//
//  AppConfigRepository.swift
//  Shopping
//
//  Created by Albert Bori on 2/9/22.
//

import Foundation

protocol AppConfiguring {
    var appUIMode: AppUIMode { get }
    var currencyCode: String { get }
}

protocol AppConfiguringDependency {
    var appConfig: AppConfiguring { get }
}

enum AppUIMode {
    case swiftUI
    case uiKit
}

struct AppConfiguration: AppConfiguring {
    let appUIMode: AppUIMode
    let currencyCode: String
}
