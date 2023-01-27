//
//  ProfileView.swift
//  Shopping
//
//  Created by Albert Bori on 1/26/23.
//

import SwiftUI
import VSM

struct ProfileView: View {
    typealias Dependencies = ProfileLoaderModel.Dependencies
    @ViewState var state: ProfileViewState
    @State private var username: String = ""
    
    init(dependencies: Dependencies) {
        let loaderModel = ProfileLoaderModel(dependencies: dependencies, error: nil)
        _state = .init(wrappedValue: .initialized(loaderModel))
    }
    
    var body: some View {
        ZStack {
            switch state {
            case .initialized(let loaderModel):
                initializedView(loaderModel: loaderModel)
            case .loading:
                ProgressView()
                    .accessibilityIdentifier("Loading...")
            case .editing(let editingModel):
                loadedView(editingModel: editingModel)
            }
        }
        .padding(.all)
        .navigationTitle("Profile")
    }
    
    @ViewBuilder
    func initializedView(loaderModel: ProfileLoaderModeling) -> some View {
        ProgressView()
            .onAppear {
                $state.observe({ await loaderModel.load() })
            }
            .alert(
                "Oops!",
                isPresented: .constant(loaderModel.error != nil),
                presenting: loaderModel.error
            ) { error in
                Button("Retry") {
                    $state.observe({ await loaderModel.load() })
                }
            } message: { error in
                Text(error)
            }
    }
    
    @ViewBuilder
    func loadedView(editingModel: ProfileEditingModeling) -> some View {
        VStack(alignment: .leading) {
            HStack {
                TextField("User Name", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .onAppear {
                        username = editingModel.username
                    }
                    .onChange(of: username) { newUsername in
                        $state.observe({ await editingModel.save(username: newUsername)}, debounced: .seconds(0.5))
                    }
                if case .saving = editingModel.editingState {
                    ProgressView()
                        .padding(.leading, 4)
                        .accessibilityIdentifier("Saving...")
                }
            }
            if let error = editingModel.editingState.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(Color.red)
            }
            Spacer()
        }
    }
}

// MARK: - TestSupport

extension ProfileView {
    init(state: ProfileViewState) {
        _state = .init(wrappedValue: state)
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ProfileView(state: .initialized(ProfileLoaderModel(dependencies: MockAppDependencies.noOp, error: nil)))
        }
        .previewDisplayName("initialized State - no error")
        
        NavigationView {
            ProfileView(state: .initialized(ProfileLoaderModel(dependencies: MockAppDependencies.noOp, error: "Lorem ipsum")))
        }
        .previewDisplayName("initialized State - error")
        
        NavigationView {
            ProfileView(state: .loading)
        }
        .previewDisplayName("loading State")
        
        NavigationView {
            ProfileView(state: .editing(ProfileEditingModel(dependencies: MockAppDependencies.noOp, username: "Foo", editingState: .editing)))
        }
        .previewDisplayName("editing State - editing")
        
        NavigationView {
            ProfileView(state: .editing(ProfileEditingModel(dependencies: MockAppDependencies.noOp, username: "Foo", editingState: .saving)))
        }
        .previewDisplayName("editing State - saving")
        
        NavigationView {
            ProfileView(state: .editing(ProfileEditingModel(dependencies: MockAppDependencies.noOp, username: "Foo", editingState: .error(NSError(domain: "", code: 1)))))
        }
        .previewDisplayName("editing State - error")
    }
}
