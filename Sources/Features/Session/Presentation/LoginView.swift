import SwiftUI

enum SessionAccessibilityID {
    static let accountState = "session.account.state"
    static let loginButton = "session.account.login"
    static let loginCancel = "session.login.cancel"
    static let loginError = "session.login.error"
    static let loginWebView = "session.login.web-view"
    static let logoutButton = "session.account.logout"
}

@MainActor
struct LoginView: View {
    @Bindable var store: SessionStore
    let webSession: LoginWebSession
    let cancel: () -> Void
    let completed: () -> Void

    @State private var webFailure = false

    var body: some View {
        NavigationStack {
            LoginWebView(
                session: webSession,
                onCookiesDetected: submit,
                onIncompleteCookies: showIncomplete,
                onNavigationFailure: {
                    webFailure = true
                }
            )
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let message = errorMessage {
                    Text(message)
                        .font(Typography.font(.caption))
                        .foregroundStyle(SemanticColor.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(Spacing.small)
                        .background(SemanticColor.surface)
                        .accessibilityIdentifier(
                            SessionAccessibilityID.loginError
                        )
                }
            }
            .background(SemanticColor.background)
            .navigationTitle("登录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭", action: cancel)
                        .accessibilityIdentifier(
                            SessionAccessibilityID.loginCancel
                        )
                }
            }
        }
    }

    private var errorMessage: String? {
        if webFailure {
            return "登录页面暂时无法加载，请稍后重试。"
        }
        guard case let .failed(failure) = store.state else {
            return nil
        }
        switch failure {
        case .loginIncomplete:
            return "登录尚未完成，请在网页中完成验证。"
        case .credentialStore:
            return "无法安全保存会话，请重试。"
        case .logout:
            return nil
        }
    }

    private func showIncomplete() {
        Task {
            await store.completeLogin(
                LoginCookieValues(bduss: nil, stoken: nil)
            )
        }
    }

    private func submit(_ cookies: LoginCookieValues) {
        webFailure = false
        Task {
            await store.completeLogin(cookies)
            if store.state == .signedIn {
                completed()
            }
        }
    }
}

@MainActor
struct SessionAccountView: View {
    @Bindable var store: SessionStore
    let openLogin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Label("账户", systemImage: "person.crop.circle")
                .font(Typography.font(.headline))
                .foregroundStyle(SemanticColor.primaryText)

            Text(stateText)
                .font(Typography.font(.body))
                .foregroundStyle(SemanticColor.secondaryText)
                .accessibilityIdentifier(
                    SessionAccessibilityID.accountState
                )

            actionButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.medium)
        .background(SemanticColor.surface)
        .clipShape(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
        )
    }

    private var stateText: String {
        switch store.state {
        case .signedOut:
            "未登录"
        case .signingIn:
            "正在登录"
        case .signingOut:
            "正在安全退出"
        case .signedIn:
            "已登录"
        case .expired:
            "会话已失效，请重新登录"
        case let .failed(failure):
            switch failure {
            case .loginIncomplete:
                "登录尚未完成"
            case .credentialStore:
                "会话保存失败"
            case .logout:
                "退出登录未完全清理，请重试"
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch store.state {
        case .signedIn:
            Button("退出登录", role: .destructive) {
                Task {
                    await store.logout()
                }
            }
            .disabled(store.isBusy)
            .accessibilityIdentifier(SessionAccessibilityID.logoutButton)
        case .signingIn:
            ProgressView("等待网页登录")
        case .signingOut:
            ProgressView("正在清理会话")
        case .failed(.logout):
            Button("重试退出登录", role: .destructive) {
                Task {
                    await store.logout()
                }
            }
            .disabled(store.isBusy)
            .accessibilityIdentifier(SessionAccessibilityID.logoutButton)
        case .signedOut, .expired, .failed:
            Button("登录", action: openLogin)
                .buttonStyle(.borderedProminent)
                .disabled(store.isBusy)
                .accessibilityIdentifier(SessionAccessibilityID.loginButton)
        }
    }
}
