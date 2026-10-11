import Foundation

/// A custom symbol saved in the SF Symbols app on this Mac.
public struct CustomSymbol: Sendable, Hashable {
    /// The name shown in the SF Symbols app, e.g. `custom.gift.fill`.
    public var name: String
    /// The symbol's SVG template.
    public var templateURL: URL
}

/// Reads the custom symbols that the SF Symbols app keeps in its library.
public enum CustomSymbolLibrary {
    /// Where the SF Symbols app stores its library.
    public static var url: URL {
        URL.applicationSupportDirectory
            .appending(path: "com.apple.SFSymbols/SF Symbols Library.sfsymbolslibrary/Custom Symbols", directoryHint: .isDirectory)
    }

    /// Every custom symbol in the library that has its own template, sorted by name.
    ///
    /// Symbols the app derives from another custom symbol, such as an added slash, have no
    /// template of their own and aren't included. Export those from the app as an SVG template
    /// and render the file instead.
    public static func symbols() -> [CustomSymbol] {
        let folders = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
        return folders
            .filter { $0.pathExtension == "customsymbol" }
            .compactMap(symbol(in:))
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// The custom symbol with the given name, if the library has one.
    public static func symbol(named name: String) -> CustomSymbol? {
        symbols().first { $0.name == name }
    }

    private struct Metadata: Decodable {
        var displayName: String
        var template: String
    }

    private static func symbol(in folder: URL) -> CustomSymbol? {
        guard let data = try? Data(contentsOf: folder.appending(path: "CustomSymbol.json")),
              let metadata = try? JSONDecoder().decode(Metadata.self, from: data)
        else { return nil }

        let templateURL = folder.appending(path: metadata.template)
        guard FileManager.default.fileExists(atPath: templateURL.path(percentEncoded: false)) else { return nil }
        return CustomSymbol(name: metadata.displayName, templateURL: templateURL)
    }
}
