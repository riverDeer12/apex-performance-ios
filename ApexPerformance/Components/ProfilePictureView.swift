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
    // Tapping the picture opens it full screen, like "View" in WhatsApp.
    var opensFullScreen = false

    @State private var image: UIImage?
    @State private var showFullScreen = false

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
        .contentShape(Rectangle())
        .onTapGesture {
            if opensFullScreen, image != nil {
                showFullScreen = true
            }
        }
        .accessibilityAddTraits(opensFullScreen && image != nil ? .isButton : [])
        .fullScreenCover(isPresented: $showFullScreen) {
            if let image {
                ProfilePictureViewer(image: image)
            }
        }
        .task(id: profile?.profilePictureUpdatedAt) {
            await load()
        }
    }

    @MainActor
    private func load() async {
        guard let profile, profile.hasProfilePicture else {
            image = nil
            ProfilePictureStore.shared.image = nil
            return
        }

        do {
            image = try await ProfilePictureStore.loadPicture()
            // Keeps the tab bar picture in step after a change.
            ProfilePictureStore.shared.image = image
        } catch is CancellationError {
            return
        } catch {
            image = nil
        }
    }
}

/// Profile picture of the logged user shown small in the tab bar.
@MainActor
final class ProfilePictureStore: ObservableObject {
    static let shared = ProfilePictureStore()

    @Published var image: UIImage? {
        didSet { tabIcon = image.map { Self.roundIcon(from: $0, size: 28) } }
    }
    // Round picture for the tab bar, drawn in its own colors.
    @Published private(set) var tabIcon: UIImage?

    private init() {}

    /// Loads the logged user's picture, or clears it when there is none.
    func refresh() async {
        do {
            let url = AppEnvironment.apiURL.appendingPathComponent("profile")
            let profile: Profile = try await APIClient.shared.request(url)
            if profile.hasProfilePicture {
                image = try await Self.loadPicture()
            } else {
                image = nil
            }
        } catch {
            // The tab shows the person icon, never another user's picture.
            image = nil
        }
    }

    // Picture API needs the auth header, so it goes through APIClient.
    static func loadPicture() async throws -> UIImage? {
        let url = AppEnvironment.apiURL.appendingPathComponent("profile/picture")
        let data = try await APIClient.shared.requestData(url, headers: ["Accept": "image/*"])
        return UIImage(data: data)
    }

    private static func roundIcon(from image: UIImage, size: CGFloat) -> UIImage {
        let bounds = CGRect(x: 0, y: 0, width: size, height: size)
        let rendered = UIGraphicsImageRenderer(size: bounds.size).image { _ in
            UIBezierPath(ovalIn: bounds).addClip()
            // Aspect fill, centered.
            let scale = max(size / image.size.width, size / image.size.height)
            let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            image.draw(in: CGRect(
                x: (size - drawSize.width) / 2,
                y: (size - drawSize.height) / 2,
                width: drawSize.width,
                height: drawSize.height
            ))
        }
        return rendered.withRenderingMode(.alwaysOriginal)
    }
}

/// Full screen profile picture with pinch and double tap to zoom,
/// drag to move when zoomed, and swipe down or close to dismiss.
struct ProfilePictureViewer: View {
    let image: UIImage

    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    // Vertical drag while not zoomed, used to dismiss.
    @State private var dismissDrag: CGFloat = 0

    private let maxScale: CGFloat = 4

    var body: some View {
        ZStack {
            Color.black
                .opacity(1 - min(abs(dismissDrag) / 400, 0.6))
                .ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(x: offset.width, y: offset.height + dismissDrag)
                .gesture(zoomGesture.simultaneously(with: dragGesture))
                .onTapGesture(count: 2) {
                    withAnimation(.spring(duration: 0.3)) {
                        if scale > 1 {
                            resetZoom()
                        } else {
                            scale = 2.5
                            lastScale = 2.5
                        }
                    }
                }
                .accessibilityLabel(Text("profile_picture"))

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(.black.opacity(0.4)))
                    }
                    .accessibilityLabel(Text("close"))
                    Spacer()
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .opacity(dismissDrag == 0 ? 1 : 0)
        }
        .statusBarHidden()
        // The app shows through while swiping down to close.
        .presentationBackground(.clear)
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(max(lastScale * value.magnification, 1), maxScale)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1 {
                    withAnimation(.spring(duration: 0.3)) { resetZoom() }
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > 1 {
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                } else {
                    dismissDrag = value.translation.height
                }
            }
            .onEnded { value in
                if scale > 1 {
                    lastOffset = offset
                } else if abs(value.translation.height) > 120 {
                    dismiss()
                } else {
                    withAnimation(.spring(duration: 0.3)) { dismissDrag = 0 }
                }
            }
    }

    private func resetZoom() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
    }
}

#Preview {
    HStack(spacing: 16) {
        ProfilePictureView(profile: .previewClient)
        ProfilePictureView(profile: .previewClient, size: 96)
    }
    .padding()
}
