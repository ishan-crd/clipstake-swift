import SwiftUI
import PhotosUI
import UIKit

// MARK: - Bug Report Sheet

struct BugReportSheet: View {
    @Environment(\.appColors) private var colors
    @Environment(\.dismiss) private var dismiss

    @State private var bugText = ""
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var didSubmit = false

    private let maxChars = 500
    private let maxImages = 3

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(colors.divider)
                .frame(width: 40, height: 5)
                .padding(.top, 12)

            ScrollView {
                VStack(spacing: 20) {
                    headerRow
                    descriptionSection
                    screenshotsSection
                    feedbackSection
                    submitButton
                    Spacer(minLength: 40)
                }
            }
        }
        .background(SheetGlassBackground())
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(Radius.xl3)
    }

    // MARK: - Subviews

    private var headerRow: some View {
        HStack {
            Text("Report a bug")
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
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(AppFont.Body.semibold(13))
                .foregroundColor(colors.text)

            ZStack(alignment: .topLeading) {
                if bugText.isEmpty {
                    Text("Describe the bug in detail...")
                        .font(AppFont.Body.regular(14))
                        .foregroundColor(colors.textTertiary)
                        .padding(.top, 14)
                        .padding(.leading, 4)
                }
                TextEditor(text: $bugText)
                    .font(AppFont.Body.regular(14))
                    .foregroundColor(colors.text)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120, maxHeight: 200)
                    .onChange(of: bugText) { _, v in
                        if v.count > maxChars { bugText = String(v.prefix(maxChars)) }
                    }
            }
            .padding(12)
            .background(colors.bgInput)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(colors.border, lineWidth: 1))

            HStack {
                Spacer()
                Text("\(bugText.count)/\(maxChars)")
                    .font(AppFont.Body.regular(12))
                    .foregroundColor(bugText.count == maxChars ? colors.error : colors.textTertiary)
            }
        }
        .padding(.horizontal, Layout.pagePadX)
    }

    private var screenshotsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Screenshots")
                    .font(AppFont.Body.semibold(13))
                    .foregroundColor(colors.text)
                Spacer()
                Text("\(selectedImages.count)/\(maxImages)")
                    .font(AppFont.Body.regular(12))
                    .foregroundColor(colors.textTertiary)
            }

            HStack(spacing: 8) {
                ForEach(selectedImages.indices, id: \.self) { idx in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: selectedImages[idx])
                            .resizable()
                            .scaledToFill()
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md))

                        Button {
                            withAnimation { selectedImages.remove(atOffsets: IndexSet(integer: idx)) }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(colors.error)
                                .background(Circle().fill(Color.white))
                        }
                        .offset(x: 6, y: -6)
                    }
                }

                if selectedImages.count < maxImages {
                    PhotosPicker(
                        selection: $selectedItems,
                        maxSelectionCount: maxImages - selectedImages.count,
                        matching: .images
                    ) {
                        ZStack {
                            RoundedRectangle(cornerRadius: Radius.md)
                                .fill(colors.bgSecondary)
                                .frame(width: 72, height: 72)
                            Image(systemName: "plus")
                                .font(.system(size: 24))
                                .foregroundColor(colors.textTertiary)
                        }
                    }
                    .onChange(of: selectedItems) { _, items in
                        Task { await loadImages(from: items) }
                    }
                }

                Spacer()
            }
        }
        .padding(.horizontal, Layout.pagePadX)
    }

    @ViewBuilder
    private var feedbackSection: some View {
        if let err = errorMessage {
            Text(err)
                .font(AppFont.Body.regular(13))
                .foregroundColor(colors.error)
                .padding(.horizontal, Layout.pagePadX)
        }
        if didSubmit {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(colors.success)
                Text("Bug report submitted! Thank you.")
                    .font(AppFont.Body.regular(13))
                    .foregroundColor(colors.success)
            }
            .padding(.horizontal, Layout.pagePadX)
        }
    }

    private var submitButton: some View {
        AsyncButton(action: submit) {
            Group {
                if isSubmitting {
                    ProgressView().tint(.white)
                } else {
                    Text("Submit report")
                        .font(AppFont.Body.semibold(16))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(isSubmitting ? colors.accent.opacity(0.5) : colors.accent)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        }
        .disabled(isSubmitting || bugText.isEmpty)
        .padding(.horizontal, Layout.pagePadX)
    }

    // MARK: - Helpers

    private func loadImages(from items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                let compressed = img.jpegData(compressionQuality: 0.6)
                    .flatMap { UIImage(data: $0) } ?? img
                selectedImages.append(compressed)
            }
        }
        selectedItems = []
    }

    // MARK: - Submit

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            struct Attachment: Encodable { let data: String; let mimeType: String }
            struct BugPayload: Encodable { let reportText: String; let attachments: [Attachment] }
            let attachments = selectedImages.compactMap { img -> Attachment? in
                guard let data = img.jpegData(compressionQuality: 0.6) else { return nil }
                return Attachment(data: data.base64EncodedString(), mimeType: "image/jpeg")
            }
            struct EmptyResult: Decodable {}
            let _: EmptyResult = try await TRPCClient.shared.mutate(
                "bug.report",
                input: BugPayload(reportText: bugText, attachments: attachments)
            )
            withAnimation {
                didSubmit = true
                bugText = ""
                selectedImages = []
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            dismiss()
        } catch {
            errorMessage = (error as? AppError)?.errorDescription ?? error.localizedDescription
        }
    }
}
