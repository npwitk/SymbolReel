import Foundation

public enum SymbolReelError: Error, CustomStringConvertible {
    case unknownSymbol(String)
    case missingTargetSymbol(effect: SymbolEffectSpec.Kind)
    case effectUnavailable(SymbolEffectSpec.Kind, requiredMacOS: Int)
    case invalidRequest(String)
    case animationClockUnavailable
    case encodingFailed(String)

    public var description: String {
        switch self {
        case .unknownSymbol(let name):
            "There's no SF Symbol named '\(name)' on this Mac."
        case .missingTargetSymbol(let effect):
            "The \(effect.name) effect needs a symbol to transition to. Pass one with --to."
        case .effectUnavailable(let effect, let version):
            "The \(effect.name) effect requires macOS \(version) or later."
        case .invalidRequest(let reason):
            reason
        case .animationClockUnavailable:
            """
            This version of macOS doesn't expose the symbol animation clock that SymbolReel uses to \
            render frames. Please open an issue with your macOS version.
            """
        case .encodingFailed(let reason):
            "Encoding failed: \(reason)"
        }
    }
}
