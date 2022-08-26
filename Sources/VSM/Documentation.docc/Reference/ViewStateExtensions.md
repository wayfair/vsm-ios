# View State Extensions - VSM Reference

<!--@START_MENU_TOKEN@-->Summary<!--@END_MENU_TOKEN@-->

## Overview

<!--@START_MENU_TOKEN@-->Text<!--@END_MENU_TOKEN@-->

## Topics

### <!--@START_MENU_TOKEN@-->Group<!--@END_MENU_TOKEN@-->

- <!--@START_MENU_TOKEN@-->``Symbol``<!--@END_MENU_TOKEN@-->

- todo: Expound on the following

Some of these unique requirements may include any combination of the following situations:

- Preserving [SwiftUI view identity](https://medium.com/geekculture/identity-in-swiftui-6aacf8f587d9) between view states (for animations and memory efficiency)
- Providing a custom `Binding<T>` to a property wrapper that requires one
- Translating a `case` condition into a boolean, or optional value for easier access in the view
- Reaching deep within the view state graph to grab a value for display
- Translating a feature state value into something more palatable for viewing
- Conforming a view state or model to `Identifiable`
