//
//  ScrollStripView.swift
//  MemoryScroll
//
//  Created by Lixing Liu on 4/8/26.
//

import SwiftUI

/// Displays the composited strip image in a scrollable view.
/// Scrolls horizontally for horizontal strips, vertically for vertical strips.
struct ScrollStripView: View {
    let image: UIImage
    let orientation: ScrollOrientation

    var body: some View {
        GeometryReader { geo in
            switch orientation {
            case .horizontal:
                ScrollView(.horizontal, showsIndicators: true) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: geo.size.height)
                }
            case .vertical:
                ScrollView(.vertical, showsIndicators: true) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width)
                }
            }
        }
    }
}
