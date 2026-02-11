//
//  UIFrameworkDependency.swift
//  Shopping
//
//  Created by Albert Bori on 12/13/22.
//

import Foundation

protocol UIFrameworkDependency {
    var frameworkProvider: UIFrameworkProviding { get }
}

protocol UIFrameworkProviding {
    var framework: UIFramework { get }
}

struct UIFrameworkProvider: UIFrameworkProviding {
    typealias Dependencies = UserDefaultsDependency
    let dependencies: Dependencies
    
    var framework: UIFramework {
        guard let rawFramework = dependencies.userDefaults.string(forKey: "ui-framework") else {
            return .swiftUI
        }
        return UIFramework(rawValue: rawFramework) ?? .swiftUI
    }
}

struct UIFrameworkProviderDependencies: UIFrameworkProvider.Dependencies {
    var userDefaults: UserDefaults
}

struct MockUIFrameworkProvider: UIFrameworkProviding {
    static var noOp: MockUIFrameworkProvider {
        MockUIFrameworkProvider(framework: .swiftUI)
    }
    
    var framework: UIFramework
}

enum UIFramework: String {
    case swiftUI, uiKit
    
    init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "swiftui":
            self = .swiftUI
        case "uikit":
            self = .uiKit
        default:
            return nil
        }
    }
}
