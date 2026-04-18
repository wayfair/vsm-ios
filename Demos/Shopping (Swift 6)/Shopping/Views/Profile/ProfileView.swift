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
    @FocusState private var isTextFieldFocused: Bool
    
    init(dependencies: Dependencies) {
        let loaderModel = ProfileLoaderModel(dependencies: dependencies, error: nil)
        // Console logging enabled for this demo app. Logging is disabled by default.
        _state = .init(wrappedValue: .initialized(loaderModel), observedViewType: Self.self, loggingEnabled: true)
    }
    
    var body: some View {
        ZStack {
            switch state {
            case .initialized(let loaderModel):
                initializedView(loaderModel: loaderModel)
            case .loading:
                ProgressView()
                    .accessibilityIdentifier("Loading...")
            case .loaded, .editing:
                loadedView()
                    .onAppear {
                        guard case .loaded(let loadedModel) = state else { return }
                        username = loadedModel.fetchedUsername
                    }
                    .onChange(of: isTextFieldFocused) { _, focused in
                        if focused {
                            guard case .loaded(let loadedModel) = state else { return }
                            $state.observe(loadedModel.startEditing())
                        }
                    }
            }
        }
        .padding()
        .navigationTitle("Profile")
    }
    
    @ViewBuilder
    func initializedView(loaderModel: ProfileLoaderModel) -> some View {
        ProgressView()
            .onAppear {
                $state.observe(loaderModel.load())
            }
            .alert(
                "Oops!",
                isPresented: .constant(loaderModel.error != nil),
                presenting: loaderModel.error
            ) { error in
                Button("Retry") {
                    $state.observe(loaderModel.load())
                }
            } message: { error in
                Text(error)
            }
    }
    
    @ViewBuilder
    func loadedView() -> some View {
        VStack(alignment: .leading) {
            HStack {
                TextField("User Name", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextFieldFocused)
                if state.isSaving {
                    ProgressView()
                        .padding(.leading, 4)
                        .accessibilityIdentifier("Saving...")
                }
            }
            if let error = state.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(Color.red)
            }
            Spacer()
        }
        .onChange(of: username, debounce: .seconds(0.5)) { _, newValue in
            if case .editing(let editingModel) = state {
                $state.observe(editingModel.save(username: newValue))
            }
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
            ProfileView(state: .initialized(ProfileLoaderModel(dependencies: MockAppDependencies.noOp(), error: nil)))
        }
        .previewDisplayName("initialized State - no error")
        
        NavigationView {
            ProfileView(state: .initialized(ProfileLoaderModel(dependencies: MockAppDependencies.noOp(), error: "Lorem ipsum")))
        }
        .previewDisplayName("initialized State - error")
        
        NavigationView {
            ProfileView(state: .loading)
        }
        .previewDisplayName("loading State")
        
        NavigationView {
            ProfileView(state: .editing(ProfileEditingModel(dependencies: MockAppDependencies.noOp(), username: "Foo", editingState: .editing)))
        }
        .previewDisplayName("editing State - editing")
        
        NavigationView {
            ProfileView(state: .editing(ProfileEditingModel(dependencies: MockAppDependencies.noOp(), username: "Foo", editingState: .saving)))
        }
        .previewDisplayName("editing State - saving")
        
        NavigationView {
            ProfileView(state: .editing(ProfileEditingModel(dependencies: MockAppDependencies.noOp(), username: "Foo", editingState: .error(NSError(domain: "", code: 1)))))
        }
        .previewDisplayName("editing State - error")
    }
}
