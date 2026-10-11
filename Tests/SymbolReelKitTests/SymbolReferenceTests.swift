import Foundation
import Testing
@testable import SymbolReelKit

struct SymbolReferenceTests {
    @Test(arguments: ["wifi", "custom.gift.fill", "bell.slash"])
    func symbolNamesAreNotPaths(name: String) {
        #expect(SymbolReference.templateURL(name) == nil)
        #expect(SymbolReference.displayName(name) == name)
    }

    @Test func pathsNameTheirTemplate() {
        #expect(SymbolReference.templateURL("logo.svg")?.lastPathComponent == "logo.svg")
        #expect(SymbolReference.displayName("~/Desktop/my.logo.SVG") == "my.logo")
        #expect(SymbolReference.templateURL("~/Desktop/logo.svg")?.path(percentEncoded: false).hasPrefix("~") == false)
    }

    @Test func baseNameUsesTheTemplateName() {
        let request = RenderRequest(
            symbolName: "/tmp/logo.svg",
            effect: SymbolEffectSpec(kind: .replace),
            targetSymbolName: "bell.slash"
        )
        #expect(request.suggestedBaseName == "logo_replace_to_bell.slash")
    }
}
