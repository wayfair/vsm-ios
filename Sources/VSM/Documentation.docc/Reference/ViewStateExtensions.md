# View State Extensions

An instruction on making your VSM View State fit the needs of your View

## Overview

SwiftUI and UIKit have very particular programming styles, which encourage engineers to form their data and actions in a specific way to make these UI APIs easier to deal with. In some cases, your Feature Shape may not be in a format that conveniently satisfies your view's needs. This article discusses how we can bridge that gap without being pressured to change the Feature Shape.

## Preserving SwiftUI View Identity

The SwiftUI API does a lot of under-the-hood processing of your SwiftUI views. One critical part of this processing relies on the SwiftUI runtime being able to identify one view or sub-view from another.

Since the SwiftUI `View` structs themselves are not the actual views that are being displayed, SwiftUI has to transform your `View` struct into a drawn view on screen. The view's identity is critically important for this process. Specifically, SwiftUI view identity is required for performing SwiftUI view animations and managing the memory of a given view or sub-view.

> Important: If a view's identity is not properly communicated by your `View` struct, then transitions and animations will not work properly. At worst, you will experience memory issues and other rendering anomalies if a view's identity is not consistent.

Needless to say, it's very important when building SwiftUI views to ensure that a view's identity is properly communicated with the SwiftUI framework. You can read more about SwiftUI View identity in [Identity in SwiftUI](https://medium.com/geekculture/identity-in-swiftui-6aacf8f587d9).

The SwiftUI framework keeps track of a view's identity in one of two ways, depending on how your code is written:

1. Structural Identity
1. Explicit Identity

We will cover only Structural Identity in this article, as Explicit Identity is more easily implemented without any VSM considerations

### Structural Identity

Structural Identity in SwiftUI is the default mechanism for identifying views. It is done by recording the location of your view in the view hierarchy. (If you are familiar with identifying HTML tags on a web page in CSS or JavaScript by using [XPath](https://www.w3schools.com/xml/xpath_syntax.asp), this is a very similar concept.)

A view's location is its identity. Since SwiftUI flow control statements are translated into views, you'll discover that some view declarations might result in an inconsistent view identity.

The following simplified example highlights one of these situations:

```swift
struct EditUserProfileView: View, ViewStateRendering {
    ...
    var body: some View {
        switch state.editingState {
        case .editing:
            TextField("Username", $username)
                .disabled(false)
        case .saving:
            TextField("Username", $username)
                .disabled(true)
        }
    }
}
```

While you may think these two view's identities are the same, they are in fact not. The SwiftUI framework sees these as two separate text fields nested within a switch view: `SwitchView<TextField, TextField>`.

The problem we have here is that our view state is an enum and our view code will become much more complicated and verbose if we try to convert the enum to a boolean like so:

```swift
struct EditUserProfileView: View, ViewStateRendering {
    ...
    var body: some View {
        let isSaving: Bool
        switch state.editingState {
        case .editing:
            isSaving = false
        case .saving:
            isSaving = true
        }
        TextField("Username", $username)
            .disabled(isSaving)
        ...
    }
}
```

To prevent our view's code from exploding into data manipulation code, we can instead opt for a much cleaner approach. By extending the view state, we can add a computed property for getting at the information we need in the format that is most convenient.

```swift
extension EditUserProfileViewState {
    var isSaving: Bool {
        switch editingState {
        case .editing:
            return false
        case .saving:
            return true
        }
    }
}
```

Now that we have this extension, our view code becomes much cleaner.

```swift
struct EditUserProfileView: View, ViewStateRendering {
    ...
    var body: some View {
        TextField("Username", $username)
            .disabled(state.isSaving)
        ...
    }
}
```

SwiftUI now sees this TextField as a single view with a disabled modifier. Any transitions, animations, or memory optimizations are now guaranteed to work for this view. These view state extensions are very handy for transforming the Feature Shape into something more digestible for the UI.

## Binding to SwiftUI Views

When working with the SwiftUI framework, you will often come across views or view modifiers that require a `Binding<T>` of some kind. For example, you may have an error view that you want to display if the user gets into an error state. Without view state extensions, your view will be cluttered with code that translates the view state enum into a `Binding<Bool>` and a confusing `.sheet()` view modifier implementation.

```swift
struct EditUserProfileView: View, ViewStateRendering {
    ...
    var hasError: Binding<Bool>

    init() {
        _hasError = Binding<Bool> {
            get {
                if case .savingError(let errorModel) = state.editingState {
                    return true
                }
                return false
            },
            set {
                /* no-op */
            }
        }
    }

    var body: some View {
        VStack {
            ...
        }
        .sheet(isPresented: hasError) {
            if case .savingError(let errorModel) = state.editingState {
                ErrorView(errorModel)
            } else {
                EmptyView()
            }
        }
    }
}
```

To solve this, we will use a view state extension and a model extension to conform the `ErrorModel` to the `Identifiable` protocol.

```swift
extension EditUserProfileViewState {
    var errorModel: ErrorModel? {
        if case .loadingError(let errorModel) = editingState {
            return errorModel
        }
        return nil
    }
}

extension ErrorModel: Identifiable {
    var id: String { message }
}
```

This allows us to build the following view code, which is much more clean and concise.

```swift
struct EditUserProfileView: View, ViewStateRendering {
    ...
    var body: some View {
        VStack {
            ...
        }
        .sheet(item: .constant(state.errorModel)) { errorModel in
            ErrorView(errorModel)
        }
    }
}
```

Look at the difference! If you rely on view state extensions (and in some cases, model extensions), it will remove a lot of friction in writing SwiftUI views for VSM features.

## UIKit Concerns

While there are definitely scenarios where this can be helpful when building UIKit views, it is much less of an issue for UIKit. This is because UIKit rarely defines _and_ configures the view to the current state within the same block of code.

More often, a UIKit view will declare its views as properties (programmatically or via `IBOutlet`s) and then configure those views within the `render(state:)` function. Because the views are already defined within that function, switch statements and other logical structures don't have as many ramifications for the view as they do in SwiftUI.

Regardless, if you encounter any situation in UIKit where a view state or model extension is helpful, feel free to use them at will.

## Do Not Transform Actions

If you have a view and view state like the one in the examples above, you may be tempted to write an extension that looks like this:

```swift
extension EditUserProfileViewState {
    var saveUsername: (String) -> AnyPublisher<EditUserProfileViewState, Never> {
        if case .editing(let editingModel) = editingState {
            return { username in editingModel.save(username: username) }
        }
        return { _ in }
    }
}
```

In order to get view code that looks like this:

```swift
struct EditUserProfileView: View, ViewStateRendering {
    ...
    var body: some View {
        TextField("Username", $username)
            .disabled(state.isSaving)
        Button("Save") {
            observe(state.saveUsername(username))
        }
    }
}
```

**This is a violation of the VSM architecture pattern.** Specifically, this approach negates the safety and readability that comes with explicitly unwrapping actions from the view state.

Obfuscating the action's behavior in a view state extension will confuse future maintainers and invite bugs and regressions into your code. Explicit unwrapping of view state actions within the view code will clearly communicate the meaning of each action to the creator and maintainer alike.

The following approach is a best practice. It is worth noting that there is no `observe` function overload for an optional action result, and this is by design for the reasons stated above.

```swift
struct EditUserProfileView: View, ViewStateRendering {
    ...
    var body: some View {
        TextField("Username", $username)
            .disabled(state.isSaving)
        Button("Save") {
            if case .editing(let editingModel) = editingState {
                observe(editingModel.save(username: username))
            }
        }
    }
}
```
