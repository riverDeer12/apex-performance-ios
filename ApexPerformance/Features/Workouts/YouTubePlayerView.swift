//
//  YouTubePlayerView.swift
//  ApexPerformance
//

import SwiftUI
import WebKit

enum YouTubeVideo {
    // Same link formats the API accepts: watch?v=, youtu.be/, shorts/, embed/ and live/.
    private static let pattern =
        #"(?:youtube\.com/(?:watch\?(?:.*&)?v=|shorts/|embed/|live/)|youtu\.be/)([A-Za-z0-9_-]{6,})"#

    static func id(from urlString: String?) -> String? {
        guard let urlString,
              let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: urlString, range: NSRange(urlString.startIndex..., in: urlString)),
              let range = Range(match.range(at: 1), in: urlString) else {
            return nil
        }
        return String(urlString[range])
    }
}

/// Plays a YouTube video inline through YouTube's embedded player.
struct YouTubePlayerView: UIViewRepresentable {
    let videoId: String

    // YouTube rejects embeds without a referrer (error 153),
    // so the player page is loaded under the app's own domain.
    private static let embedOrigin = URL(string: "https://apex-performance.fit")

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.loadHTMLString(html, baseURL: Self.embedOrigin)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    // videoId only contains [A-Za-z0-9_-], so it is safe to put into the HTML.
    private var html: String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <style>
        html, body { margin: 0; padding: 0; height: 100%; background: #000; overflow: hidden; }
        iframe { position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: 0; }
        </style>
        </head>
        <body>
        <iframe src="https://www.youtube.com/embed/\(videoId)?playsinline=1&autoplay=1&rel=0"
                allow="autoplay; encrypted-media; picture-in-picture; fullscreen"
                referrerpolicy="strict-origin-when-cross-origin"
                allowfullscreen></iframe>
        </body>
        </html>
        """
    }
}
