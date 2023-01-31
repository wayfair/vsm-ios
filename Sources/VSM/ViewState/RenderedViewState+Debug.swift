//
//  RenderedViewState+Debug.swift
//  
//
//  Created by Albert Bori on 1/31/23.
//

#if DEBUG

@available(iOS 14.0, *)
extension RenderedViewState: _StateContainerStaticDebugging where State == Any { }

#endif
