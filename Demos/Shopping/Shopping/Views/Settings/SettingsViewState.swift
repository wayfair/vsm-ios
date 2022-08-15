//
//  SettingsViewState.swift
//  Shopping
//
//  Created by Albert Bori on 5/9/22.
//

import Foundation
import VSM

// Note that in this example, the "S" in "VSM" is silent, because the corresponding view has a single state, which is implied by a single State-Model type
struct SettingsViewStateModel: MutatingCopyable {
    typealias Dependencies = UserDefaultsDependency
    
    private enum SettingKey {
        static var isCustomBindingExampleEnabled = "isCustomBindingExampleEnabled"
        static var isStateBindingExampleEnabled = "isStateBindingExampleEnabled"
        static var isConvenienceBindingExampleEnabled1 = "isConvenienceBindingExampleEnabled1"
        static var isConvenienceBindingExampleEnabled2 = "isConvenienceBindingExampleEnabled2"
    }
    
    let dependencies: Dependencies
    private(set) var isCustomBindingExampleEnabled: Bool
    private(set) var isStateBindingExampleEnabled: Bool
    private(set) var isConvenienceBindingExampleEnabled1: Bool
    private(set) var isConvenienceBindingExampleEnabled2: Bool
        
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        isCustomBindingExampleEnabled = dependencies.userDefaults.bool(forKey: SettingKey.isCustomBindingExampleEnabled)
        isStateBindingExampleEnabled = dependencies.userDefaults.bool(forKey: SettingKey.isStateBindingExampleEnabled)
        isConvenienceBindingExampleEnabled1 = dependencies.userDefaults.bool(forKey: SettingKey.isConvenienceBindingExampleEnabled1)
        isConvenienceBindingExampleEnabled2 = dependencies.userDefaults.bool(forKey: SettingKey.isConvenienceBindingExampleEnabled2)
    }
    
    func toggleIsCustomBindingExampleEnabled(_ enabled: Bool) -> Self {
        change(key: SettingKey.isCustomBindingExampleEnabled, to: enabled)
        return self.copy(mutating: { $0.isCustomBindingExampleEnabled = enabled })
    }
    
    func toggleIsStateBindingExampleEnabled(_ enabled: Bool) -> Self {
        change(key: SettingKey.isStateBindingExampleEnabled, to: enabled)
        return self.copy(mutating: { $0.isStateBindingExampleEnabled = enabled })
    }
    
    func toggleIsConvenienceBindingExampleEnabled1(_ enabled: Bool) -> Self {
        change(key: SettingKey.isConvenienceBindingExampleEnabled1, to: enabled)
        return self.copy(mutating: { $0.isConvenienceBindingExampleEnabled1 = enabled })
    }
    
    func toggleIsConvenienceBindingExampleEnabled2(_ enabled: Bool) -> Self {
        change(key: SettingKey.isConvenienceBindingExampleEnabled2, to: enabled)
        return self.copy(mutating: { $0.isConvenienceBindingExampleEnabled2 = enabled })
    }
    
    private func change(key: String, to enabled: Bool) {
        print("\(key) set to \(enabled)")
        dependencies.userDefaults.set(enabled, forKey: key)
    }
}
