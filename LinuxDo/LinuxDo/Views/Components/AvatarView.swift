//
//  AvatarView.swift
//  LinuxDo
//

import SwiftUI
import UIKit

struct AvatarView: View {
    let url: URL?
    let size: CGFloat

    init(url: URL?, size: CGFloat = 40) {
        self.url = url
        self.size = size
    }

    var body: some View {
        Group {
            if let url {
                CachedAsyncImage(url: url, size: size)
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.secondary)
                    .frame(width: size, height: size)
            }
        }
        .clipShape(Circle())
    }
}

struct CachedAsyncImage: View {
    let url: URL
    let size: CGFloat
    @State private var imageData: Data?

    var body: some View {
        Group {
            if let data = imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.gray.opacity(0.15)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .task {
            imageData = await ImageLoader.shared.load(url: url)
        }
    }
}
