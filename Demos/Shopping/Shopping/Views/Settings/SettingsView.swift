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
struct SettingsView: View, ViewStateRendering {
    typealias Dependencies = SettingsViewStateModel.Dependencies
    @StateObject var container: StateContainer<SettingsViewStateModel>
    
    // a. Custom Binding Approach (generally recommended)
    var isCustomBindingExampleEnabled: Binding<Bool>
    
    // b. Value Observation & Synchronization
    // Be careful with this approach. Incorrect use of `onChange` or `onReceive` can result in undesired side-effects
    @State var isStateBindingExampleEnabled: Bool
    
    // c State-Model Binding Convenience Functions (recommended for when your `ViewState` is not an enum)
    // c.1
    var isConvenienceBindingExampleEnabled1: Binding<Bool>
    // c.2
    var isConvenienceBindingExampleEnabled2: Binding<Bool>
    
    init(dependencies: Dependencies) {
        let container: StateContainer<SettingsViewStateModel> = .init(state: SettingsViewStateModel(dependencies: dependencies))
        _container = .init(wrappedValue: container)
        
        // a.
        isCustomBindingExampleEnabled = .init(
            get: {
                container.state.isCustomBindingExampleEnabled
            },
            set: { enabled in
                container.observe(container.state.toggleIsCustomBindingExampleEnabled(enabled))
            })
        
        // b.
        _isStateBindingExampleEnabled = .init(initialValue: container.state.isStateBindingExampleEnabled)
        
        // c.1
        isConvenienceBindingExampleEnabled1 = container.bind(
            \.isConvenienceBindingExampleEnabled1,
            to: { state, newValue in
                state.toggleIsConvenienceBindingExampleEnabled1(newValue)
            }
        )
        
        // c.2
        isConvenienceBindingExampleEnabled2 = container.bind(\.isConvenienceBindingExampleEnabled2, to: SomeViewState.toggleIsConvenienceBindingExampleEnabled2)
        // The last parameter in c.2 can also be `SettingsViewStateModel.toggleIsConvenienceBindingExampleEnabled2`. SomeViewState is just a generic type alias.
    }
    
    var body: some View {
        List {
            // a.
            Toggle("Custom Binding", isOn: isCustomBindingExampleEnabled)
            
            // b.
            Toggle("State Binding", isOn: $isStateBindingExampleEnabled)
                .onChange(of: isStateBindingExampleEnabled) { enabled in
                    container.observe(container.state.toggleIsStateBindingExampleEnabled(enabled))
                }
                .onChange(of: container.state.isStateBindingExampleEnabled, perform: { enabled in
                    isStateBindingExampleEnabled = enabled
                })
            
            // c.1
            Toggle("Convenience Binding 1", isOn: isConvenienceBindingExampleEnabled1)
            
            // c.2
            Toggle("Convenience Binding 2", isOn: isConvenienceBindingExampleEnabled2)
        }
    }
}
