//
//  EditPostPage.swift
//  LinuxDo
//
//  编辑帖子 — 对照 fluxdo edit_topic_page
//

import SwiftUI

struct EditPostPage: View {
    let postID: Int
    let postNumber: Int
    let topicID: Int

    @Environment(\.dismiss) private var dismiss
    @State private var rawBody = ""
    @State private var isSubmitting = false
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else {
                    Form {
                        Section {
                            TextEditor(text: $rawBody)
                                .font(DesignTypography.serifBody)
                                .frame(minHeight: 200)
                                .scrollContentBackground(.hidden)
                        } header: {
                            Text("编辑 #\(postNumber)")
                                .font(DesignTypography.serifCaption)
                        }
                    }
                }
            }
            .navigationTitle("编辑帖子")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSubmitting ? "" : "保存") { submitEdit() }
                        .disabled(rawBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting || isLoading)
                        .fontWeight(.semibold)
                }
            }
            .overlay { if isSubmitting { ProgressView() } }
            .alert("编辑失败", isPresented: .constant(errorMessage != nil)) {
                Button("确定") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .task { await loadRawContent() }
        }
    }

    private func loadRawContent() async {
        do {
            struct PostDetailResponse: Decodable {
                let raw: String?
            }
            let resp: PostDetailResponse = try await HTTPClient.shared.get("posts/\(postID).json")
            rawBody = resp.raw ?? ""
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func submitEdit() {
        let body = rawBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }

        isSubmitting = true
        Task {
            do {
                struct EditResponse: Decodable { let id: Int? }
                let _: EditResponse = try await HTTPClient.shared.putForm(
                    "posts/\(postID).json",
                    params: ["post[raw]": body]
                )
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
}