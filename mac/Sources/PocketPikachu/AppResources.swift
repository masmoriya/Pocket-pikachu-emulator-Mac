import Foundation

/// App bundles keep resources in Contents/Resources for valid code signing;
/// SwiftPM command-line builds retain their generated resource accessor.
enum AppResources {
    static let bundle: Bundle = {
        if let url = Bundle.main.url(forResource: "PocketPikachu_PocketPikachu", withExtension: "bundle"),
           let bundle = Bundle(url: url) { return bundle }
        return Bundle.module
    }()
}
