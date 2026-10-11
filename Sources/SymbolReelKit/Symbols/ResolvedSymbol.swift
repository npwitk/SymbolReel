import AppKit
import CryptoKit

/// A symbol ready to draw: either a system symbol, or a custom symbol compiled into a bundle.
struct ResolvedSymbol: Hashable {
    /// The system symbol name, or the image name inside `bundle`.
    var name: String
    /// The bundle that holds a custom symbol; `nil` for system symbols.
    var bundle: Bundle?

    /// Finds the symbols that names refer to.
    ///
    /// A name can be a system symbol such as `wifi`, a custom symbol from the SF Symbols app's
    /// library, or the path to an SVG template exported from the SF Symbols app.
    ///
    /// The first reference is the source symbol and the second, if any, the symbol it transitions
    /// to. When the target is a custom symbol, its layer tags are lined up with the source's so Magic
    /// Replace works as it does between system symbols (see `MagicReplaceTags`).
    static func resolve(_ references: [String]) throws(SymbolReelError) -> [ResolvedSymbol] {
        enum Pending {
            case system(String)
            case custom(String)
        }
        var templates: [(name: String, template: Data)] = []
        var pending: [Pending] = []

        for reference in references {
            if let templateURL = SymbolReference.templateURL(reference) {
                guard FileManager.default.fileExists(atPath: templateURL.path(percentEncoded: false)) else {
                    throw .unknownSymbol(reference)
                }
                pending.append(.custom(try add(templateURL, named: SymbolReference.displayName(reference), to: &templates)))
            } else if NSImage(systemSymbolName: reference, accessibilityDescription: nil) != nil {
                pending.append(.system(reference))
            } else if let custom = CustomSymbolLibrary.symbol(named: reference) {
                pending.append(.custom(try add(custom.templateURL, named: custom.name, to: &templates)))
            } else {
                throw .unknownSymbol(reference)
            }
        }
        if pending.count == 2, case .custom(let targetName) = pending[1],
           let targetIndex = templates.firstIndex(where: { $0.name == targetName }) {
            let sourceTags: Set<String>? = switch pending[0] {
            // System symbols tag their layers with the symbol's name.
            case .system(let name): [name]
            // A symbol replacing itself has nothing to line up.
            case .custom(let name) where name == targetName: nil
            case .custom(let name): templates.first { $0.name == name }.map { Set(MagicReplaceTags.tagLists(in: $0.template).joined()) }
            }
            if let sourceTags {
                templates[targetIndex].template = MagicReplaceTags.reconcile(target: templates[targetIndex].template, withSourceTags: sourceTags)
            }
        }

        let bundle = templates.isEmpty ? nil : try compile(templates)
        return pending.map { symbol in
            switch symbol {
            case .system(let name): ResolvedSymbol(name: name, bundle: nil)
            case .custom(let name): ResolvedSymbol(name: name, bundle: bundle)
            }
        }
    }

    // MARK: - Compiling custom symbols

    /// Adds a template to compile, and returns its image name in the catalog. Two different
    /// templates with the same name get distinct image names.
    private static func add(_ templateURL: URL, named name: String, to templates: inout [(name: String, template: Data)]) throws(SymbolReelError) -> String {
        let template: Data
        do {
            template = try Data(contentsOf: templateURL)
        } catch {
            throw .customSymbolFailed(name, reason: "Couldn't read \(templateURL.path(percentEncoded: false)).")
        }

        if let existing = templates.first(where: { $0.template == template }) {
            return existing.name
        }
        var uniqueName = name
        var suffix = 2
        while templates.contains(where: { $0.name == uniqueName }) {
            uniqueName = "\(name)-\(suffix)"
            suffix += 1
        }
        templates.append((uniqueName, template))
        return uniqueName
    }

    /// Compiles SVG templates into an asset catalog the way Xcode does for an app, and loads it.
    ///
    /// Only an asset catalog gives a custom symbol its layers and annotations, which the effects
    /// animate. Compiled bundles are cached by content, so the same symbols are compiled once.
    private static func compile(_ templates: [(name: String, template: Data)]) throws(SymbolReelError) -> Bundle {
        let deploymentTarget = "\(ProcessInfo.processInfo.operatingSystemVersion.majorVersion).0"
        var key = Data(deploymentTarget.utf8)
        for (name, template) in templates {
            key.append(Data(name.utf8))
            key.append(Data(SHA256.hash(data: template)))
        }
        let identifier = SHA256.hash(data: key).prefix(12).map { String(format: "%02x", $0) }.joined()
        let bundleURL = cacheURL.appending(path: "\(identifier).bundle", directoryHint: .isDirectory)

        if !FileManager.default.fileExists(atPath: bundleURL.path(percentEncoded: false)) {
            try buildBundle(at: bundleURL, identifier: identifier, templates: templates, deploymentTarget: deploymentTarget)
        }

        let names = templates.map(\.name).joined(separator: ", ")
        guard let bundle = Bundle(url: bundleURL) else {
            throw .customSymbolFailed(names, reason: "The compiled symbols couldn't be loaded.")
        }
        for (name, _) in templates where NSImage(symbolName: name, bundle: bundle, variableValue: 1) == nil {
            throw .customSymbolFailed(name, reason: "The compiled symbol couldn't be loaded. Check that the SVG is a symbol template exported from the SF Symbols app.")
        }
        return bundle
    }

    private static var cacheURL: URL {
        URL.cachesDirectory.appending(path: "SymbolReel/CustomSymbols", directoryHint: .isDirectory)
    }

    private static func buildBundle(at bundleURL: URL, identifier: String, templates: [(name: String, template: Data)], deploymentTarget: String) throws(SymbolReelError) {
        let name = templates.map(\.name).joined(separator: ", ")
        let fileManager = FileManager.default
        let workURL = fileManager.temporaryDirectory.appending(path: "SymbolReel-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? fileManager.removeItem(at: workURL) }

        let catalogURL = workURL.appending(path: "Symbols.xcassets", directoryHint: .isDirectory)
        let stagedBundleURL = workURL.appending(path: "Symbols.bundle", directoryHint: .isDirectory)
        let resourcesURL = stagedBundleURL.appending(path: "Contents/Resources", directoryHint: .isDirectory)

        do {
            try fileManager.createDirectory(at: resourcesURL, withIntermediateDirectories: true)
            let info = ["author": "xcode", "version": 1] as [String: Any]
            try fileManager.createDirectory(at: catalogURL, withIntermediateDirectories: true)
            try JSONSerialization.data(withJSONObject: ["info": info])
                .write(to: catalogURL.appending(path: "Contents.json"))
            for (symbolName, template) in templates {
                let symbolSetURL = catalogURL.appending(path: "\(symbolName).symbolset", directoryHint: .isDirectory)
                try fileManager.createDirectory(at: symbolSetURL, withIntermediateDirectories: true)
                try template.write(to: symbolSetURL.appending(path: "\(symbolName).svg"))
                try JSONSerialization.data(withJSONObject: ["info": info, "symbols": [["filename": "\(symbolName).svg", "idiom": "universal"]]])
                    .write(to: symbolSetURL.appending(path: "Contents.json"))
            }
            // Asset catalogs are looked up by bundle identifier, so each bundle needs its own.
            let infoPlist: [String: String] = [
                "CFBundleIdentifier": "dev.symbolreel.custom-symbol.\(identifier)",
                "CFBundlePackageType": "BNDL",
            ]
            try PropertyListSerialization.data(fromPropertyList: infoPlist, format: .xml, options: 0)
                .write(to: stagedBundleURL.appending(path: "Contents/Info.plist"))
        } catch {
            throw .customSymbolFailed(name, reason: "Couldn't prepare the asset catalog: \(error.localizedDescription)")
        }

        let output = try runActool(
            catalogURL: catalogURL, resourcesURL: resourcesURL, deploymentTarget: deploymentTarget, symbolName: name
        )
        guard fileManager.fileExists(atPath: resourcesURL.appending(path: "Assets.car").path(percentEncoded: false)) else {
            throw .customSymbolFailed(name, reason: "actool didn't produce an asset catalog.\n\(output)")
        }

        do {
            try fileManager.createDirectory(at: bundleURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.moveItem(at: stagedBundleURL, to: bundleURL)
        } catch {
            // Another render may have cached the same symbol in the meantime.
            guard fileManager.fileExists(atPath: bundleURL.path(percentEncoded: false)) else {
                throw .customSymbolFailed(name, reason: "Couldn't cache the compiled symbols: \(error.localizedDescription)")
            }
        }
    }

    private static func runActool(catalogURL: URL, resourcesURL: URL, deploymentTarget: String, symbolName: String) throws(SymbolReelError) -> String {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/xcrun")
        process.arguments = [
            "actool", catalogURL.path(percentEncoded: false),
            "--compile", resourcesURL.path(percentEncoded: false),
            "--platform", "macosx",
            "--minimum-deployment-target", deploymentTarget,
            "--output-format", "human-readable-text",
            "--errors", "--warnings",
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            throw .customSymbolFailed(symbolName, reason: "Couldn't run xcrun: \(error.localizedDescription)")
        }
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            if output.contains("unable to find utility") {
                throw .customSymbolFailed(symbolName, reason: "Custom symbols are compiled with actool, which comes with Xcode. Install Xcode, then select it with `sudo xcode-select -s /Applications/Xcode.app`.")
            }
            throw .customSymbolFailed(symbolName, reason: "actool failed.\n\(output)")
        }
        return output
    }
}

/// Interprets the names people pass for symbols.
public enum SymbolReference {
    /// The template file a reference points to, if it's a path rather than a symbol name.
    public static func templateURL(_ reference: String) -> URL? {
        guard reference.lowercased().hasSuffix(".svg") || reference.contains("/") else { return nil }
        return URL(filePath: (reference as NSString).expandingTildeInPath)
    }

    /// A short name for a reference: the symbol name, or a template's file name without `.svg`.
    public static func displayName(_ reference: String) -> String {
        guard let url = templateURL(reference) else { return reference }
        return url.deletingPathExtension().lastPathComponent
    }
}
