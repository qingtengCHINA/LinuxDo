//
//  CreateTopicPage.swift
//  LinuxDo
//
//  创建新话题 — 对照 fluxdo create_topic_page
//

import SwiftUI

struct CreateTopicPage: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var rawBody = ""
    @State private var selectedCategoryID: Int?
    @State private var tags = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showPreview = false
    @State private var categories: [DiscourseCategory] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                formContent
            }
            .navigationTitle("发帖")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSubmitting ? "" : "发布") { submitTopic() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || rawBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                        .fontWeight(.semibold)
                }
            }
            .overlay { if isSubmitting { ProgressView() } }
            .alert("发布失败", isPresented: .constant(errorMessage != nil)) {
                Button("确定") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .task { await loadCategories() }
        }
    }

    private var formContent: some View {
        Form {
            Section {
                TextField("标题", text: $title)
                    .font(DesignTypography.serifHeadline)
            }

            Section {
                Picker("分类", selection: $selectedCategoryID) {
                    Text("选择分类").tag(Int?.none)
                    ForEach(categories) { cat in
                        HStack(spacing: 6) {
                            Circle().fill(Color(hex: cat.hexColor) ?? .accentColor).frame(width: 10, height: 10)
                            Text(cat.name)
                        }
                        .tag(Int?(cat.id))
                    }
                }

                TextField("标签（逗号分隔）", text: $tags)
                    .font(DesignTypography.serifBody)
            }

            Section {
                HStack {
                    Spacer()
                    Button(showPreview ? "编辑" : "预览") { showPreview.toggle() }
                        .font(DesignTypography.serifCaption).buttonStyle(.bordered)
                }

                if showPreview {
                    ScrollableHTMLPreview(html: renderedMarkdown)
                } else {
                    TextEditor(text: $rawBody)
                        .font(DesignTypography.serifBody)
                        .frame(minHeight: 200)
                        .overlay(alignment: .topLeading) {
                            if rawBody.isEmpty {
                                Text("输入内容…（支持 Markdown）")
                                    .font(DesignTypography.serifBody).foregroundStyle(.tertiary)
                                    .padding(.horizontal, 4).padding(.vertical, 8)
                                    .allowsHitTesting(false)
                            }
                        }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var renderedMarkdown: String {
        var md = rawBody
        // Basic markdown to HTML conversion for preview
        // Bold: **text** → <strong>text</strong>
        md = md.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "<strong>$1</strong>", options: .regularExpression)
        // Italic: *text* → <em>text</em>
        md = md.replacingOccurrences(of: "\\*(.+?)\\*", with: "<em>$1</em>", options: .regularExpression)
        // Code: `text` → <code>text</code>
        md = md.replacingOccurrences(of: "`(.+?)`", with: "<code>$1</code>", options: .regularExpression)
        // Line breaks → <br>
        md = md.replacingOccurrences(of: "\n", with: "<br>")
        return md
    }

    private func submitTopic() {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = rawBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !b.isEmpty else { return }

        isSubmitting = true
        Task {
            do {
                var params: [String: String] = [
                    "title": t,
                    "raw": b,
                    "unlist_topic": "false"
                ]
                if let catID = selectedCategoryID {
                    params["category"] = "\(catID)"
                }
                let tagList = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty }
                for (i, tag) in tagList.enumerated() {
                    params["tags[\(i)]"] = tag
                }

                struct CreateTopicResponse: Decodable {
                    let id: Int?
                    let slug: String?
                }

                let resp: CreateTopicResponse = try await HTTPClient.shared.postForm("posts.json", params: params)

                await MainActor.run {
                    isSubmitting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func loadCategories() async {
        guard categories.isEmpty else { return }
        do { categories = try await CategoryService.list().categoryList.categories.filter { !$0.readRestricted } } catch { }
    }
}

struct ScrollableHTMLPreview: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isScrollEnabled = true
        tv.font = UIFont(name: "Times New Roman", size: 15) ?? UIFont.systemFont(ofSize: 15)
        tv.textColor = .label
        tv.backgroundColor = .clear
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if let data = html.data(using: .utf8),
           let attr = try? NSMutableAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue], documentAttributes: nil) {
            uiView.attributedText = attr
        } else {
            uiView.text = html
        }
    }
}