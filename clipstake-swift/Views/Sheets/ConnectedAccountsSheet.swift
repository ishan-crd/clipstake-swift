import SwiftUI

// MARK: - Connected Accounts Sheet

struct ConnectedAccountsSheet: View {
    @Environment(\.appColors) private var colors
    @Environment(\.dismiss) private var dismiss

    @State private var connectedProviders: Set<String> = []
    @State private var isLoading = true

    private let providers = [
        Provider(id: "google", name: "Google", icon: "globe"),
        Provider(id: "apple", name: "Apple", icon: "apple.logo"),
        Provider(id: "discord", name: "Discord", icon: "gamecontroller")
    ]

    struct Provider: Identifiable {
        let id: String
        let name: String
        let icon: String
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(colors.divider)
                .frame(width: 40, height: 5)
                .padding(.top, 12)

            VStack(spacing: 20) {
                HStack {
                    Text("Connected accounts")
                        .font(AppFont.Display.semibold(20))
                        .foregroundColor(colors.text)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(colors.textTertiary)
                    }
                }
                .padding(.horizontal, Layout.pagePadX)
                .padding(.top, 16)

                Text("Connect social accounts to enable additional sign-in methods.")
                    .font(AppFont.Body.regular(14))
                    .foregroundColor(colors.textSecondary)
                    .padding(.horizontal, Layout.pagePadX)

                VStack(spacing: 1) {
                    ForEach(providers) { provider in
                        let isConnected = connectedProviders.contains(provider.id)
                        HStack(spacing: 12) {
                            Image(systemName: provider.icon)
                                .font(.system(size: 18))
                                .foregroundColor(colors.text)
                                .frame(width: 36, height: 36)
                                .background(colors.bgSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.sm))

                            Text(provider.name)
                                .font(AppFont.Body.medium(15))
                                .foregroundColor(colors.text)

                            Spacer()

                            if isLoading {
                                SkeletonRect(height: 28).frame(width: 80)
                            } else if isConnected {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(colors.success)
                                    Text("Connected")
                                        .font(AppFont.Body.regular(12))
                                        .foregroundColor(colors.success)
                                }
                            } else {
                                Button("Connect") {}
                                    .font(AppFont.Body.medium(13))
                                    .foregroundColor(colors.accent)
                                    .buttonStyle(PressableButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)

                        if provider.id != providers.last?.id {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .background(colors.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                .padding(.horizontal, Layout.pagePadX)

                Spacer(minLength: 40)
            }
        }
        .background(SheetGlassBackground())
        .presentationDetents([.height(380)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(Radius.xl3)
        .task {
            // In production, fetch connected accounts from API
            try? await Task.sleep(nanoseconds: 300_000_000)
            isLoading = false
            connectedProviders = ["google"]
        }
    }
}
