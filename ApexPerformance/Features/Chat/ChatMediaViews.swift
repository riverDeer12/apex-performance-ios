//
//  ChatMediaViews.swift
//  ApexPerformance
//

import ImageIO
import SwiftUI
import UIKit

/// Picture ready to send: photos are shrunk to JPEG, GIFs are kept as
/// they are so they stay animated.
struct ChatImageUpload {
    let data: Data
    let contentType: String
    let fileName: String
    let width: Int
    let height: Int

    // Same limit as the API.
    static let maxBytes = 10 * 1024 * 1024
    private static let maxDimension: CGFloat = 1600

    static func prepare(_ data: Data) -> ChatImageUpload? {
        if data.starts(with: Array("GIF8".utf8)) {
            guard data.count <= maxBytes, let size = pixelSize(of: data) else { return nil }
            return ChatImageUpload(data: data, contentType: "image/gif", fileName: "image.gif",
                                   width: size.width, height: size.height)
        }

        guard let image = UIImage(data: data) else { return nil }
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let jpeg = resized.jpegData(compressionQuality: 0.8), jpeg.count <= maxBytes else { return nil }
        return ChatImageUpload(data: jpeg, contentType: "image/jpeg", fileName: "image.jpg",
                               width: Int(size.width), height: Int(size.height))
    }

    private static func pixelSize(of data: Data) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return (width, height)
    }
}

/// Pictures of messages loaded so far, kept while the app runs.
@MainActor
final class ChatAttachmentCache {
    static let shared = ChatAttachmentCache()

    private let cache = NSCache<NSUUID, NSData>()
    private var loading: [UUID: Task<Data, Error>] = [:]

    func data(for attachment: ChatAttachment, conversationId: UUID) async throws -> Data {
        if let cached = cache.object(forKey: attachment.id as NSUUID) {
            return cached as Data
        }
        if let task = loading[attachment.id] {
            return try await task.value
        }
        let task = Task { try await ChatAPI.attachment(attachment.id, conversationId: conversationId) }
        loading[attachment.id] = task
        defer { loading[attachment.id] = nil }
        let data = try await task.value
        cache.setObject(data as NSData, forKey: attachment.id as NSUUID)
        return data
    }
}

/// Picture of a message; GIFs are animated. Tapping opens it full screen.
struct ChatImageBubble: View {
    let attachment: ChatAttachment
    let conversationId: UUID

    @State private var data: Data?
    @State private var failed = false
    @State private var showsViewer = false

    private static let maxWidth: CGFloat = 240

    private var aspectRatio: CGFloat {
        guard let width = attachment.width, let height = attachment.height, width > 0, height > 0 else {
            return 4 / 3
        }
        return CGFloat(width) / CGFloat(height)
    }

    var body: some View {
        Button {
            if data != nil { showsViewer = true }
        } label: {
            ZStack {
                Color.apexCard
                if let data {
                    ChatPictureView(data: data, isGIF: attachment.isGIF, contentMode: .scaleAspectFill)
                } else if failed {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                }
            }
            .frame(width: Self.maxWidth, height: Self.maxWidth / max(0.5, min(aspectRatio, 2)))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(attachment.isGIF ? "chat_gif" : "chat_photo"))
        .task(id: attachment.id) {
            do {
                data = try await ChatAttachmentCache.shared.data(for: attachment, conversationId: conversationId)
            } catch {
                failed = true
            }
        }
        .fullScreenCover(isPresented: $showsViewer) {
            if let data {
                ChatImageViewer(data: data, isGIF: attachment.isGIF)
            }
        }
    }
}

/// Full screen picture with a close button.
private struct ChatImageViewer: View {
    let data: Data
    let isGIF: Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            ChatPictureView(data: data, isGIF: isGIF, contentMode: .scaleAspectFit)
                .ignoresSafeArea()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.black.opacity(0.4)))
            }
            .padding()
            .accessibilityLabel(Text("close"))
        }
    }
}

/// Still or animated picture from data (SwiftUI's Image doesn't animate GIFs).
struct ChatPictureView: UIViewRepresentable {
    let data: Data
    let isGIF: Bool
    let contentMode: UIView.ContentMode

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.clipsToBounds = true
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return view
    }

    func updateUIView(_ view: UIImageView, context: Context) {
        view.contentMode = contentMode
        view.image = isGIF ? Self.animatedImage(data) : UIImage(data: data)
    }

    private static func animatedImage(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return UIImage(data: data) }
        let count = CGImageSourceGetCount(source)
        guard count > 1 else { return UIImage(data: data) }

        var frames: [UIImage] = []
        var duration: Double = 0
        for index in 0..<count {
            guard let frame = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            frames.append(UIImage(cgImage: frame))
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
            let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let delay = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
                ?? (gif?[kCGImagePropertyGIFDelayTime] as? Double) ?? 0.1
            duration += delay < 0.02 ? 0.1 : delay
        }
        return UIImage.animatedImage(with: frames, duration: duration)
    }
}

/// Workout a coach shared; opens the workout.
struct ChatWorkoutCard: View {
    let workout: Workout?

    var body: some View {
        if let workout {
            NavigationLink {
                WorkoutDetailView(workout: workout, canEdit: false, onSaved: { _ in })
            } label: {
                content(title: Text(verbatim: workout.name.localized), thumbnail: workout.thumbnailUrl)
            }
            .buttonStyle(.plain)
        } else {
            content(title: Text("chat_workout_unavailable"), thumbnail: nil)
        }
    }

    private func content(title: Text, thumbnail: String?) -> some View {
        HStack(spacing: 10) {
            WorkoutThumbnailView(url: thumbnail)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("chat_shared_workout")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                title
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            if workout != nil {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(width: 240)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.apexCard))
    }
}

/// Searchable workouts; tapping one shares it.
struct ChatWorkoutPickerView: View {
    let onPick: (Workout) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var toastManager: ToastManager
    @State private var workouts: [Workout] = []
    @State private var searchText = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            List(workouts.filter { $0.matches(searchText) }) { workout in
                Button {
                    onPick(workout)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        WorkoutThumbnailView(url: workout.thumbnailUrl)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        Text(verbatim: workout.name.localized)
                            .foregroundStyle(Color.primary)
                    }
                }
            }
            .overlay {
                if isLoading && workouts.isEmpty {
                    ProgressView()
                }
            }
            .searchable(text: $searchText, prompt: Text("search_workouts"))
            .navigationTitle("chat_share_workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(Color.apexMainColor)
                    }
                    .accessibilityLabel(Text("cancel"))
                }
            }
            .task {
                await load()
            }
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let url = AppEnvironment.apiURL.appendingPathComponent("workouts")
            let loaded: [Workout] = try await APIClient.shared.request(url)
            workouts = loaded.sorted {
                $0.name.localized.localizedStandardCompare($1.name.localized) == .orderedAscending
            }
        } catch let error where error.isCancellation {
            return
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }
}
