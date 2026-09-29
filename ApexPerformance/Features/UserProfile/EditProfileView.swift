//
//  EditProfileView.swift
//  ApexPerformance
//

import SwiftUI
import PhotosUI
import UIKit

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var toastManager: ToastManager

    // Called with the latest profile after saving data or changing the picture.
    var onProfileChanged: ((Profile) -> Void)? = nil

    @State private var profile: Profile
    @State private var firstName: String
    @State private var lastName: String
    @State private var phone: String
    @State private var email: String

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isSaving = false
    @State private var isUpdatingPicture = false
    @State private var showRemovePictureDialog = false

    // Same limits as the web app: longer side at most 512 px,
    // API accepts pictures up to 2 MB.
    private static let pictureMaxDimension: CGFloat = 512
    private static let maxUploadedPictureBytes = 2 * 1024 * 1024

    init(profile: Profile, onProfileChanged: ((Profile) -> Void)? = nil) {
        self.onProfileChanged = onProfileChanged
        _profile = State(initialValue: profile)
        _firstName = State(initialValue: profile.firstName ?? "")
        _lastName = State(initialValue: profile.lastName ?? "")
        _phone = State(initialValue: profile.phone ?? "")
        _email = State(initialValue: profile.email)
    }

    private var isValid: Bool {
        if trimmed(email).isEmpty { return false }
        if profile.hasPersonalData && (trimmed(firstName).isEmpty || trimmed(lastName).isEmpty) { return false }
        if profile.hasPhone && trimmed(phone).isEmpty { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        ZStack {
                            ProfilePictureView(profile: profile, size: 96)
                            if isUpdatingPicture {
                                ProgressView()
                            }
                        }

                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Text(LocalizedStringKey(profile.hasProfilePicture ? "change_profile_picture" : "upload_profile_picture"))
                                .foregroundStyle(Color.apexMainColor)
                        }
                        .buttonStyle(.borderless)

                        if profile.hasProfilePicture {
                            Button("remove_profile_picture", role: .destructive) {
                                showRemovePictureDialog = true
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(isUpdatingPicture)
                }

                if profile.hasPersonalData {
                    Section(header: Text("personal_info")) {
                        TextField("first_name", text: $firstName)
                            .textContentType(.givenName)
                        TextField("last_name", text: $lastName)
                            .textContentType(.familyName)
                        if profile.hasPhone {
                            TextField("mobile_phone", text: $phone)
                                .textContentType(.telephoneNumber)
                                .keyboardType(.phonePad)
                        }
                    }
                }

                Section(header: Text("contact")) {
                    TextField("email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("edit_profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        ZStack {
                            if isSaving {
                                ProgressView().scaleEffect(0.9)
                            } else {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.apexMainColor)
                            }
                        }
                    }
                    .disabled(isSaving || !isValid)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.backward")
                            .foregroundStyle(Color.apexMainColor)
                    }
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                Task { await uploadPicture(item) }
            }
            .confirmationDialog("remove_profile_picture_question", isPresented: $showRemovePictureDialog) {
                Button("remove_profile_picture", role: .destructive) {
                    Task { await removePicture() }
                }
                Button("cancel", role: .cancel) {}
            }
        }
    }

    // MARK: - Profile data

    @MainActor
    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let request = UpdateProfileRequest(
            email: trimmed(email),
            firstName: profile.hasPersonalData ? trimmed(firstName) : nil,
            lastName: profile.hasPersonalData ? trimmed(lastName) : nil,
            phone: profile.hasPhone ? trimmed(phone) : nil
        )

        do {
            let url = AppEnvironment.apiURL.appendingPathComponent("profile")
            let updated: Profile = try await APIClient.shared.request(
                url,
                method: .put,
                body: JSONEncoder().encode(request)
            )
            profile = updated
            onProfileChanged?(updated)
            toastManager.show("profile_updated_successfully", type: .success)
            dismiss()
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }

    // MARK: - Profile picture

    @MainActor
    private func uploadPicture(_ item: PhotosPickerItem) async {
        isUpdatingPicture = true
        defer {
            isUpdatingPicture = false
            selectedPhoto = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let jpeg = Self.resizedJPEG(from: data) else {
                toastManager.show("invalid_profile_picture", type: .error)
                return
            }

            guard jpeg.count <= Self.maxUploadedPictureBytes else {
                toastManager.show("profile_picture_too_large", type: .error)
                return
            }

            let boundary = "Boundary-\(UUID().uuidString)"

            var body = Data()
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"profile-picture.jpg\"\r\n".utf8))
            body.append(Data("Content-Type: image/jpeg\r\n\r\n".utf8))
            body.append(jpeg)
            body.append(Data("\r\n--\(boundary)--\r\n".utf8))

            let url = AppEnvironment.apiURL.appendingPathComponent("profile/picture")
            try await APIClient.shared.requestData(
                url,
                method: .put,
                body: body,
                headers: ["Content-Type": "multipart/form-data; boundary=\(boundary)"]
            )

            await reloadProfile()
            toastManager.show("profile_picture_updated_successfully", type: .success)
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }

    @MainActor
    private func removePicture() async {
        isUpdatingPicture = true
        defer { isUpdatingPicture = false }

        do {
            let url = AppEnvironment.apiURL.appendingPathComponent("profile/picture")
            try await APIClient.shared.requestData(url, method: .delete)

            await reloadProfile()
            toastManager.show("profile_picture_removed_successfully", type: .success)
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }

    // Picture changes are saved right away, so the profile screen
    // gets the new picture even if the form is not saved.
    @MainActor
    private func reloadProfile() async {
        do {
            let url = AppEnvironment.apiURL.appendingPathComponent("profile")
            let updated: Profile = try await APIClient.shared.request(url)
            profile = updated
            onProfileChanged?(updated)
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }

    /// Scale picture down so the longer side is at most 512 px and
    /// encode it as JPEG. Transparent areas are filled with white.
    private static func resizedJPEG(from data: Data) -> Data? {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else {
            return nil
        }

        let scale = min(1, pictureMaxDimension / max(image.size.width, image.size.height))
        let size = CGSize(
            width: (image.size.width * scale).rounded(),
            height: (image.size.height * scale).rounded()
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let resized = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            image.draw(in: CGRect(origin: .zero, size: size))
        }

        return resized.jpegData(compressionQuality: 0.85)
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview("Client") {
    EditProfileView(profile: .previewClient)
        .environmentObject(ToastManager())
}

#Preview("Super admin") {
    EditProfileView(profile: .previewSuperAdmin)
        .environmentObject(ToastManager())
}
