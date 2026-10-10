import Symbols

/// Builds the concrete `Symbols` effect values a spec describes.
extension SymbolEffectSpec {
    var bounce: BounceSymbolEffect {
        applying(to: .bounce) { effect, modifier in
            switch modifier {
            case .up: effect.up
            case .down: effect.down
            case .byLayer: effect.byLayer
            default: effect.wholeSymbol
            }
        }
    }

    var pulse: PulseSymbolEffect {
        applying(to: .pulse) { effect, modifier in
            modifier == .byLayer ? effect.byLayer : effect.wholeSymbol
        }
    }

    var variableColor: VariableColorSymbolEffect {
        applying(to: .variableColor) { effect, modifier in
            switch modifier {
            case .iterative: effect.iterative
            case .cumulative: effect.cumulative
            case .reversing: effect.reversing
            case .nonReversing: effect.nonReversing
            case .hideInactiveLayers: effect.hideInactiveLayers
            default: effect.dimInactiveLayers
            }
        }
    }

    var scale: ScaleSymbolEffect {
        applying(to: .scale) { effect, modifier in
            switch modifier {
            case .up: effect.up
            case .down: effect.down
            case .byLayer: effect.byLayer
            default: effect.wholeSymbol
            }
        }
    }

    var wiggle: WiggleSymbolEffect {
        applying(to: .wiggle) { effect, modifier in
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
        }
    }

    var rotate: RotateSymbolEffect {
        applying(to: .rotate) { effect, modifier in
            switch modifier {
            case .clockwise: effect.clockwise
            case .counterClockwise: effect.counterClockwise
            case .byLayer: effect.byLayer
            default: effect.wholeSymbol
            }
        }
    }

    var breathe: BreatheSymbolEffect {
        applying(to: .breathe) { effect, modifier in
            switch modifier {
            case .pulse: effect.pulse
            case .plain: effect.plain
            case .byLayer: effect.byLayer
            default: effect.wholeSymbol
            }
        }
    }

    var appear: AppearSymbolEffect {
        applying(to: .appear) { effect, modifier in
            switch modifier {
            case .up: effect.up
            case .down: effect.down
            case .byLayer: effect.byLayer
            default: effect.wholeSymbol
            }
        }
    }

    var disappear: DisappearSymbolEffect {
        applying(to: .disappear) { effect, modifier in
            switch modifier {
            case .up: effect.up
            case .down: effect.down
            case .byLayer: effect.byLayer
            default: effect.wholeSymbol
            }
        }
    }

    @available(macOS 26, *)
    var drawOn: DrawOnSymbolEffect {
        applying(to: .drawOn) { effect, modifier in
            switch modifier {
            case .byLayer: effect.byLayer
            case .individually: effect.individually
            default: effect.wholeSymbol
            }
        }
    }

    @available(macOS 26, *)
    var drawOff: DrawOffSymbolEffect {
        applying(to: .drawOff) { effect, modifier in
            switch modifier {
            case .byLayer: effect.byLayer
            case .individually: effect.individually
            case .reversed: effect.reversed
            case .nonReversed: effect.nonReversed
            default: effect.wholeSymbol
            }
        }
    }

    var replace: ReplaceSymbolEffect {
        applying(to: ReplaceSymbolEffect.replace) { effect, modifier in
            switch modifier {
            case .downUp: effect.downUp
            case .upUp: effect.upUp
            case .offUp: effect.offUp
            case .byLayer: effect.byLayer
            case .wholeSymbol: effect.wholeSymbol
            default: effect
            }
        }
    }

    private func applying<Effect>(to base: Effect, _ transform: (Effect, Modifier) -> Effect) -> Effect {
        modifiers.reduce(base, transform)
    }
}
