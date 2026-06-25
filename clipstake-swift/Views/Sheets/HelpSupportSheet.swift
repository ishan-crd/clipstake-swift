import SwiftUI

// MARK: - Help & Support Sheet

struct HelpSupportSheet: View {
    @Environment(\.appColors) private var colors
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionManager.self) private var sessionManager

    @State private var view: SheetView = .menu
    @State private var message = ""
    @State private var username = ""
    @State private var sessionUsername = ""
    @State private var isDeleting = false
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    enum SheetView { case menu, message, delete }
    private let maxMessage = 100

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Handle
                Capsule()
                    .fill(colors.divider)
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                Group {
                    switch view {
                    case .menu:  menuContent
                    case .message: messageContent
                    case .delete:  deleteContent
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.conditional, value: view)
            }
            .background(SheetGlassBackground())
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(Radius.xl3)
        }
        .task {
            sessionUsername = sessionManager.currentUser?.username ?? sessionManager.currentUser?.name ?? ""
        }
    }

    // MARK: - Menu

    private var menuContent: some View {
        VStack(spacing: 0) {
            sheetTitle("Help & Support")

            VStack(spacing: 1) {
                menuRow(icon: "calendar", label: "Book a call", isDanger: false) {
                    // Open Calendly
                }
                Divider().padding(.leading, 56)
                menuRow(icon: "bubble.left", label: "Send a message", isDanger: false) {
                    withAnimation(.conditional) { view = .message }
                }
                Divider().padding(.leading, 56)
                menuRow(icon: "person.badge.minus", label: "Deactivate account", isDanger: true) {
                    withAnimation(.conditional) { view = .delete }
                }
            }
            .background(colors.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .padding(.horizontal, Layout.pagePadX)

            Spacer()
        }
    }

    private func menuRow(icon: String, label: String, isDanger: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(isDanger ? colors.error : colors.iconSecondary)
                    .frame(width: 36, height: 36)
                    .background(isDanger ? colors.error.opacity(0.1) : colors.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm))

                Text(label)
                    .font(AppFont.Body.medium(15))
                    .foregroundColor(isDanger ? colors.error : colors.text)

                Spacer()

                if !isDanger {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(colors.textTertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Message

    private var messageContent: some View {
        VStack(spacing: 20) {
            HStack {
                Button { withAnimation(.conditional) { view = .menu } } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(colors.text)
                }
                sheetTitle("Send a message")
                Spacer().frame(width: 24)
            }
            .padding(.horizontal, Layout.pagePadX)

            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    if message.isEmpty {
                        Text("How can we help? (max 100 chars)")
                            .font(AppFont.Body.regular(14))
                            .foregroundColor(colors.textTertiary)
                            .padding(.top, 14)
                            .padding(.leading, 4)
                    }
                    TextEditor(text: $message)
                        .font(AppFont.Body.regular(14))
                        .foregroundColor(colors.text)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 100, maxHeight: 160)
                        .onChange(of: message) { _, v in
                            if v.count > maxMessage { message = String(v.prefix(maxMessage)) }
                        }
                }
                .padding(12)
                .background(colors.bgInput)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(colors.border, lineWidth: 1))

                HStack {
                    Spacer()
                    Text("\(message.count)/\(maxMessage)")
                        .font(AppFont.Body.regular(12))
                        .foregroundColor(message.count == maxMessage ? colors.error : colors.textTertiary)
                }
            }
            .padding(.horizontal, Layout.pagePadX)

            if let msg = successMessage {
                Text(msg)
                    .font(AppFont.Body.regular(13))
                    .foregroundColor(colors.success)
                    .padding(.horizontal, Layout.pagePadX)
            }

            if let err = errorMessage {
                Text(err)
                    .font(AppFont.Body.regular(13))
                    .foregroundColor(colors.error)
                    .padding(.horizontal, Layout.pagePadX)
            }

            AsyncButton(action: sendMessage) {
                Group {
                    if isSending {
                        ProgressView().tint(.white)
                    } else {
                        Text("Send")
                            .font(AppFont.Body.semibold(16))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(colors.accent)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            }
            .disabled(isSending || message.isEmpty)
            .padding(.horizontal, Layout.pagePadX)

            Spacer()
        }
    }

    // MARK: - Delete

    private var deleteContent: some View {
        VStack(spacing: 20) {
            HStack {
                Button { withAnimation(.conditional) { view = .menu } } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(colors.text)
                }
                sheetTitle("Deactivate account")
                Spacer().frame(width: 24)
            }
            .padding(.horizontal, Layout.pagePadX)

            VStack(alignment: .leading, spacing: 8) {
                Text("This will deactivate your account. Your data is preserved and you can reactivate by contacting support.")
                    .font(AppFont.Body.regular(14))
                    .foregroundColor(colors.textSecondary)
                    .padding(.horizontal, Layout.pagePadX)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Type your username to confirm")
                        .font(AppFont.Body.medium(13))
                        .foregroundColor(colors.text)

                    TextField("Username", text: $username)
                        .font(AppFont.Body.regular(14))
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .padding()
                        .background(colors.bgInput)
                        .foregroundColor(colors.text)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                        .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(colors.border, lineWidth: 1))
                }
                .padding(.horizontal, Layout.pagePadX)
            }

            if let err = errorMessage {
                Text(err)
                    .font(AppFont.Body.regular(13))
                    .foregroundColor(colors.error)
                    .padding(.horizontal, Layout.pagePadX)
            }

            HStack(spacing: 12) {
                Button { withAnimation(.conditional) { view = .menu } } label: {
                    Text("Cancel")
                        .font(AppFont.Body.medium(15))
                        .foregroundColor(colors.text)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(colors.bgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                }
                .buttonStyle(PressableButtonStyle())

                AsyncButton(action: deactivateAccount) {
                    Group {
                        if isDeleting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Deactivate")
                                .font(AppFont.Body.semibold(15))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(isDeleting ? colors.error.opacity(0.5) : colors.error)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                }
                .disabled(isDeleting || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, Layout.pagePadX)

            Spacer()
        }
    }

    // MARK: - Title

    private func sheetTitle(_ text: String) -> some View {
        Text(text)
            .font(AppFont.Display.semibold(18))
            .foregroundColor(colors.text)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Actions

    private func sendMessage() async {
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        // In production: call support API
        try? await Task.sleep(nanoseconds: 800_000_000)
        successMessage = "Message sent! We'll get back to you soon."
        message = ""
    }

    private func deactivateAccount() async {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased() == sessionUsername.lowercased() else {
            errorMessage = "Username doesn't match. Please try again."
            return
        }
        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false }
        do {
            struct EmptyResult: Decodable {}
            let _: EmptyResult = try await TRPCClient.shared.mutate("auth.deactivateAccount")
            await sessionManager.signOut()
            dismiss()
        } catch {
            errorMessage = (error as? AppError)?.errorDescription ?? error.localizedDescription
        }
    }
}
