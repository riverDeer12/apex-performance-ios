//
//  SplashView.swift
//  ApexPerformance
//

import SwiftUI
import UIKit

/// Animated continuation of the launch screen. It starts exactly like the
/// launch screen (same logo, size, position and background), so the switch
/// is invisible, then the logo pulses and zooms out to reveal the app.
struct SplashView: View {
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var logoScale: CGFloat = 1
    @State private var opacity: Double = 1

    // The launch screen follows the system appearance, while the app is
    // always light, so assets are resolved with the system's scheme.
    @State private var systemColorScheme: ColorScheme = SplashView.currentSystemColorScheme

    var body: some View {
        ZStack {
            Color("LaunchBackground")
                .ignoresSafeArea()

            Image("LaunchLogo")
                .scaleEffect(logoScale)
        }
        .environment(\.colorScheme, systemColorScheme)
        .opacity(opacity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            await animate()
        }
    }

    @MainActor
    private func animate() async {
        if reduceMotion {
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.easeOut(duration: 0.3)) { opacity = 0 }
            try? await Task.sleep(for: .milliseconds(300))
            onFinished()
            return
        }

        // Short pause so the first frame matches the launch screen.
        try? await Task.sleep(for: .milliseconds(150))

        // Logo "breathes in".
        withAnimation(.easeInOut(duration: 0.35)) { logoScale = 0.88 }
        try? await Task.sleep(for: .milliseconds(350))

        // Logo zooms towards the user while the splash fades away.
        withAnimation(.easeIn(duration: 0.45)) {
            logoScale = 6
            opacity = 0
        }
        try? await Task.sleep(for: .milliseconds(450))

        onFinished()
    }

    private static var currentSystemColorScheme: ColorScheme {
        let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        return windowScene?.screen.traitCollection.userInterfaceStyle == .dark ? .dark : .light
    }
}

#Preview {
    SplashView(onFinished: {})
}
