# Navigation

A breakdown of VSM navigation concepts

## Overview

Many architectures have provisions for addressing navigation concepts within their patterns and frameworks. Often, these frameworks treat navigation as "business logic", requiring that all navigation logic is abstracted from the view. The VSM architecture, however, does not follow this mindset. Navigating in iOS is done exclusively through the SwiftUI and UIKit View-APIs, regardless of which architecture you may be using. Separating navigation code from these APIs creates expensive abstractions that are responsible for significant tradeoffs. The following are just some examples of the costs incurred with treating navigation concerns as business logic.

- Navigation code is difficult to read and maintain (ie, Routers and Coordinators in VIPER and other architectures)
- Drastically increases lines of code by creating large logical circles for the sake of abstraction (i.e., In VIPER, the View calls the Presenter calls the Interactor calls the Router calls the navigation API on the same View)
- Abstractions are technically testable by way of injection, but not usually tested with automation because of how tightly coupled they are with view concerns
- Abstractions rely on meta-descriptions of the actual navigation code, which incurs a significant maintenance cost (i.e., The navigation state enums used in The Composable Architecture)

Therefore VSM places navigation behavior squarely as a view concern. As a result, you will find that VSM navigation code looks identical to the navigation examples and tutorials found within Apple's documentation. There are some instances, however, of needing to reconcile some real business logic that affects the navigation of a feature, which we will address later in this article.

## Standard Navigation

We will not go into detail on how to write navigation code for iOS. This is covered ubiquitously in training resources across the internet. When writing navigation code in a VSM feature, use the standard SwiftUI or UIKit navigation APIs that are appropriate for your situation.

In SwiftUI, you would use `@State` and `@Binding` properties on the view struct to control the navigation, as you would expect. In UIKit, you would use `UINavigationControllers` and the `performSegue(withIdentifier:sender:)`, `pushViewController(_:animated:)`, `present(_:animated:completion:)`, etc., as you would expect.

Navigation logic does not generally belong in VSM models, except in cases where your feature _is_, itself, a navigation component (i.e., when building a custom navigation menu view).

## Navigation Logic

VSM models are a source of information and actions that can be performed on that information. This information apprises the view through the view state. In some cases, navigation can be a side-effect of this information. One good example of this concept is when a feature needs to run an A/B test between separate experiences.

In this scenario, the model should interact with the A/B test provider to inform the view which test is active. Note that the model does not tell the view which subview to show, or which modal to present. Instead it returns something like, `testGroup: TestGroups.a`, which the view can interpret into either a UI change, or a navigation state change.

## Deep Linking

The VSM architecture has no specific opinions on deep linking. However, to protect the models from the friction and bloat caused by treating deep-linking code as business logic, it is generally recommended that you rely on UIKit or SwiftUI-based deep linking libraries or frameworks. SwiftUI's new `NavigationStack` is also a perfectly acceptable tool.
