import Foundation

public enum SymbolReelError: Error, CustomStringConvertible {
    case unknownSymbol(String)
    case missingTargetSymbol(effect: SymbolEffectSpec.Kind)
    case effectUnavailable(SymbolEffectSpec.Kind, requiredMacOS: Int)
    case invalidRequest(String)
    case encodingFailed(String)
    case customSymbolFailed(String, reason: String)

    public var description: String {
        switch self {
        case .unknownSymbol(let name) where SymbolReference.templateURL(name) != nil:
            "There's no symbol template at '\(name)'."
        case .unknownSymbol(let name):
            "There's no SF Symbol named '\(name)' on this Mac, and no custom symbol by that name in the SF Symbols app."
        case .missingTargetSymbol(let effect):
            "The \(effect.name) effect needs a symbol to transition to. Pass one with --to."
        case .effectUnavailable(let effect, let version):
            "The \(effect.name) effect requires macOS \(version) or later."
        case .invalidRequest(let reason):
            reason
        case .encodingFailed(let reason):
            "Encoding failed: \(reason)"
        case .customSymbolFailed(let name, let reason):
            "Couldn't load the custom symbol '\(name)'. \(reason)"
        }
    }
}
