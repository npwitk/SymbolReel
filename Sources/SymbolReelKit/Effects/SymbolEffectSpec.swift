import Foundation

/// A description of an SF Symbols effect, such as `bounce.down.by-layer` or `draw-on.individually`.
///
/// A spec is written as an effect name followed by optional dot-separated modifiers. Names are
/// matched case-insensitively and ignore `-` and `_`, so `variableColor.iterative`,
/// `variable-color.iterative` and `variable_color.ITERATIVE` are all equivalent.
public struct SymbolEffectSpec: Hashable, Sendable, CustomStringConvertible {
    public var kind: Kind
    public var modifiers: [Modifier]

    public init(kind: Kind, modifiers: [Modifier] = []) {
        self.kind = kind
        self.modifiers = modifiers
    }

    /// Parses a spec such as `"wiggle.left.by-layer"`.
    public init(parsing string: String) throws(SymbolEffectSpecError) {
        let tokens = string.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard let head = tokens.first, !head.isEmpty else { throw .empty }
        guard let kind = Kind(token: head) else { throw .unknownEffect(head) }

        var modifiers: [Modifier] = []
        for token in tokens.dropFirst() {
            guard let modifier = Modifier(token: token) else { throw .unknownModifier(token, effect: kind) }
            guard kind.supportedModifiers.contains(modifier) else { throw .unsupportedModifier(modifier, effect: kind) }
            modifiers.append(modifier)
        }
        self.init(kind: kind, modifiers: modifiers)
    }

    public var description: String {
        ([kind.name] + modifiers.map(\.name)).joined(separator: ".")
    }

    /// A filesystem-friendly form of the spec, e.g. `variable-color-iterative`.
    public var slug: String {
        ([kind.name] + modifiers.map(\.name)).joined(separator: "-")
    }
}

extension SymbolEffectSpec {
    public enum Kind: String, CaseIterable, Sendable {
        case bounce
        case pulse
        case variableColor
        case scale
        case wiggle
        case rotate
        case breathe
        case appear
        case disappear
        case drawOn
        case drawOff
        case replace

        init?(token: String) {
            let key = token.normalizedToken
            guard let match = Self.allCases.first(where: { $0.rawValue.normalizedToken == key }) else { return nil }
            self = match
        }

        /// The kebab-case name used on the command line.
        public var name: String { rawValue.kebabCased }

        public var supportedModifiers: [Modifier] {
            switch self {
            case .bounce: [.up, .down, .byLayer, .wholeSymbol]
            case .pulse: [.byLayer, .wholeSymbol]
            case .variableColor: [.iterative, .cumulative, .reversing, .nonReversing, .hideInactiveLayers, .dimInactiveLayers]
            case .scale: [.up, .down, .byLayer, .wholeSymbol]
            case .wiggle: [.up, .down, .left, .right, .forward, .backward, .clockwise, .counterClockwise, .byLayer, .wholeSymbol]
            case .rotate: [.clockwise, .counterClockwise, .byLayer, .wholeSymbol]
            case .breathe: [.pulse, .plain, .byLayer, .wholeSymbol]
            case .appear, .disappear: [.up, .down, .byLayer, .wholeSymbol]
            case .drawOn: [.byLayer, .wholeSymbol, .individually]
            case .drawOff: [.byLayer, .wholeSymbol, .individually, .reversed, .nonReversed]
            case .replace: [.downUp, .upUp, .offUp, .magic, .byLayer, .wholeSymbol]
            }
        }

        /// Whether the effect transitions to a second symbol (requires a target symbol).
        public var isContentTransition: Bool { self == .replace }

        /// Whether the effect can loop. State changes like `draw-on` or `appear` play exactly once.
        public var isRepeatable: Bool {
            switch self {
            case .bounce, .pulse, .variableColor, .wiggle, .rotate, .breathe: true
            case .scale, .appear, .disappear, .drawOn, .drawOff, .replace: false
            }
        }

        /// The minimum macOS major version that provides the effect.
        public var minimumMacOSVersion: Int {
            switch self {
            case .bounce, .pulse, .variableColor, .scale, .appear, .disappear, .replace: 14
            case .wiggle, .rotate, .breathe: 15
            case .drawOn, .drawOff: 26
            }
        }

        public var summary: String {
            switch self {
            case .bounce: "Bounces the symbol once per repetition."
            case .pulse: "Fades the opacity of the symbol or its layers."
            case .variableColor: "Steps the opacity through the symbol's variable layers."
            case .scale: "Scales the symbol up or down and holds it there."
            case .wiggle: "Wiggles the symbol in a direction."
            case .rotate: "Rotates the symbol or its rotating layers."
            case .breathe: "Gently scales and fades the symbol, like breathing."
            case .appear: "Animates the symbol into view."
            case .disappear: "Animates the symbol out of view."
            case .drawOn: "Draws the symbol's strokes on along their paths."
            case .drawOff: "Erases the symbol's strokes along their paths."
            case .replace: "Replaces the symbol with another one (needs a target symbol)."
            }
        }
    }

    public enum Modifier: String, CaseIterable, Sendable {
        case up, down, left, right, forward, backward
        case clockwise, counterClockwise
        case byLayer, wholeSymbol, individually
        case iterative, cumulative, reversing, nonReversing
        case hideInactiveLayers, dimInactiveLayers
        case pulse, plain
        case reversed, nonReversed
        case downUp, upUp, offUp, magic

        init?(token: String) {
            let key = token.normalizedToken
            guard let match = Self.allCases.first(where: { $0.rawValue.normalizedToken == key }) else { return nil }
            self = match
        }

        /// The kebab-case name used on the command line.
        public var name: String { rawValue.kebabCased }
    }
}

public enum SymbolEffectSpecError: Error, Equatable, CustomStringConvertible {
    case empty
    case unknownEffect(String)
    case unknownModifier(String, effect: SymbolEffectSpec.Kind)
    case unsupportedModifier(SymbolEffectSpec.Modifier, effect: SymbolEffectSpec.Kind)

    public var description: String {
        switch self {
        case .empty:
            "The effect is empty."
        case .unknownEffect(let name):
            "Unknown effect '\(name)'. Available effects: \(SymbolEffectSpec.Kind.allCases.map(\.name).joined(separator: ", "))."
        case .unknownModifier(let name, let effect):
            "Unknown modifier '\(name)' for \(effect.name). Supported: \(effect.supportedModifiers.map(\.name).joined(separator: ", "))."
        case .unsupportedModifier(let modifier, let effect):
            "\(effect.name) doesn't support '\(modifier.name)'. Supported: \(effect.supportedModifiers.map(\.name).joined(separator: ", "))."
        }
    }
}

private extension String {
    var normalizedToken: String {
        lowercased().filter { $0 != "-" && $0 != "_" }
    }

    var kebabCased: String {
        reduce(into: "") { result, character in
            if character.isUppercase {
                result += "-" + character.lowercased()
            } else {
                result.append(character)
            }
        }
    }
}
