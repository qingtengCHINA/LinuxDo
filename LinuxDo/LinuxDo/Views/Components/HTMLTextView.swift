//
//  HTMLTextView.swift
//  LinuxDo
//
//  Discourse cooked HTML — serif fonts, code highlighting, blockquotes, image taps
//

import SwiftUI
import UIKit

// MARK: - SwiftUI wrapper

struct HTMLTextView: View {
    let html: String
    var baseSize: CGFloat = 15
    var onImageTap: ((String) -> Void)?

    @State private var intrinsicHeight: CGFloat = 20

    var body: some View {
        HTMLTextRepresentable(
            html: html,
            baseSize: baseSize,
            onImageTap: onImageTap,
            dynamicHeight: $intrinsicHeight
        )
        .frame(minHeight: intrinsicHeight)
    }
}

// MARK: - UIKit representable

struct HTMLTextRepresentable: UIViewRepresentable {
    let html: String
    let baseSize: CGFloat
    var onImageTap: ((String) -> Void)?
    @Binding var dynamicHeight: CGFloat

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.isSelectable = true
        tv.dataDetectorTypes = [.link]
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.delegate = context.coordinator

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        tv.addGestureRecognizer(tap)

        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        let attr = context.coordinator.render(html, baseSize: baseSize)
        uiView.attributedText = attr

        DispatchQueue.main.async {
            let size = uiView.sizeThatFits(CGSize(width: uiView.frame.width, height: .greatestFiniteMagnitude))
            if size.height > 0, abs(size.height - dynamicHeight) > 1 {
                dynamicHeight = size.height
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var parent: HTMLTextRepresentable

        init(_ parent: HTMLTextRepresentable) {
            self.parent = parent
        }

        // Link taps → open in Safari
        func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
            // Don't let UITextView open links; we'll handle most in the tap gesture
            // But for regular links this default handler is fine
            return true
        }

        // Image tap detection
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let textView = gesture.view as? UITextView else { return }
            let point = gesture.location(in: textView)
            let charIndex = textView.layoutManager.characterIndex(for: point, in: textView.textContainer, fractionOfDistanceBetweenInsertionPoints: nil)

            guard charIndex < textView.textStorage.length else { return }

            // Check for image attachments
            if let attachment = textView.textStorage.attribute(.attachment, at: charIndex, effectiveRange: nil) as? NSTextAttachment {
                if let imageURL = extractImageURL(from: attachment) {
                    parent.onImageTap?(imageURL)
                    return
                }
            }

            // Also check for <img> tags rendered as links — look for link attribute pointing to image URLs
            var linkRange = NSRange(location: 0, length: 0)
            let link = textView.textStorage.attribute(.link, at: charIndex, effectiveRange: &linkRange) as? URL
            if let link = link {
                let path = link.absoluteString
                if path.hasSuffix(".png") || path.hasSuffix(".jpg") || path.hasSuffix(".jpeg") || path.hasSuffix(".gif") || path.hasSuffix(".webp") {
                    parent.onImageTap?(path)
                    return
                }
                // Regular link — open in Safari
                UIApplication.shared.open(link)
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }

        private func extractImageURL(from attachment: NSTextAttachment) -> String? {
            if let file = attachment.fileType, file.hasPrefix("image/") {
                // NSTextAttachment with image data — we can't easily get the original URL
                // This case only applies to inline images loaded by NSAttributedString
                return nil
            }
            return nil
        }

        // MARK: - Rendering

        func render(_ raw: String, baseSize: CGFloat) -> NSAttributedString {
            let preprocessed = preprocessHTML(raw)
            guard let data = preprocessed.data(using: .utf8),
                  let ns = try? NSMutableAttributedString(
                    data: data,
                    options: [.documentType: NSAttributedString.DocumentType.html,
                              .characterEncoding: String.Encoding.utf8.rawValue],
                    documentAttributes: nil)
            else { return NSAttributedString(string: raw) }

            let range = NSRange(location: 0, length: ns.length)
            applySerifFont(ns, range: range, baseSize: baseSize)
            applyCodeBlockStyling(ns, range: range)
            applyBlockquoteStyling(ns, range: range)
            applyLinkStyling(ns, range: range)

            return ns
        }

        private func preprocessHTML(_ html: String) -> String {
            var s = html
            // Code blocks get a class for styling
            s = s.replacingOccurrences(of: "<pre><code", with: "<pre class='code-block'><code")
            s = s.replacingOccurrences(of: "<pre><code class=\"", with: "<pre class=\"code-block\"><code class=\"")
            // Details/spoiler — style as a collapsible block
            s = s.replacingOccurrences(of: "<details>", with: "<details style='background:#f0f0f0;padding:8px;border-radius:6px;'>")
            // Blockquotes — bordered left accent
            s = s.replacingOccurrences(of: "<blockquote>", with: "<blockquote style='border-left:4px solid #007AFF;padding-left:12px;margin:8px 0;color:#555;'>")
            // Images — make them tappable by wrapping in links if not already
            // Add style for responsive images
            s = s.replacingOccurrences(of: "<img ", with: "<img style='max-width:100%;height:auto;border-radius:6px;' ")
            return s
        }

        private func applySerifFont(_ ns: NSMutableAttributedString, range: NSRange, baseSize: CGFloat) {
            let serif = UIFont(name: "Times New Roman", size: baseSize) ?? UIFont.systemFont(ofSize: baseSize)

            ns.enumerateAttribute(.font, in: range) { v, r, _ in
                guard let f = v as? UIFont else { return }
                let traits = f.fontDescriptor.symbolicTraits
                let isMono = traits.contains(.traitMonoSpace)

                let newSize: CGFloat
                if isMono {
                    newSize = max(baseSize - 1, 13)
                } else if f.pointSize > baseSize + 2 {
                    newSize = f.pointSize
                } else {
                    newSize = baseSize
                }

                let newFont: UIFont
                if isMono {
                    newFont = UIFont.monospacedSystemFont(ofSize: newSize, weight: .regular)
                } else if traits.contains(.traitBold) && traits.contains(.traitItalic) {
                    let desc = serif.fontDescriptor.withSymbolicTraits([.traitBold, .traitItalic]) ?? serif.fontDescriptor
                    newFont = UIFont(descriptor: desc, size: newSize)
                } else if traits.contains(.traitBold) {
                    let desc = serif.fontDescriptor.withSymbolicTraits([.traitBold]) ?? serif.fontDescriptor
                    newFont = UIFont(descriptor: desc, size: newSize)
                } else if traits.contains(.traitItalic) {
                    let desc = serif.fontDescriptor.withSymbolicTraits([.traitItalic]) ?? serif.fontDescriptor
                    newFont = UIFont(descriptor: desc, size: newSize)
                } else {
                    newFont = serif.withSize(newSize)
                }
                ns.addAttribute(.font, value: newFont, range: r)
            }
        }

        private func applyCodeBlockStyling(_ ns: NSMutableAttributedString, range: NSRange) {
            ns.enumerateAttribute(.font, in: range) { v, r, _ in
                guard let f = v as? UIFont, f.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) else { return }
                let nsStr = ns.string as NSString
                let lineRange = nsStr.lineRange(for: r)
                if lineRange.length > r.length + 5 {
                    // Multi-line code block
                    ns.addAttribute(.backgroundColor, value: UIColor.systemGray6.withAlphaComponent(0.6), range: r)
                } else {
                    // Inline code
                    ns.addAttribute(.backgroundColor, value: UIColor.systemGray5.withAlphaComponent(0.4), range: r)
                    ns.addAttribute(.foregroundColor, value: UIColor.systemIndigo, range: r)
                }
            }
        }

        private func applyBlockquoteStyling(_ ns: NSMutableAttributedString, range: NSRange) {
            // Blockquotes from Discourse get styled via HTML <blockquote> with border-left
            // NSAttributedString renders the border as indent, so we add subtle background
            // Find indented paragraphs (blockquote indicator) and add background
            let nsStr = ns.string as NSString
            var idx = 0
            while idx < ns.length {
                let paraRange = nsStr.paragraphRange(for: NSRange(location: idx, length: 1))
                let paraText = nsStr.substring(with: paraRange)

                // Check if this paragraph has head indent (blockquote indicator)
                if idx > 0 {
                    // We rely on the HTML-applied styles; just add subtle tint
                }

                idx = paraRange.location + paraRange.length
            }

            // Apply paragraph styling for blockquote sections
            // Find text that starts with a quote marker
            ns.enumerateAttribute(.paragraphStyle, in: range) { v, r, _ in
                guard let ps = v as? NSParagraphStyle, ps.headIndent > 0 else { return }
                let mutable = ps.mutableCopy() as! NSMutableParagraphStyle
                mutable.firstLineHeadIndent = mutable.headIndent
                ns.addAttribute(.paragraphStyle, value: mutable, range: r)
                ns.addAttribute(.backgroundColor, value: UIColor.systemGray6.withAlphaComponent(0.3), range: r)
            }
        }

        private func applyLinkStyling(_ ns: NSMutableAttributedString, range: NSRange) {
            ns.enumerateAttribute(.link, in: range) { v, r, _ in
                guard v != nil else { return }
                ns.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: r)
            }
        }
    }
}