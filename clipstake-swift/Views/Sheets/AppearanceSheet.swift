import SwiftUI

// MARK: - Appearance Sheet

struct AppearanceSheet: View {
    @Environment(\.appColors) private var colors
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(colors.divider)
                .frame(width: 40, height: 5)
                .padding(.top, 12)

            VStack(spacing: 20) {
                HStack {
                    Text("Appearance")
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

                Text("Choose how ClipStake looks to you.")
                    .font(AppFont.Body.regular(14))
                    .foregroundColor(colors.textSecondary)
                    .padding(.horizontal, Layout.pagePadX)

                // Mode picker
                VStack(spacing: 8) {
                    ForEach(ThemeMode.allCases, id: \.rawValue) { mode in
                        themeOption(mode)
                    }
                }
                .padding(.horizontal, Layout.pagePadX)

                Spacer(minLength: 40)
            }
        }
        .background(SheetGlassBackground())
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(Radius.xl3)
    }

    private func themeOption(_ mode: ThemeMode) -> some View {
        let isSelected = themeManager.mode == mode

        return Button {
            themeManager.setMode(mode)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: themeIcon(mode))
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? colors.accent : colors.iconSecondary)
                    .frame(width: 36, height: 36)
                    .background(isSelected ? colors.bgAccent : colors.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm))

                Text(mode.label)
                    .font(AppFont.Body.medium(15))
                    .foregroundColor(colors.text)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(colors.accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? colors.bgAccent : colors.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .stroke(isSelected ? colors.accent.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .animation(.conditional, value: themeManager.mode)
    }

    private func themeIcon(_ mode: ThemeMode) -> String {
        switch mode {
        case .light:  "sun.max"
        case .dark:   "moon"
        case .system: "circle.lefthalf.filled"
        }
    }
}
