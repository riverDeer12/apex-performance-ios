//
//  UserAvatarView.swift
//  ApexPerformance
//

import SwiftUI
import UIKit

/// Round profile picture of a client, coach or administrator, with their
/// initials while it loads or when they have none. `pictureUrl` is the
/// API's link ("users/{id}/picture?v=..."), it changes with the picture.
struct UserAvatarView: View {
    let name: String
    var pictureUrl: String? = nil
    var size: CGFloat = 44
    // Tapping the picture opens it full screen.
    var opensFullScreen = false

    @State private var image: UIImage?
    @State private var showFullScreen = false

    init(name: String, pictureUrl: String? = nil, size: CGFloat = 44, opensFullScreen: Bool = false) {
        self.name = name
        self.pictureUrl = pictureUrl
        self.size = size
        self.opensFullScreen = opensFullScreen
        // Pictures seen before show at once, without the initials flashing.
        _image = State(initialValue: UserPictureCache.shared.cachedImage(for: pictureUrl))
    }

    private var initials: String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }

    var body: some View {
        if opensFullScreen {
            avatar
                .onTapGesture {
                    if image != nil { showFullScreen = true }
                }
                .accessibilityHidden(image == nil)
                .accessibilityLabel(Text("profile_picture"))
                .accessibilityAddTraits(image != nil ? .isButton : [])
                .fullScreenCover(isPresented: $showFullScreen) {
                    if let image {
                        ProfilePictureViewer(image: image)
                    }
                }
        } else {
            // No gesture here, so taps reach the row it is in.
            avatar.accessibilityHidden(true)
        }
    }

    private var avatar: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle().fill(Color.apexAccent)
                Text(verbatim: initials.isEmpty ? "?" : initials)
                    .font(.system(size: size * 0.36, weight: .bold))
                    .foregroundStyle(Color.apexOnAccent)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .contentShape(Circle())
        .task(id: pictureUrl) {
            image = await UserPictureCache.shared.image(for: pictureUrl)
        }
    }
}

/// Picture and name of a person, e.g. a row of a client picker.
struct UserNameLabel: View {
    let name: String
    var pictureUrl: String? = nil
    var size: CGFloat = 30

    var body: some View {
        HStack(spacing: 10) {
            UserAvatarView(name: name, pictureUrl: pictureUrl, size: size)
            Text(verbatim: name)
        }
    }
}

/// Pictures of several people (e.g. a group appointment), overlapping;
/// the first `maxShown` are drawn, the rest as "+N".
struct UserAvatarStack: View {
    let people: [(name: String, pictureUrl: String?)]
    var size: CGFloat = 40
    var maxShown = 3

    var body: some View {
        let shown = Array(people.prefix(people.count > maxShown ? maxShown - 1 : maxShown))
        let rest = people.count - shown.count
        // One person fills the whole size; more share it, overlapping.
        let itemSize = people.count > 1 ? size * 0.72 : size
        HStack(spacing: -itemSize * 0.4) {
            ForEach(Array(shown.enumerated()), id: \.offset) { _, person in
                UserAvatarView(name: person.name, pictureUrl: person.pictureUrl, size: itemSize)
                    .overlay(Circle().stroke(Color.apexCard, lineWidth: people.count > 1 ? 2 : 0))
            }
            if rest > 0 {
                Text(verbatim: "+\(rest)")
                    .font(.system(size: itemSize * 0.34, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: itemSize, height: itemSize)
                    .background(Circle().fill(Color(.systemGray5)))
                    .overlay(Circle().stroke(Color.apexCard, lineWidth: 2))
            }
        }
        .accessibilityHidden(true)
    }
}

extension View {
    /// Small round icon on the bottom right of an avatar, e.g. the status of
    /// an appointment or the type of a request.
    func avatarBadge(systemImage: String, tint: Color, size: CGFloat = 18) -> some View {
        overlay(alignment: .bottomTrailing) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.55, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Circle().fill(tint))
                .overlay(Circle().stroke(Color.apexCard, lineWidth: 1.5))
                .offset(x: 3, y: 3)
                .accessibilityHidden(true)
        }
    }
}

/// Profile pictures of other users loaded so far. Kept in memory while the
/// app runs; the API lets URLSession keep them on disk for a week too.
final class UserPictureCache: @unchecked Sendable {
    static let shared = UserPictureCache()

    private let images = NSCache<NSString, UIImage>()
    @MainActor private var loading: [String: Task<UIImage?, Never>] = [:]

    private init() {
        images.countLimit = 300
    }

    func cachedImage(for pictureUrl: String?) -> UIImage? {
        guard let pictureUrl else { return nil }
        return images.object(forKey: pictureUrl as NSString)
    }

    /// The picture, or nil when there is none or it can't be loaded
    /// (the initials stay then).
    @MainActor
    func image(for pictureUrl: String?) async -> UIImage? {
        guard let pictureUrl, let url = Self.url(for: pictureUrl) else { return nil }
        if let cached = cachedImage(for: pictureUrl) { return cached }
        if let task = loading[pictureUrl] { return await task.value }

        let task = Task<UIImage?, Never> {
            guard let data = try? await APIClient.shared.requestData(url, headers: ["Accept": "image/*"]),
                  let image = UIImage(data: data) else { return nil }
            return image.preparingForDisplay() ?? image
        }
        loading[pictureUrl] = task
        let image = await task.value
        loading[pictureUrl] = nil
        if let image {
            images.setObject(image, forKey: pictureUrl as NSString)
        }
        return image
    }

    /// Link from the API is relative to the API url ("users/{id}/picture?v=...").
    static func url(for pictureUrl: String) -> URL? {
        if pictureUrl.hasPrefix("http") { return URL(string: pictureUrl) }
        var base = AppEnvironment.apiURL.absoluteString
        if base.hasSuffix("/") { base.removeLast() }
        let path = pictureUrl.hasPrefix("/") ? String(pictureUrl.dropFirst()) : pictureUrl
        return URL(string: "\(base)/\(path)")
    }
}

#Preview {
    HStack(spacing: 16) {
        UserAvatarView(name: "Ana Kovač")
        UserAvatarView(name: "Luka Marić", size: 64)
    }
    .padding()
}
