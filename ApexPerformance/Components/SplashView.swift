//
//  SplashView.swift
//  ApexPerformance
//

import AVFoundation
import SwiftUI
import UIKit

/// Intro video shown over the app right after the launch screen. The launch
/// screen has the video's background color, so the switch is invisible;
/// the video plays once without sound and then fades out to reveal the app.
struct SplashView: View {
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var opacity: Double = 1
    @State private var player: AVPlayer?

    // Longest the splash may stay when the video doesn't play.
    private static let timeout: Duration = .seconds(4)

    var body: some View {
        ZStack {
            Color("LaunchBackground")
                .ignoresSafeArea()

            if let player, !reduceMotion {
                SplashVideoView(player: player)
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .opacity(opacity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            await start()
        }
    }

    @MainActor
    private func start() async {
        guard !reduceMotion, let player = Self.makePlayer() else {
            try? await Task.sleep(for: .milliseconds(300))
            await finish()
            return
        }

        self.player = player
        let item = player.currentItem
        player.play()

        // Until the video ends, or the timeout when it doesn't play.
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                let ended = NotificationCenter.default.notifications(
                    named: .AVPlayerItemDidPlayToEndTime,
                    object: item
                )
                for await _ in ended { break }
            }
            group.addTask {
                try? await Task.sleep(for: Self.timeout)
            }
            await group.next()
            group.cancelAll()
        }
        await finish()
    }

    @MainActor
    private func finish() async {
        withAnimation(.easeOut(duration: 0.35)) { opacity = 0 }
        try? await Task.sleep(for: .milliseconds(350))
        player?.pause()
        player = nil
        onFinished()
    }

    private static func makePlayer() -> AVPlayer? {
        guard let url = Bundle.main.url(forResource: "splash", withExtension: "mp4") else { return nil }
        // Silent video: don't stop music the user is listening to.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
        let player = AVPlayer(url: url)
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        return player
    }
}

/// AVPlayerLayer without playback controls.
private struct SplashVideoView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.backgroundColor = .clear
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ view: PlayerView, context: Context) {
        view.playerLayer.player = player
    }

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }

        var playerLayer: AVPlayerLayer {
            layer as! AVPlayerLayer
        }
    }
}

#Preview {
    SplashView(onFinished: {})
}
