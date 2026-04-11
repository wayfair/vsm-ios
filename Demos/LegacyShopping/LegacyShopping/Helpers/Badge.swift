//
//  Badge.swift
//  Shopping
//
//  Created by Albert Bori on 2/9/22.
//

import SwiftUI

struct Badge: View {
    let count: Int

    var body: some View {
        if count == 0 {
            EmptyView()
        } else {
            ZStack(alignment: .topTrailing) {
                Color.clear
                Text(String(count))
                    .font(.system(size: 14))
                    .padding(5)
                    .background(Color.purple)
                    .foregroundColor(Color.white)
                    .clipShape(Circle())
                    // custom positioning in the top-right corner
                    .alignmentGuide(.top) { $0[.bottom] - 8 }
                    .alignmentGuide(.trailing) { $0[.trailing] - $0.width * 0.25 }
                    .accessibilityIdentifier("Cart Item Count")
            }
        }
    }
}

struct Badge_Previews: PreviewProvider {
    static var previews: some View {
        Badge(count: 10)
            .previewDisplayName("Badge with Count")
        
        Badge(count: 0)
            .previewDisplayName("Badge with no Count")
        
        Button(action: {  }) {
            Image(systemName: "cart")
        }
        .overlay(Badge(count: 1))
        .previewDisplayName("Button Badge with Count")
        
        Button(action: {  }) {
            Image(systemName: "cart")
        }
        .overlay(Badge(count: 0))
        .previewDisplayName("Button Badge with no Count")
        
        NavigationView {
            VStack { }
            .toolbar {
                Button(action: {  }) {
                    Image(systemName: "cart")
                }
                .overlay(Badge(count: 1))
            }
        }
        .previewDisplayName("Navigation Button Badge with Count")
        
        NavigationView {
            VStack { }
            .toolbar {
                Button(action: {  }) {
                    Image(systemName: "cart")
                }
                .overlay(Badge(count: 0))
            }
        }
        .previewDisplayName("Navigation Button Badge with no Count")
    }
}
