import Testing
@testable import SymbolReelKit

struct SymbolEffectSpecTests {
    @Test(arguments: ["variable-color.iterative", "variableColor.iterative", "VARIABLE_COLOR.Iterative"])
    func parsesEffectNamesInAnyCase(_ string: String) throws {
        let spec = try SymbolEffectSpec(parsing: string)
        #expect(spec.kind == .variableColor)
        #expect(spec.modifiers == [.iterative])
    }

    @Test func parsesMultipleModifiersInOrder() throws {
        let spec = try SymbolEffectSpec(parsing: "draw-off.individually.reversed")
        #expect(spec.kind == .drawOff)
        #expect(spec.modifiers == [.individually, .reversed])
        #expect(spec.description == "draw-off.individually.reversed")
        #expect(spec.slug == "draw-off-individually-reversed")
    }

    @Test func rejectsUnknownEffects() {
        #expect(throws: SymbolEffectSpecError.unknownEffect("jump")) {
            try SymbolEffectSpec(parsing: "jump")
        }
    }

    @Test func rejectsModifiersTheEffectDoesNotSupport() {
        #expect(throws: SymbolEffectSpecError.unsupportedModifier(.clockwise, effect: .bounce)) {
            try SymbolEffectSpec(parsing: "bounce.clockwise")
        }
    }

    @Test func rejectsUnknownModifiers() {
        #expect(throws: SymbolEffectSpecError.unknownModifier("sideways", effect: .wiggle)) {
            try SymbolEffectSpec(parsing: "wiggle.sideways")
        }
    }

    @Test func rejectsEmptySpecsAndTokens() {
        #expect(throws: SymbolEffectSpecError.empty) { try SymbolEffectSpec(parsing: "") }
        #expect(throws: (any Error).self) { try SymbolEffectSpec(parsing: "bounce..up") }
    }

    @Test func everyKindRoundTripsThroughItsName() throws {
        for kind in SymbolEffectSpec.Kind.allCases {
            #expect(try SymbolEffectSpec(parsing: kind.name).kind == kind)
            for modifier in kind.supportedModifiers {
                #expect(try SymbolEffectSpec(parsing: "\(kind.name).\(modifier.name)").modifiers == [modifier])
            }
        }
    }
}

struct RGBAColorTests {
    @Test func parsesHexForms() throws {
        #expect(RGBAColor(string: "#007AFF") == RGBAColor(hex: 0x007AFF))
        #expect(RGBAColor(string: "007aff") == RGBAColor(hex: 0x007AFF))
        #expect(RGBAColor(string: "#fff") == .white)
        #expect(RGBAColor(string: "#00000080") == RGBAColor(red: 0, green: 0, blue: 0, alpha: 128.0 / 255))
    }

    @Test func parsesNames() {
        #expect(RGBAColor(string: "Blue") == RGBAColor(hex: 0x007AFF))
    }

    @Test func rejectsInvalidColors() {
        #expect(RGBAColor(string: "#12") == nil)
        #expect(RGBAColor(string: "chartreuse") == nil)
        #expect(RGBAColor(string: "#GGGGGG") == nil)
    }

    @Test func describesItselfAsHex() {
        #expect(RGBAColor(hex: 0xFF9500).description == "#FF9500")
    }
}

struct RenderRequestTests {
    @Test func suggestsFileNamesFromSymbolAndEffect() throws {
        let bounce = RenderRequest(symbolName: "bell.fill", effect: try SymbolEffectSpec(parsing: "bounce.down"))
        #expect(bounce.suggestedBaseName == "bell.fill_bounce-down")

        let replace = RenderRequest(symbolName: "wifi", effect: SymbolEffectSpec(kind: .replace), targetSymbolName: "wifi.slash")
        #expect(replace.suggestedBaseName == "wifi_replace_to_wifi.slash")
    }

    @Test func formatsWithAlphaAreTheTransparentOnes() {
        #expect(OutputFormat.allCases.filter(\.supportsAlpha) == [.prores, .hevcAlpha, .png])
    }
}
