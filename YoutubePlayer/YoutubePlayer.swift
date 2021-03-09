
import Foundation
import SwiftUI
import XCDYouTubeKit
import Kingfisher
import AVKit
import WebKit

internal struct YoutubePlayer {
    internal enum Source {
        case iframe
        case stream(URL)
    }

    internal let videoIdentifier: String
    internal let imageURL: URL?
    @State private var source: Source?
    @State private var showingPlaceholder = true
    
    internal init(videoURL: String) {
        self.videoIdentifier = YoutubePlayer.extractYoutubeIdFromLink(link: videoURL) ?? ""
        self.imageURL = URL(string: "https://img.youtube.com/vi/\(videoIdentifier)/hqdefault.jpg")
    }

    internal init(videoIdentifier: String, imageURL: URL?) {
        self.videoIdentifier = videoIdentifier
        self.imageURL = imageURL
    }

    internal init(videoURL: URL, imageURL: URL?) {
        let identifier = videoURL.absoluteString
            .components(separatedBy: "?v=").last?
            .components(separatedBy: .init(charactersIn: "&?")).first
        self.init(videoIdentifier: identifier ?? "", imageURL: imageURL)
    }
    
    internal static func extractYoutubeIdFromLink(link: String) -> String? {
        let pattern = "((?<=(v|V)/)|(?<=be/)|(?<=(\\?|\\&)v=)|(?<=embed/))([\\w-]++)"
        guard let regExp = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        let nsLink = link as NSString
        let options = NSRegularExpression.MatchingOptions(rawValue: 0)
        let range = NSRange(location: 0, length: nsLink.length)
        let matches = regExp.matches(in: link as String, options:options, range:range)
        if let firstMatch = matches.first {
            return nsLink.substring(with: firstMatch.range)
        }
        return nil
    }
}

extension YoutubePlayer: View {
    internal var body: some View {
        ZStack {
            if showingPlaceholder {
                KFImage(imageURL)
                    .resizable()
                    .aspectRatio(contentMode: .fill)

                Button(action: { self.showingPlaceholder = false }) {
                    Image(systemName: "play.circle.fill") // Asset.play
                        .renderingMode(.original)
                        .resizable()
                        .frame(width: 25, height: 30)
                        .aspectRatio(contentMode: .fit)
                        .padding(20)
                        .padding(.leading, 5)
                        .background(
                            Color.blue // background(Color(.shadow))
                                .opacity(0.7)
                                .cornerRadius(.infinity)
                        )
                }
            } else {
                ActiveYoutubePlayer(videoIdentifier: videoIdentifier, source: $source)
            }
        }
        .background(Color.blue) // .shadow
    }
}

internal struct ActiveYoutubePlayer {
    internal let videoIdentifier: String
    @Binding internal var source: YoutubePlayer.Source?
}

extension ActiveYoutubePlayer: UIViewControllerRepresentable {
    internal func makeCoordinator() -> ActiveYoutubePlayerCoordinator {
        ActiveYoutubePlayerCoordinator(self)
    }

    internal func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    internal func updateUIViewController(_ viewController: UIViewController, context: Context) {
        guard viewController.view.subviews.isEmpty else { return }

        switch source {
        case .stream(let url):
            let avController = context.coordinator.avPlayerViewController
            let player = AVPlayer(url: url)

            avController.player = player

            avController.willMove(toParent: viewController)
            viewController.addChild(avController)
            viewController.view.addSubview(avController.view)
            avController.view.frame = viewController.view.bounds
            viewController.didMove(toParent: viewController)

            player.play()
        case .iframe:
            let webView = WKWebView(frame: .zero)
            webView.frame = viewController.view.bounds
            viewController.view.addSubview(webView)

            if let url = URL(string: "https://www.youtube.com/embed/\(videoIdentifier)?autoplay=1&modestbranding=1&start=0&loop=1") {
                webView.load(.init(url: url))
            }
        case nil:
            break
        }
    }
}

internal final class ActiveYoutubePlayerCoordinator: NSObject {
    internal let activeYoutubePlayer: ActiveYoutubePlayer
    internal lazy var avPlayerViewController: AVPlayerViewController = {
        let avPlayerViewController = AVPlayerViewController()
        // MARK: Change made here
        // Added one line which sets the videoGravity Attribute to resizeAspectFill.
        avPlayerViewController.videoGravity = .resizeAspectFill
        avPlayerViewController.delegate = self
        return avPlayerViewController
    }()

    internal init(_ activeYoutubePlayer: ActiveYoutubePlayer) {
        self.activeYoutubePlayer = activeYoutubePlayer

        XCDYouTubeClient.default().getVideoWithIdentifier(activeYoutubePlayer.videoIdentifier) { video, _ in
            activeYoutubePlayer.source = video.map {
                guard let streamUrl = $0.streamURL else { return nil }

                return YoutubePlayer.Source.stream(streamUrl)
            } ?? .iframe
        }
    }
}

extension ActiveYoutubePlayerCoordinator: AVPlayerViewControllerDelegate {
    internal func playerViewController(_ playerViewController: AVPlayerViewController, willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(
            alongsideTransition: { _ in },
            completion: { _ in playerViewController.player?.play() }
        )
    }
}
