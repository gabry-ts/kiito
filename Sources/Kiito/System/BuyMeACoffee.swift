import AppKit

/// Opens the Buy Me a Coffee page in the user's default browser.
enum BuyMeACoffee {
    private static let url = URL(string: "https://buymeacoffee.com/gabrielepartiti")!

    static func open() {
        NSWorkspace.shared.open(url)
    }
}
