//
//  AuthViewModel.swift
//  LinuxDo
//
//  登录状态管理
//  监听 SessionStore 变化，驱动 UI 更新
//

import Foundation
import SwiftUI

@Observable
final class AuthViewModel {
    private(set) var currentUser: User?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var isLoggedIn: Bool { SessionStore.shared.isLoggedIn }

    /// 应用启动时恢复会话
    func restoreSession() async {
        guard SessionStore.shared.restoreFromKeychain() else { return }
        await fetchCurrentUser()
    }

    /// 登录后刷新当前用户
    func fetchCurrentUser() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let resp = try await UserService.shared.currentUser()
            currentUser = resp.currentUser
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            // 如果 session 失效，登出
            if case APIError.notLoggedIn = error {
                SessionStore.shared.logout()
                currentUser = nil
            }
        }
    }

    func logout() {
        SessionStore.shared.logout()
        currentUser = nil
    }
}
