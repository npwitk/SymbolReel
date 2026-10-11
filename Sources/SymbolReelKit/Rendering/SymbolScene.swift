import Observation
import SwiftUI

/// The state change that plays an effect.
@MainActor
@Observable
final class SceneState {
    /// Incremented to trigger effects that play once per change, such as bounce.
    var trigger = 0
    /// Turned on for effects that run while active, such as scale or an endless pulse.
    var isActive = false
    /// Whether the symbol is shown, for appear, disappear and draw transitions.
    var isVisible: Bool
    /// Whether the target symbol is shown, for replace.
    var showsTarget = false

    init(isVisible: Bool) {
        self.isVisible = isVisible
    }
}

/// Draws the symbol and applies the requested effect the same way an app would in SwiftUI.
struct SymbolScene: View {
    let symbol: ResolvedSymbol
    let targetSymbol: ResolvedSymbol?
    let effect: SymbolEffectSpec
    let options: SymbolEffectOptions
    /// Whether the effect loops until stopped rather than playing a fixed number of times.
    let isEndless: Bool
    let appearance: SymbolAppearance
    let pointSize: CGFloat
    let canvasSize: CGSize
    let state: SceneState

    var body: some View {
        ZStack {
            if state.isVisible {
                animatedSymbol
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
    }

    private var currentSymbol: ResolvedSymbol {
        state.showsTarget ? (targetSymbol ?? symbol) : symbol
    }

    @ViewBuilder
    private var animatedSymbol: some View {
        let image = styled(image(of: currentSymbol))

        switch effect.kind {
        case .bounce:
            if isEndless {
                image.symbolEffect(effect.bounce, options: options, isActive: state.isActive)
            } else {
                image.symbolEffect(effect.bounce, options: options, value: state.trigger)
            }
        case .pulse:
            if isEndless {
                image.symbolEffect(effect.pulse, options: options, isActive: state.isActive)
            } else {
                image.symbolEffect(effect.pulse, options: options, value: state.trigger)
            }
        case .variableColor:
            if isEndless {
                image.symbolEffect(effect.variableColor, options: options, isActive: state.isActive)
            } else {
                image.symbolEffect(effect.variableColor, options: options, value: state.trigger)
            }
        case .wiggle:
            if isEndless {
                image.symbolEffect(effect.wiggle, options: options, isActive: state.isActive)
            } else {
                image.symbolEffect(effect.wiggle, options: options, value: state.trigger)
            }
        case .rotate:
            if isEndless {
                image.symbolEffect(effect.rotate, options: options, isActive: state.isActive)
            } else {
                image.symbolEffect(effect.rotate, options: options, value: state.trigger)
            }
        case .breathe:
            if isEndless {
                image.symbolEffect(effect.breathe, options: options, isActive: state.isActive)
            } else {
                image.symbolEffect(effect.breathe, options: options, value: state.trigger)
            }
        case .scale:
            image.symbolEffect(effect.scale, options: options, isActive: state.isActive)
        case .appear:
            image.transition(.symbolEffect(effect.appear, options: options))
        case .disappear:
            image.transition(.symbolEffect(effect.disappear, options: options))
        case .drawOn:
            if #available(macOS 26, *) {
                image.transition(.symbolEffect(effect.drawOn, options: options))
            }
        case .drawOff:
            if #available(macOS 26, *) {
                image.transition(.symbolEffect(effect.drawOff, options: options))
            }
        case .replace:
            if effect.modifiers.contains(.magic) {
                image.contentTransition(.symbolEffect(.replace.magic(fallback: effect.replace), options: options))
            } else {
                image.contentTransition(.symbolEffect(effect.replace, options: options))
            }
        }
    }

    private func image(of symbol: ResolvedSymbol) -> Image {
        if let bundle = symbol.bundle {
            Image(symbol.name, variableValue: appearance.variableValue, bundle: bundle)
        } else {
            Image(systemName: symbol.name, variableValue: appearance.variableValue)
        }
    }

    private func styled(_ image: Image) -> some View {
        let colors = appearance.colors.map { Color(nsColor: $0.nsColor) }
        let primary = colors.first ?? .black

        return image
            .font(.system(size: pointSize, weight: Font.Weight(appearance.weight)))
            .imageScale(Image.Scale(appearance.scale))
            .symbolRenderingMode(appearance.renderingMode.swiftUIMode)
            .modifier(Foreground(colors: colors.isEmpty ? [primary] : colors, isPalette: appearance.renderingMode == .palette))
    }
}

/// Applies one color, or up to three palette colors.
private struct Foreground: ViewModifier {
    let colors: [Color]
    let isPalette: Bool

    func body(content: Content) -> some View {
        if isPalette, colors.count >= 3 {
            content.foregroundStyle(colors[0], colors[1], colors[2])
        } else if isPalette, colors.count == 2 {
            content.foregroundStyle(colors[0], colors[1])
        } else {
            content.foregroundStyle(colors[0])
        }
    }
}

private extension SymbolAppearance.RenderingMode {
    var swiftUIMode: SymbolRenderingMode {
        switch self {
        case .monochrome: .monochrome
        case .hierarchical: .hierarchical
        case .palette: .palette
        case .multicolor: .multicolor
        }
    }
}

private extension Font.Weight {
    init(_ weight: NSFont.Weight) {
        self = switch weight {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        default: .regular
        }
    }
}

private extension Image.Scale {
    init(_ scale: NSImage.SymbolScale) {
        self = switch scale {
        case .small: .small
        case .medium: .medium
        default: .large
        }
    }
}
