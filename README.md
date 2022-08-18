[![Release](https://img.shields.io/github/v/release/wayfair-incubator/vsm-ios?display_name=tag)](CHANGELOG.md)
[![Lint](https://github.com/wayfair-incubator/vsm-ios/actions/workflows/lint.yml/badge.svg?branch=main)](https://github.com/wayfair-incubator/vsm-ios/actions/workflows/lint.yml)
[![CI](https://github.com/wayfair-incubator/vsm-ios/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/wayfair-incubator/vsm-ios/actions/workflows/ci.yml)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.0-4baaaa.svg)](CODE_OF_CONDUCT.md)
[![Maintainer](https://img.shields.io/badge/Maintainer-Wayfair-7F187F)](https://wayfair.github.io)

# VSM for iOS

VSM is a unidirectional, type-safe, behavior-driven, clean architecture. This repository hosts an open-source swift package framework for easily building features in VSM on iOS.

Open the [Demo App](Demos/Shopping) to see in-depth examples of how to build features using the VSM pattern.

## Overview

VSM stands for ***V***iew ***S***tate ***M***odel. The **View** observes and renders the **State**. Each **State** may provide a **Model**. Each **Model** contains the **Data** and **Action**s available in the given **State**. Each **Action** in a **Model** returns a new **State**. **State** changes cause the **View** to update.

![VSM Diagram](vsm-diagram.png)

In this module, the provided `StateContainer` type encapsulates and observes the State. A `ViewStateRendering` view (SwiftUI or UIKit) can observe the `container.state` value for rendering the States as they change.

## Documentation

Documentation and guides for learning the VSM architecture and accompanying iOS framework can be found [here](/Sources/VSM/Documentation.docc/Documentation.md).

## Project Information

### Credits

VSM for iOS is owned and [maintained](MAINTAINERS.md) by [Wayfair](https://www.wayfair.com/).

### Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

### Security

See [SECURITY.md](SECURITY.md).

### License

VSM for iOS is released under the MIT license. See [LICENSE](LICENSE) for details.
