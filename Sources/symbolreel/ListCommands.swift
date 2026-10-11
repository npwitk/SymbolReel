import ArgumentParser
import SymbolReelKit

struct EffectsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "effects",
        abstract: "List the available effects and their modifiers."
    )

    func run() {
        print("Write an effect as its name followed by dot-separated modifiers, e.g. bounce.down.by-layer.\n")
        for kind in SymbolEffectSpec.Kind.allCases {
            print("\(kind.name.padding(toLength: 16, withPad: " ", startingAt: 0))\(kind.summary) (macOS \(kind.minimumMacOSVersion)+)")
            print("\(String(repeating: " ", count: 16))modifiers: \(kind.supportedModifiers.map(\.name).joined(separator: ", "))")
        }
    }
}

struct FormatsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "formats",
        abstract: "List the available output formats."
    )

    func run() {
        for format in OutputFormat.allCases {
            print("\(format.rawValue.padding(toLength: 12, withPad: " ", startingAt: 0))\(format.summary)")
        }
    }
}

struct CustomSymbolsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "custom-symbols",
        abstract: "List the custom symbols in the SF Symbols app on this Mac."
    )

    func run() {
        let symbols = CustomSymbolLibrary.symbols()
        guard !symbols.isEmpty else {
            print("The SF Symbols app has no custom symbols on this Mac.")
            return
        }
        print("Render any of these by name. Each one is compiled with Xcode's actool the first time it's used.\n")
        for symbol in symbols {
            print(symbol.name)
        }
    }
}
