import Foundation
import Testing
@testable import SymbolReelKit

struct MagicReplaceTagsTests {
    /// The tags the SF Symbols app writes when it adds a slash to a custom symbol.
    private let slashedTemplate = Data("""
        <style>.monochrome-0 {-sfsymbols-motion-group:1;-sfsymbols-layer-tags:-15e8134a38046f7 bb55fa7d4821ab7 server.rack}
        .monochrome-1 {opacity:0.0;-sfsymbols-clear-behind:true;-sfsymbols-layer-tags:_slash bb55fa7d4821ab7}
        .monochrome-2 {-sfsymbols-motion-group:0;-sfsymbols-layer-tags:_slash bb55fa7d4821ab7}
        </style>
        """.utf8)

    @Test func readsEachRulesTags() {
        #expect(MagicReplaceTags.tagLists(in: slashedTemplate) == [
            ["-15e8134a38046f7", "bb55fa7d4821ab7", "server.rack"],
            ["_slash", "bb55fa7d4821ab7"],
            ["_slash", "bb55fa7d4821ab7"],
        ])
    }

    @Test func dropsLineageTagsTheSourceLacks() {
        let reconciled = MagicReplaceTags.reconcile(target: slashedTemplate, withSourceTags: ["server.rack"])
        #expect(MagicReplaceTags.tagLists(in: reconciled) == [
            ["bb55fa7d4821ab7", "server.rack"],
            ["_slash", "bb55fa7d4821ab7"],
            ["_slash", "bb55fa7d4821ab7"],
        ])
    }

    @Test func leavesUnrelatedSymbolsAlone() {
        let reconciled = MagicReplaceTags.reconcile(target: slashedTemplate, withSourceTags: ["gate.and"])
        #expect(reconciled == slashedTemplate)
    }

    @Test func leavesMatchingSymbolsAlone() {
        let sourceTags: Set = ["-15e8134a38046f7", "server.rack"]
        #expect(MagicReplaceTags.reconcile(target: slashedTemplate, withSourceTags: sourceTags) == slashedTemplate)
    }
}
