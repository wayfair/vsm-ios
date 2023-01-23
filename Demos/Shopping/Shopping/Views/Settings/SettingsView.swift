//
//  SettingsView.swift
//  Shopping
//
//  Created by Albert Bori on 5/9/22.
//

import SwiftUI
import VSM

// This view shows two examples of how to handle cases where a value that is controlled by the view should be synchronized with the State and/or State Model.
// Note that in this example, the "S" in "VSM" is silent, because the corresponding view has a single state, which is implied by a single State-Model type
struct SettingsView: View {
    typealias Dependencies = SettingsViewState.Dependencies
    @ViewState var state: SettingsViewState
    
    // a. Custom Binding Approach (generally recommended)
    var isCustomBindingExampleEnabled: Binding<Bool> {
        .init(
            get: {
                state.isCustomBindingExampleEnabled
            },
            set: { enabled in
                $state.observe(state.toggleIsCustomBindingExampleEnabled(enabled))
            }
        )
    }
    
    // b. Value Observation & Synchronization
    // Be careful with this approach. Incorrect use of `onChange` or `onReceive` can result in undesired side-effects if configured incorrectly
    @State var isStateBindingExampleEnabled: Bool
    
    // c State-Model Binding Convenience Functions (recommended for when your `ViewState` is not an enum)
    // c.1
    var isConvenienceBindingExampleEnabled1: Binding<Bool> {
        $state.bind(
            \.isConvenienceBindingExampleEnabled1,
            to: { state, newValue in
                state.toggleIsConvenienceBindingExampleEnabled1(newValue)
            }
        )
    }
    
    // c.2
    var isConvenienceBindingExampleEnabled2: Binding<Bool> {
        $state.bind(\.isConvenienceBindingExampleEnabled2, to: SettingsViewState.toggleIsConvenienceBindingExampleEnabled2)
    }
    
    init(dependencies: Dependencies) {
        let state = SettingsViewState(dependencies: dependencies)
        _state = .init(wrappedValue: state)
        _isStateBindingExampleEnabled = .init(initialValue: state.isStateBindingExampleEnabled)
    }
    
    var body: some View {
        List {
            // a.
            Toggle("Custom Binding", isOn: isCustomBindingExampleEnabled)
                .accessibilityIdentifier("Custom Binding Toggle")
            
            // b.
            Toggle("State Binding", isOn: $isStateBindingExampleEnabled)
                .onChange(of: isStateBindingExampleEnabled) { enabled in
                    $state.observe(state.toggleIsStateBindingExampleEnabled(enabled))
                }
                .onReceive($state.publisher.map(\.isStateBindingExampleEnabled)) { enabled in
                    isStateBindingExampleEnabled = enabled
                }
                .accessibilityIdentifier("State Binding Toggle")
            
            // c.1
            Toggle("Convenience Binding 1", isOn: isConvenienceBindingExampleEnabled1)
                .accessibilityIdentifier("Convenience Binding 1 Toggle")
            
            // c.2
            Toggle("Convenience Binding 2", isOn: isConvenienceBindingExampleEnabled2)
                .accessibilityIdentifier("Convenience Binding 2 Toggle")
        }
        .navigationTitle("Settings")
    }
}
