//
//  AutoRender.swift
//  
//
//  Created by Albert Bori on 11/30/22.
//

import Combine
import Foundation
import SwiftUI

@available(iOS 14.0, *)
@propertyWrapper
public struct AutoRendered<State>: DynamicProperty {
    private var container: StateContainer<State>
    private var stateDidChangeSubscriber: AtomicStateChangeSubscriber<State> = .init()
    
    public var wrappedValue: StateContainer<State> {
        get { container }
        @available(*, unavailable, message: "VSM does not support direct view state editing")
        nonmutating set { /* no-op */ }
    }
    
    public init(container: StateContainer<State>) {
        self.container = container
    }
    
    public init(state: State) {
        self.container = .init(state: state)
    }
    
    /// Hooks into the property wrapper implicit behavior to automatically call the `render()` function on any class that declares a property with this property wrapper.
    ///
    /// For the behavior to take effect, the property's parent type must be a `class` that implements the ``ViewStateRendering`` and will usually be some sort of `UIView` or `UIViewController` subclass.
    /// This is helpful for implementing VSM with **UIKit** views and view controllers in that it handles the "auto-updating" behavior that comes implicitly with SwiftUI.
    public static subscript<ParentClass: AnyObject & ViewStateRendering>(
        _enclosingInstance instance: ParentClass,
        wrapped wrappedKeyPath: KeyPath<ParentClass, StateContainer<State>>,
        storage storageKeyPath: KeyPath<ParentClass, AutoRendered<State>>
    ) -> StateContainer<State> {
        get {
            let wrapper = instance[keyPath: storageKeyPath]
            wrapper
                .stateDidChangeSubscriber
                .subscribe(to: wrapper.container.statePublisher) { [weak instance] newState in
                    instance?.render()
                }
            return wrapper.container
        }
        @available(*, unavailable, message: "VSM does not support direct view state editing")
        set { /* no-op */ }
    }
}

// Example

protocol OptionBViewStating {
    var isEnabled: Bool { get }
    func toggle(isEnabled: Bool) -> OptionBViewStating
}

struct OptionBViewState: OptionBViewStating, MutatingCopyable, Equatable {
    var isEnabled: Bool = false
    
    func toggle(isEnabled: Bool) -> OptionBViewStating {
        self.copy(mutating: { $0.isEnabled = isEnabled })
    }
}

@available(iOS 14.0, *)
class OptionBViewController: UIViewController, ViewStateRendering {
    
    @AutoRendered var container: StateContainer<OptionBViewStating>
    
    lazy var button: UIButton = UIButton()
    
    init(state: OptionBViewStating) {
        _container = .init(container: .init(state: state))
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(button)
    }
    
    func render() {
        button.setTitle(state.isEnabled.description, for: .normal)
        // etc.
    }
}
