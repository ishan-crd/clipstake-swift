import SwiftUI
import PhotosUI
import UIKit

// MARK: - Personal Info Sheet

struct PersonalInfoSheet: View {
    let user: AppUser
    let onSave: (AppUser) -> Void

    @Environment(\.appColors) private var colors
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var selectedItem: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(user: AppUser, onSave: @escaping (AppUser) -> Void) {
        self.user = user
        self.onSave = onSave
        self._name = State(initialValue: user.name)
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(colors.divider)
                .frame(width: 40, height: 5)
                .padding(.top, 12)

            ScrollView {
                VStack(spacing: 24) {
                    HStack {
                        Text("Personal information")
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

                    // Avatar picker
                    VStack(spacing: 8) {
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            ZStack(alignment: .bottomTrailing) {
                                Group {
                                    if let img = avatarImage {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFill()
                                    } else if let urlStr = user.image, let url = URL(string: urlStr) {
                                        AsyncImage(url: url) { phase in
                                            if case .success(let img) = phase {
                                                img.resizable().scaledToFill()
                                            } else {
                                                Image("pfp").resizable().scaledToFill()
                                            }
                                        }
                                    } else {
                                        Image("pfp").resizable().scaledToFill()
                                    }
                                }
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())

                                Image(systemName: "camera.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                                    .frame(width: 28, height: 28)
                                    .background(colors.accent)
                                    .clipShape(Circle())
                            }
                        }
                        .buttonStyle(PressableButtonStyle())
                        .onChange(of: selectedItem) { _, item in
                            Task {
                                if let data = try? await item?.loadTransferable(type: Data.self),
                                   let img = UIImage(data: data) {
                                    let compressed = img.jpegData(compressionQuality: 0.7).flatMap { UIImage(data: $0) } ?? img
                                    avatarImage = compressed
                                }
                            }
                        }

                        Text("Tap to change photo")
                            .font(AppFont.Body.regular(12))
                            .foregroundColor(colors.textTertiary)
                    }

                    // Name field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Display name")
                            .font(AppFont.Body.semibold(13))
                            .foregroundColor(colors.text)

                        TextField("Your name", text: $name)
                            .font(AppFont.Body.regular(15))
                            .foregroundColor(colors.text)
                            .padding()
                            .background(colors.bgInput)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                            .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(colors.border, lineWidth: 1))
                    }
                    .padding(.horizontal, Layout.pagePadX)

                    if let err = errorMessage {
                        Text(err)
                            .font(AppFont.Body.regular(13))
                            .foregroundColor(colors.error)
                            .padding(.horizontal, Layout.pagePadX)
                    }

                    AsyncButton(action: save) {
                        Group {
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Text("Save changes")
                                    .font(AppFont.Body.semibold(16))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(colors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                    }
                    .disabled(isSaving)
                    .padding(.horizontal, Layout.pagePadX)

                    Spacer(minLength: 40)
                }
            }
        }
        .background(SheetGlassBackground())
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(Radius.xl3)
    }

    // MARK: - Save

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            var imageURL: String? = user.image

            // Upload avatar if changed
            if let img = avatarImage, let imageData = img.jpegData(compressionQuality: 0.7) {
                struct PresignInput: Encodable { let contentType: String; let folder: String }
                let presigned: PresignedUrlResponse = try await TRPCClient.shared.query(
                    "upload.getPresignedUrl",
                    input: PresignInput(contentType: "image/jpeg", folder: "avatars")
                )

                var uploadReq = URLRequest(url: URL(string: presigned.url)!)
                uploadReq.httpMethod = "PUT"
                uploadReq.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
                uploadReq.httpBody = imageData
                _ = try await URLSession.shared.data(for: uploadReq)
                imageURL = "https://cdn.clipstake.com/\(presigned.key)"
            }

            struct UpdateInput: Encodable { let name: String; let image: String? }
            let updated: AppUser = try await TRPCClient.shared.mutate(
                "user.updateProfile",
                input: UpdateInput(name: name.trimmingCharacters(in: .whitespacesAndNewlines), image: imageURL)
            )
            onSave(updated)
            dismiss()
        } catch {
            errorMessage = (error as? AppError)?.errorDescription ?? error.localizedDescription
        }
    }
}
