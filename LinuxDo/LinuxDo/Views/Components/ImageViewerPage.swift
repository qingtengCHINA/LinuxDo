//
//  ImageViewerPage.swift
//  LinuxDo
//
//  Full-screen image viewer — pinch-to-zoom, double-tap, swipe-to-dismiss
//

import SwiftUI

struct ImageViewerPage: View {
    let url: String
    var images: [String] = []
    var initialIndex: Int = 0

    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var currentIndex: Int = 0

    var body: some View {
        Color.black.ignoresSafeArea().overlay {
            TabView(selection: $currentIndex) {
                if images.isEmpty {
                    singleImage
                } else {
                    ForEach(Array(images.enumerated()), id: \.offset) { idx, imgUrl in
                        AsyncImage(url: URL(string: imgUrl)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .pinchToZoom(scale: $scale, lastScale: $lastScale, offset: $offset)
                            case .failure:
                                Image(systemName: "exclamationmark.triangle").foregroundStyle(.white).font(.largeTitle)
                            default:
                                ProgressView().tint(.white)
                            }
                        }
                        .tag(idx)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .always : .never))
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").font(.title).foregroundStyle(.white.opacity(0.8))
            }
            .padding()
        }
        .overlay(alignment: .bottom) {
            if images.count > 1 {
                Text("\(currentIndex + 1)/\(images.count)")
                    .font(DesignTypography.serifCaption).foregroundStyle(.white.opacity(0.7))
                    .padding(.bottom, 20)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            ShareLink(item: URL(string: url) ?? URL(string: "https://linux.do")!) {
                Image(systemName: "square.and.arrow.up").font(.title3).foregroundStyle(.white.opacity(0.8))
            }
            .padding()
        }
        .gesture(dragToDismiss)
        .onAppear { currentIndex = initialIndex }
    }

    private var singleImage: some View {
        AsyncImage(url: URL(string: url)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .pinchToZoom(scale: $scale, lastScale: $lastScale, offset: $offset)
            case .failure:
                Image(systemName: "exclamationmark.triangle").foregroundStyle(.white).font(.largeTitle)
            default:
                ProgressView().tint(.white)
            }
        }
    }

    private var dragToDismiss: some Gesture {
        DragGesture()
            .onChanged { value in
                if scale <= 1.0 {
                    offset = value.translation
                }
            }
            .onEnded { value in
                if abs(value.translation.height) > 100 && scale <= 1.0 {
                    withAnimation { dismiss() }
                } else {
                    withAnimation { offset = .zero }
                }
            }
    }
}

struct PinchToZoom: ViewModifier {
    @Binding var scale: CGFloat
    @Binding var lastScale: CGFloat
    @Binding var offset: CGSize

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                MagnificationGesture()
                    .onChanged { val in scale = lastScale * val }
                    .onEnded { val in
                        let final = lastScale * val
                        if final < 1.0 {
                            withAnimation { scale = 1.0; lastScale = 1.0; offset = .zero }
                        } else {
                            lastScale = final
                        }
                    }
            )
            .simultaneousGesture(
                TapGesture(count: 2).onEnded {
                    withAnimation {
                        if scale > 1.5 { scale = 1.0; lastScale = 1.0; offset = .zero }
                        else { scale = 2.5; lastScale = 2.5 }
                    }
                }
            )
    }
}

extension View {
    func pinchToZoom(scale: Binding<CGFloat>, lastScale: Binding<CGFloat>, offset: Binding<CGSize>) -> some View {
        self.modifier(PinchToZoom(scale: scale, lastScale: lastScale, offset: offset))
    }
}