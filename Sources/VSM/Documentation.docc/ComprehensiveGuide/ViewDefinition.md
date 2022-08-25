# Building the View

<!--@START_MENU_TOKEN@-->Summary<!--@END_MENU_TOKEN@-->

## Overview

<!--@START_MENU_TOKEN@-->Text<!--@END_MENU_TOKEN@-->

VSM encourages this behavior by requiring the View to declare a ``StateContainer`` object, which relies on a generic `ViewState` type that must be provided at declaration or initialization, like so:

```swift
struct MyView: View, ViewStateRendering {
  var container = StateContainer(state: MyViewState.loaded)
}
```
