import AppKit
import Symbols

extension SymbolEffectSpec {
    /// Puts the view into the state the effect starts from, without animating.
    ///
    /// `draw-on` and `appear` animate a hidden symbol into view, so the symbol starts hidden.
    @MainActor
    func prepare(_ view: NSImageView) throws(SymbolReelError) {
        switch kind {
        case .appear:
            view.addSymbolEffect(.disappear, animated: false)
        case .drawOn:
            guard #available(macOS 26, *) else { throw .effectUnavailable(kind, requiredMacOS: 26) }
            view.addSymbolEffect(.drawOff, animated: false)
        default:
            break
        }
    }

    /// Starts the effect on the view.
    @MainActor
    func start(on view: NSImageView, target: NSImage?, options: SymbolEffectOptions) throws(SymbolReelError) {
        switch kind {
        case .bounce:
            view.addSymbolEffect(applying(to: .bounce) { effect, modifier in
                switch modifier {
                case .up: effect.up
                case .down: effect.down
                case .byLayer: effect.byLayer
                default: effect.wholeSymbol
                }
            }, options: options)

        case .pulse:
            view.addSymbolEffect(applying(to: .pulse) { effect, modifier in
                modifier == .byLayer ? effect.byLayer : effect.wholeSymbol
            }, options: options)

        case .variableColor:
            view.addSymbolEffect(applying(to: .variableColor) { effect, modifier in
                switch modifier {
                case .iterative: effect.iterative
                case .cumulative: effect.cumulative
                case .reversing: effect.reversing
                case .nonReversing: effect.nonReversing
                case .hideInactiveLayers: effect.hideInactiveLayers
                default: effect.dimInactiveLayers
                }
            }, options: options)

        case .scale:
            view.addSymbolEffect(applying(to: .scale) { effect, modifier in
                switch modifier {
                case .up: effect.up
                case .down: effect.down
                case .byLayer: effect.byLayer
                default: effect.wholeSymbol
                }
            }, options: options)

        case .wiggle:
            view.addSymbolEffect(applying(to: .wiggle) { effect, modifier in
                switch modifier {
                case .up: effect.up
                case .down: effect.down
                case .left: effect.left
                case .right: effect.right
                case .forward: effect.forward
                case .backward: effect.backward
                case .clockwise: effect.clockwise
                case .counterClockwise: effect.counterClockwise
                case .byLayer: effect.byLayer
                default: effect.wholeSymbol
                }
            }, options: options)

        case .rotate:
            view.addSymbolEffect(applying(to: .rotate) { effect, modifier in
                switch modifier {
                case .clockwise: effect.clockwise
                case .counterClockwise: effect.counterClockwise
                case .byLayer: effect.byLayer
                default: effect.wholeSymbol
                }
            }, options: options)

        case .breathe:
            view.addSymbolEffect(applying(to: .breathe) { effect, modifier in
                switch modifier {
                case .pulse: effect.pulse
                case .plain: effect.plain
                case .byLayer: effect.byLayer
                default: effect.wholeSymbol
                }
            }, options: options)

        case .appear:
            view.removeSymbolEffect(ofType: .disappear, animated: false)
            view.addSymbolEffect(applying(to: .appear) { effect, modifier in
                switch modifier {
                case .up: effect.up
                case .down: effect.down
                case .byLayer: effect.byLayer
                default: effect.wholeSymbol
                }
            }, options: options)

        case .disappear:
            view.addSymbolEffect(applying(to: .disappear) { effect, modifier in
                switch modifier {
                case .up: effect.up
                case .down: effect.down
                case .byLayer: effect.byLayer
                default: effect.wholeSymbol
                }
            }, options: options)

        case .drawOn:
            guard #available(macOS 26, *) else { throw .effectUnavailable(kind, requiredMacOS: 26) }
            view.addSymbolEffect(applying(to: .drawOn) { effect, modifier in
                switch modifier {
                case .byLayer: effect.byLayer
                case .individually: effect.individually
                default: effect.wholeSymbol
                }
            }, options: options)

        case .drawOff:
            guard #available(macOS 26, *) else { throw .effectUnavailable(kind, requiredMacOS: 26) }
            view.addSymbolEffect(applying(to: .drawOff) { effect, modifier in
                switch modifier {
                case .byLayer: effect.byLayer
                case .individually: effect.individually
                case .reversed: effect.reversed
                case .nonReversed: effect.nonReversed
                default: effect.wholeSymbol
                }
            }, options: options)

        case .replace:
            guard let target else { throw .missingTargetSymbol(effect: kind) }
            let replace = applying(to: ReplaceSymbolEffect.replace) { effect, modifier in
                switch modifier {
                case .downUp: effect.downUp
                case .upUp: effect.upUp
                case .offUp: effect.offUp
                case .byLayer: effect.byLayer
                case .wholeSymbol: effect.wholeSymbol
                default: effect
                }
            }
            if modifiers.contains(.magic) {
                view.setSymbolImage(target, contentTransition: .replace.magic(fallback: replace), options: options)
            } else {
                view.setSymbolImage(target, contentTransition: replace, options: options)
            }
        }
    }

    private func applying<Effect>(to base: Effect, _ transform: (Effect, Modifier) -> Effect) -> Effect {
        modifiers.reduce(base, transform)
    }
}
