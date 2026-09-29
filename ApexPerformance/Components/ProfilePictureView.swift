//
//  ProfilePictureView.swift
//  ApexPerformance
//

import SwiftUI
import UIKit

// Profile picture of the logged user. Picture API needs the auth
// header, so it is loaded through APIClient instead of AsyncImage.
struct ProfilePictureView: View {
    let profile: Profile?
    var size: CGFloat = 60

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size / 6, style: .continuous)
                .fill(Color.apexMainColor.opacity(0.25))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person")
                    .font(.system(size: size / 3, weight: .semibold))
                    .foregroundStyle(Color.apexMainColor)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size / 6, style: .continuous))
        .task(id: profile?.profilePictureUpdatedAt) {
            await load()
        }
    }

    @MainActor
    private func load() async {
        guard let profile, profile.hasProfilePicture else {
            image = nil
            return
        }

        do {
            let url = AppEnvironment.apiURL.appendingPathComponent("profile/picture")
            let data = try await APIClient.shared.requestData(url, headers: ["Accept": "image/*"])
            image = UIImage(data: data)
        } catch is CancellationError {
            return
        } catch {
            image = nil
        }
    }
}
